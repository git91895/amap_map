//
//  AMapTileOverlay.m
//  amap_map
//
//  TileOverlay support for amap_map plugin
//  P0/P1 Optimizations: Cache management, preload support
//  Fix: Tile data caching to prevent reload on scroll
//

#import "AMapTileOverlay.h"
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

/// P0: Global URL cache for memory optimization
static NSCache<NSString *, NSURL *> *_urlCache;
/// P1: Shared operation queue for controlled parallel loading
static NSOperationQueue *_tileLoadQueue;

#pragma mark - AMapTileCache Implementation

@interface AMapTileCache ()
/// 内存缓存
@property (nonatomic, strong) NSCache<NSString *, NSData *> *memoryCache;
/// 磁盘缓存目录
@property (nonatomic, copy) NSString *diskCacheDirectory;
/// 文件管理器
@property (nonatomic, strong) NSFileManager *fileManager;
/// IO 队列
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@end

@implementation AMapTileCache

+ (instancetype)sharedCache {
    static AMapTileCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMapTileCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memoryCache = [[NSCache alloc] init];
        _memoryCache.countLimit = 100; // 默认缓存 100 个瓦片
        _memoryCache.totalCostLimit = 50 * 1024 * 1024; // 50MB 内存限制

        _fileManager = [NSFileManager defaultManager];
        _ioQueue = dispatch_queue_create("com.amap.tilecache.io", DISPATCH_QUEUE_CONCURRENT);

        // 设置默认磁盘缓存大小
        _diskCacheLimit = 100 * 1024 * 1024; // 100MB
        _memoryCacheLimit = 50 * 1024 * 1024; // 50MB

        // 创建磁盘缓存目录
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCacheDirectory = [paths.firstObject stringByAppendingPathComponent:@"AMapTileCache"];

        if (![_fileManager fileExistsAtPath:_diskCacheDirectory]) {
            [_fileManager createDirectoryAtPath:_diskCacheDirectory
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:nil];
        }

        // 监听内存警告
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemoryCache)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setMemoryCacheLimit:(NSUInteger)memoryCacheLimit {
    _memoryCacheLimit = memoryCacheLimit;
    _memoryCache.totalCostLimit = memoryCacheLimit;
}

/// 生成文件名 (MD5 哈希)
- (NSString *)fileNameForKey:(NSString *)key {
    const char *str = key.UTF8String;
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);

    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", result[i]];
    }
    return [hash stringByAppendingPathExtension:@"tile"];
}

- (NSString *)filePathForKey:(NSString *)key {
    return [self.diskCacheDirectory stringByAppendingPathComponent:[self fileNameForKey:key]];
}

- (NSData *)tileDataForKey:(NSString *)key {
    if (!key || key.length == 0) {
        return nil;
    }

    // 1. 先查内存缓存
    NSData *data = [self.memoryCache objectForKey:key];
    if (data) {
        return data;
    }

    // 2. 再查磁盘缓存
    NSString *filePath = [self filePathForKey:key];
    if ([self.fileManager fileExistsAtPath:filePath]) {
        data = [NSData dataWithContentsOfFile:filePath];
        if (data) {
            // 写回内存缓存
            [self.memoryCache setObject:data forKey:key cost:data.length];
        }
        return data;
    }

    return nil;
}

- (void)setTileData:(NSData *)data forKey:(NSString *)key {
    if (!key || key.length == 0 || !data) {
        return;
    }

    // 1. 存入内存缓存
    [self.memoryCache setObject:data forKey:key cost:data.length];

    // 2. 异步存入磁盘缓存
    dispatch_async(self.ioQueue, ^{
        NSString *filePath = [self filePathForKey:key];
        [data writeToFile:filePath atomically:YES];
    });
}

- (BOOL)hasCacheForKey:(NSString *)key {
    if (!key || key.length == 0) {
        return NO;
    }

    // 检查内存缓存
    if ([self.memoryCache objectForKey:key]) {
        return YES;
    }

    // 检查磁盘缓存
    NSString *filePath = [self filePathForKey:key];
    return [self.fileManager fileExistsAtPath:filePath];
}

- (void)clearMemoryCache {
    [self.memoryCache removeAllObjects];
}

- (void)clearAllCache {
    // 清除内存
    [self clearMemoryCache];

    // 清除磁盘
    dispatch_async(self.ioQueue, ^{
        NSError *error = nil;
        NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.diskCacheDirectory error:&error];
        for (NSString *file in files) {
            NSString *filePath = [self.diskCacheDirectory stringByAppendingPathComponent:file];
            [self.fileManager removeItemAtPath:filePath error:nil];
        }
    });
}

- (NSString *)diskCachePath {
    return self.diskCacheDirectory;
}

@end

@implementation AMapTileOverlay

+ (instancetype)tileOverlayWithDict:(NSDictionary *)dict {
    AMapTileOverlay *tileOverlay = [[AMapTileOverlay alloc] init];
    [tileOverlay updateWithDict:dict];
    return tileOverlay;
}

- (void)updateWithDict:(NSDictionary *)dict {
    if (dict[@"id"]) {
        self.id_ = dict[@"id"];
    }

    // 解析 tileProvider
    NSDictionary *tileProvider = dict[@"tileProvider"];
    if (tileProvider) {
        if (tileProvider[@"urlTemplate"]) {
            self.urlTemplate = tileProvider[@"urlTemplate"];
        }
        if (tileProvider[@"tileWidth"]) {
            self.tileWidth = [tileProvider[@"tileWidth"] integerValue];
        } else {
            self.tileWidth = 256;
        }
        if (tileProvider[@"tileHeight"]) {
            self.tileHeight = [tileProvider[@"tileHeight"] integerValue];
        } else {
            self.tileHeight = 256;
        }
    }

    if (dict[@"visible"] != nil) {
        self.visible = [dict[@"visible"] boolValue];
    } else {
        self.visible = YES;
    }

    if (dict[@"transparency"]) {
        self.transparency = [dict[@"transparency"] floatValue];
    } else {
        self.transparency = 0.0;
    }

    if (dict[@"zIndex"]) {
        self.zIndex = [dict[@"zIndex"] integerValue];
    }

    if (dict[@"minZoom"]) {
        self.minZoom = [dict[@"minZoom"] integerValue];
    } else {
        self.minZoom = 3;
    }

    if (dict[@"maxZoom"]) {
        self.maxZoom = [dict[@"maxZoom"] integerValue];
    } else {
        self.maxZoom = 20;
    }

    if (dict[@"diskCacheEnabled"] != nil) {
        self.diskCacheEnabled = [dict[@"diskCacheEnabled"] boolValue];
    } else {
        self.diskCacheEnabled = YES;
    }

    if (dict[@"diskCacheSize"]) {
        self.diskCacheSize = [dict[@"diskCacheSize"] integerValue];
    } else {
        self.diskCacheSize = 100;
    }

    if (dict[@"memoryCacheEnabled"] != nil) {
        self.memoryCacheEnabled = [dict[@"memoryCacheEnabled"] boolValue];
    } else {
        self.memoryCacheEnabled = YES;
    }

    if (dict[@"memoryCacheSize"]) {
        self.memoryCacheSize = [dict[@"memoryCacheSize"] integerValue];
    } else {
        self.memoryCacheSize = 50;
    }

    // P1: Parse preload margin
    if (dict[@"preloadMargin"]) {
        self.preloadMargin = [dict[@"preloadMargin"] integerValue];
    } else {
        self.preloadMargin = 1;
    }

    // P1: Parse max concurrent requests
    if (dict[@"maxConcurrentRequests"]) {
        self.maxConcurrentRequests = [dict[@"maxConcurrentRequests"] integerValue];
    } else {
        self.maxConcurrentRequests = 4;
    }

    // Parse coordinate type (0=WGS84, 1=GCJ02, 2=BD09)
    if (dict[@"coordinateType"]) {
        self.coordinateType = [dict[@"coordinateType"] integerValue];
    } else {
        self.coordinateType = 0; // Default WGS84
    }

    // Parse flipY for TMS format
    if (dict[@"flipY"] != nil) {
        self.flipY = [dict[@"flipY"] boolValue];
    } else {
        self.flipY = NO;
    }

    // Parse retinaMode for high-DPI displays
    if (dict[@"retinaMode"] != nil) {
        self.retinaMode = [dict[@"retinaMode"] boolValue];
    } else {
        self.retinaMode = NO;
    }
}

@end


@implementation AMapURLTileOverlay

+ (instancetype)tileOverlayWithModel:(AMapTileOverlay *)model {
    AMapURLTileOverlay *tileOverlay = [[AMapURLTileOverlay alloc] init];
    [tileOverlay updateWithModel:model];
    return tileOverlay;
}

+ (void)initialize {
    if (self == [AMapURLTileOverlay class]) {
        // P0: Initialize URL cache
        _urlCache = [[NSCache alloc] init];
        _urlCache.countLimit = 100; // Default cache size

        // P1: Initialize operation queue
        _tileLoadQueue = [[NSOperationQueue alloc] init];
        _tileLoadQueue.name = @"com.amap.tileoverlay.loadqueue";
        _tileLoadQueue.maxConcurrentOperationCount = 4; // Default concurrency
    }
}

- (void)updateWithModel:(AMapTileOverlay *)model {
    self.tileOverlayId = model.id_;
    self.urlTemplate = model.urlTemplate;
    self.minZoom = model.minZoom;
    self.maxZoom = model.maxZoom;

    // 设置瓦片大小
    self.tileSize = CGSizeMake(model.tileWidth, model.tileHeight);

    // 设置缩放级别范围
    self.minimumZ = (NSInteger)model.minZoom;
    self.maximumZ = (NSInteger)model.maxZoom;

    // P0: Store cache settings
    self.diskCacheEnabled = model.diskCacheEnabled;
    self.diskCacheSize = model.diskCacheSize;
    self.memoryCacheEnabled = model.memoryCacheEnabled;
    self.memoryCacheSize = model.memoryCacheSize;

    // P1: Store preload and concurrency settings
    self.preloadMargin = model.preloadMargin;
    self.maxConcurrentRequests = model.maxConcurrentRequests;

    // Store coordinate type and flipY settings
    self.coordinateType = model.coordinateType;
    self.flipY = model.flipY;
    self.retinaMode = model.retinaMode;

    // P0: Configure memory cache size
    if (self.memoryCacheEnabled && self.memoryCacheSize > 0) {
        _urlCache.countLimit = self.memoryCacheSize;
    }

    // P1: Configure operation queue concurrency
    if (self.maxConcurrentRequests > 0) {
        _tileLoadQueue.maxConcurrentOperationCount = self.maxConcurrentRequests;
    }

    // P0: Configure URL session cache
    [self configureCacheWithDiskEnabled:self.diskCacheEnabled
                            diskSizeMB:self.diskCacheSize
                          memoryEnabled:self.memoryCacheEnabled
                         memoryCacheSize:self.memoryCacheSize];
}

/// P0: Configure NSURLCache for tile loading
- (void)configureCacheWithDiskEnabled:(BOOL)diskEnabled
                          diskSizeMB:(NSInteger)diskSizeMB
                        memoryEnabled:(BOOL)memoryEnabled
                       memoryCacheSize:(NSInteger)memoryCacheSize {
    if (!diskEnabled && !memoryEnabled) {
        return;
    }

    NSUInteger memoryCapacity = memoryEnabled ? (memoryCacheSize * 256 * 1024) : 0; // ~256KB per tile
    NSUInteger diskCapacity = diskEnabled ? (diskSizeMB * 1024 * 1024) : 0;

    // Get app cache directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths.firstObject stringByAppendingPathComponent:@"tile_cache"];

    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:memoryCapacity
                                                        diskCapacity:diskCapacity
                                                            diskPath:cachePath];
    [NSURLCache setSharedURLCache:urlCache];
}

/// 获取瓦片数据缓存 key
- (NSString *)cacheKeyForPath:(MATileOverlayPath)path {
    return [NSString stringWithFormat:@"%@_%ld_%ld_%ld",
            self.urlTemplate, (long)path.z, (long)path.x, (long)path.y];
}

/// 重写 URL 生成方法
/// P0: Use memory cache for URL objects
/// 支持 Y 坐标翻转 (TMS 格式)
- (NSURL *)URLForTilePath:(MATileOverlayPath)path {
    if (self.urlTemplate == nil || self.urlTemplate.length == 0) {
        return nil;
    }

    // P0: Check memory cache first
    NSString *cacheKey = [self cacheKeyForPath:path];

    if (self.memoryCacheEnabled) {
        NSURL *cachedURL = [_urlCache objectForKey:cacheKey];
        if (cachedURL) {
            return cachedURL;
        }
    }

    // 计算 Y 坐标 (支持 TMS 格式翻转)
    NSInteger y = path.y;
    if (self.flipY) {
        // TMS 格式: y = 2^z - 1 - y
        y = (1 << path.z) - 1 - path.y;
    }

    // 替换 URL 模板中的占位符
    NSString *urlString = self.urlTemplate;
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{x}" withString:[NSString stringWithFormat:@"%ld", (long)path.x]];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{y}" withString:[NSString stringWithFormat:@"%ld", (long)y]];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{z}" withString:[NSString stringWithFormat:@"%ld", (long)path.z]];

    NSURL *url = [NSURL URLWithString:urlString];

    // P0: Store in memory cache
    if (self.memoryCacheEnabled && url) {
        [_urlCache setObject:url forKey:cacheKey];
    }

    return url;
}

/// 将图片数据转换为 PNG 格式
/// 支持 WebP、JPEG 等格式转换为 PNG
- (NSData *)convertToPNGData:(NSData *)imageData {
    if (!imageData || imageData.length == 0) {
        return nil;
    }

    // 检查是否已经是 PNG 格式
    const unsigned char *bytes = (const unsigned char *)imageData.bytes;
    if (imageData.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
        // 已经是 PNG，直接返回
        return imageData;
    }

    // 使用 ImageIO 进行格式转换
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!source) {
        return imageData; // 无法解析，返回原始数据
    }

    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);

    if (!cgImage) {
        return imageData; // 无法创建图像，返回原始数据
    }

    // 转换为 PNG
    NSMutableData *pngData = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)pngData, kUTTypePNG, 1, NULL);

    if (!destination) {
        CGImageRelease(cgImage);
        return imageData;
    }

    CGImageDestinationAddImage(destination, cgImage, NULL);
    BOOL success = CGImageDestinationFinalize(destination);

    CFRelease(destination);
    CGImageRelease(cgImage);

    return success ? pngData : imageData;
}

/// 重写瓦片加载方法 - 实现真正的瓦片数据缓存
/// 这是解决每次滑动重复加载问题的关键方法
/// 支持 WebP 自动转换为 PNG
/// 支持 Retina 模式 - 请求 z+1 级别的 4 张瓦片合成高清图
- (void)loadTileAtPath:(MATileOverlayPath)path result:(void (^)(NSData * _Nullable, NSError * _Nullable))result {
    if (!result) {
        return;
    }

    NSString *cacheKey = [self cacheKeyForPath:path];
    AMapTileCache *cache = [AMapTileCache sharedCache];

    // 1. 先检查缓存 (缓存中已经是转换后的 PNG 格式)
    NSData *cachedData = [cache tileDataForKey:cacheKey];
    if (cachedData) {
        // 缓存命中，直接返回
        NSLog(@"🗺️ [TileOverlay] Cache HIT for tile z=%ld x=%ld y=%ld (size=%lu bytes)", (long)path.z, (long)path.x, (long)path.y, (unsigned long)cachedData.length);
        result(cachedData, nil);
        return;
    }

    NSLog(@"🗺️ [TileOverlay] Cache MISS for tile z=%ld x=%ld y=%ld", (long)path.z, (long)path.x, (long)path.y);

    // 2. 判断是否使用 Retina 模式
    if (self.retinaMode && path.z < self.maxZoom) {
        // Retina 模式：请求 z+1 级别的 4 张瓦片并合成
        [self loadRetinaTileAtPath:path cacheKey:cacheKey result:result];
        return;
    }

    // 3. 普通模式：从网络加载单张瓦片
    [self loadSingleTileAtPath:path cacheKey:cacheKey result:result];
}

/// 加载单张瓦片 (普通模式)
- (void)loadSingleTileAtPath:(MATileOverlayPath)path cacheKey:(NSString *)cacheKey result:(void (^)(NSData * _Nullable, NSError * _Nullable))result {
    NSURL *url = [self URLForTilePath:path];
    if (!url) {
        NSLog(@"🗺️ [TileOverlay] Invalid URL for tile z=%ld x=%ld y=%ld", (long)path.z, (long)path.x, (long)path.y);
        result(nil, [NSError errorWithDomain:@"AMapTileOverlay"
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid tile URL"}]);
        return;
    }

    NSLog(@"🗺️ [TileOverlay] Loading tile z=%ld x=%ld y=%ld URL=%@", (long)path.z, (long)path.x, (long)path.y, url.absoluteString);

    // 配置请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    request.timeoutInterval = 30.0;

    // 创建网络任务
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPMaximumConnectionsPerHost = self.maxConcurrentRequests > 0 ? self.maxConcurrentRequests : 4;
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 60.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    AMapTileCache *cache = [AMapTileCache sharedCache];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            result(nil, error);
            return;
        }

        // 检查 HTTP 状态码
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSError *httpError = [NSError errorWithDomain:@"AMapTileOverlay"
                                                         code:httpResponse.statusCode
                                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP Error: %ld", (long)httpResponse.statusCode]}];
                result(nil, httpError);
                return;
            }
        }

        if (data && data.length > 0) {
            NSLog(@"🗺️ [TileOverlay] Downloaded tile (size=%lu bytes), caching...", (unsigned long)data.length);
            // 直接缓存原始数据，不做格式转换
            [cache setTileData:data forKey:cacheKey];
            result(data, nil);
        } else {
            NSLog(@"🗺️ [TileOverlay] Download returned empty data");
            result(data, nil);
        }
    }];

    [task resume];
}

/// Retina 模式加载：请求 z+1 级别的 4 张瓦片并合成为一张 512x512 的高清瓦片
/// 原理：z+1 级别的 (2x, 2y), (2x+1, 2y), (2x, 2y+1), (2x+1, 2y+1) 合成为 z 级别的 (x, y)
- (void)loadRetinaTileAtPath:(MATileOverlayPath)path cacheKey:(NSString *)cacheKey result:(void (^)(NSData * _Nullable, NSError * _Nullable))result {

    NSInteger nextZ = path.z + 1;
    NSInteger baseX = path.x * 2;
    NSInteger baseY = path.y * 2;

    // 4 张子瓦片的坐标 (左上, 右上, 左下, 右下)
    MATileOverlayPath paths[4];
    paths[0] = (MATileOverlayPath){.x = baseX, .y = baseY, .z = nextZ, .contentScaleFactor = path.contentScaleFactor};
    paths[1] = (MATileOverlayPath){.x = baseX + 1, .y = baseY, .z = nextZ, .contentScaleFactor = path.contentScaleFactor};
    paths[2] = (MATileOverlayPath){.x = baseX, .y = baseY + 1, .z = nextZ, .contentScaleFactor = path.contentScaleFactor};
    paths[3] = (MATileOverlayPath){.x = baseX + 1, .y = baseY + 1, .z = nextZ, .contentScaleFactor = path.contentScaleFactor};

    __block NSMutableArray<NSData *> *tileDataArray = [NSMutableArray arrayWithCapacity:4];
    for (int i = 0; i < 4; i++) {
        [tileDataArray addObject:[NSNull null]];
    }

    __block NSInteger loadedCount = 0;
    __block BOOL hasError = NO;

    dispatch_group_t group = dispatch_group_create();
    AMapTileCache *cache = [AMapTileCache sharedCache];

    __weak typeof(self) weakSelf = self;

    for (int i = 0; i < 4; i++) {
        dispatch_group_enter(group);

        MATileOverlayPath subPath = paths[i];
        NSString *subCacheKey = [self cacheKeyForPath:subPath];

        // 先检查子瓦片缓存
        NSData *subCachedData = [cache tileDataForKey:subCacheKey];
        if (subCachedData) {
            @synchronized (tileDataArray) {
                tileDataArray[i] = subCachedData;
                loadedCount++;
            }
            dispatch_group_leave(group);
            continue;
        }

        // 从网络加载子瓦片
        NSURL *url = [self URLForTilePath:subPath];
        if (!url) {
            @synchronized (tileDataArray) {
                hasError = YES;
            }
            dispatch_group_leave(group);
            continue;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
        request.timeoutInterval = 30.0;

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPMaximumConnectionsPerHost = self.maxConcurrentRequests > 0 ? self.maxConcurrentRequests : 4;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error || !data || data.length == 0) {
                @synchronized (tileDataArray) {
                    hasError = YES;
                }
                dispatch_group_leave(group);
                return;
            }

            // 检查 HTTP 状态码
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode != 200) {
                    @synchronized (tileDataArray) {
                        hasError = YES;
                    }
                    dispatch_group_leave(group);
                    return;
                }
            }

            // 转换为 PNG
            NSData *pngData = [weakSelf convertToPNGData:data];
            if (pngData) {
                // 缓存子瓦片
                [cache setTileData:pngData forKey:subCacheKey];

                @synchronized (tileDataArray) {
                    tileDataArray[i] = pngData;
                    loadedCount++;
                }
            } else {
                @synchronized (tileDataArray) {
                    hasError = YES;
                }
            }

            dispatch_group_leave(group);
        }];

        [task resume];
    }

    // 等待所有子瓦片加载完成
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (tileDataArray) {
            if (hasError || loadedCount < 4) {
                // 如果有错误或加载不完整，回退到普通模式
                [weakSelf loadSingleTileAtPath:path cacheKey:cacheKey result:result];
                return;
            }

            // 合成 4 张瓦片为一张 512x512 的高清瓦片
            NSData *mergedData = [weakSelf mergeTileImages:tileDataArray];
            if (mergedData) {
                [cache setTileData:mergedData forKey:cacheKey];
                result(mergedData, nil);
            } else {
                // 合成失败，回退到普通模式
                [weakSelf loadSingleTileAtPath:path cacheKey:cacheKey result:result];
            }
        }
    });
}

/// 合成 4 张瓦片图像为一张 512x512 的高清瓦片
/// 输入：4 张 256x256 的瓦片 [左上, 右上, 左下, 右下]
/// 输出：1 张 512x512 的合成瓦片
- (NSData *)mergeTileImages:(NSArray<NSData *> *)tileDataArray {
    if (tileDataArray.count != 4) {
        return nil;
    }

    // 创建 4 个 CGImage
    CGImageRef images[4];
    for (int i = 0; i < 4; i++) {
        id data = tileDataArray[i];
        if (![data isKindOfClass:[NSData class]]) {
            return nil;
        }

        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (!source) {
            // 释放已创建的图像
            for (int j = 0; j < i; j++) {
                CGImageRelease(images[j]);
            }
            return nil;
        }

        images[i] = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);

        if (!images[i]) {
            // 释放已创建的图像
            for (int j = 0; j < i; j++) {
                CGImageRelease(images[j]);
            }
            return nil;
        }
    }

    // 获取单张瓦片尺寸 (通常是 256x256)
    size_t tileWidth = CGImageGetWidth(images[0]);
    size_t tileHeight = CGImageGetHeight(images[0]);

    // 创建 512x512 的画布
    size_t canvasWidth = tileWidth * 2;
    size_t canvasHeight = tileHeight * 2;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, canvasWidth, canvasHeight, 8,
                                                  canvasWidth * 4, colorSpace,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    if (!context) {
        for (int i = 0; i < 4; i++) {
            CGImageRelease(images[i]);
        }
        return nil;
    }

    // 绘制 4 张瓦片到画布上
    // 注意：CoreGraphics 坐标系 Y 轴向上，所以需要调整位置
    // 左上 (0, tileHeight)
    CGContextDrawImage(context, CGRectMake(0, tileHeight, tileWidth, tileHeight), images[0]);
    // 右上 (tileWidth, tileHeight)
    CGContextDrawImage(context, CGRectMake(tileWidth, tileHeight, tileWidth, tileHeight), images[1]);
    // 左下 (0, 0)
    CGContextDrawImage(context, CGRectMake(0, 0, tileWidth, tileHeight), images[2]);
    // 右下 (tileWidth, 0)
    CGContextDrawImage(context, CGRectMake(tileWidth, 0, tileWidth, tileHeight), images[3]);

    // 释放原图像
    for (int i = 0; i < 4; i++) {
        CGImageRelease(images[i]);
    }

    // 获取合成后的图像
    CGImageRef mergedImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);

    if (!mergedImage) {
        return nil;
    }

    // 转换为 PNG 数据
    NSMutableData *pngData = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)pngData, kUTTypePNG, 1, NULL);

    if (!destination) {
        CGImageRelease(mergedImage);
        return nil;
    }

    CGImageDestinationAddImage(destination, mergedImage, NULL);
    BOOL success = CGImageDestinationFinalize(destination);

    CFRelease(destination);
    CGImageRelease(mergedImage);

    return success ? pngData : nil;
}

/// P1: Get shared tile load operation queue
+ (NSOperationQueue *)tileLoadQueue {
    return _tileLoadQueue;
}

/// P0: Get shared URL cache
+ (NSCache<NSString *, NSURL *> *)urlCache {
    return _urlCache;
}

/// 清除缓存 - 包括瓦片数据缓存
- (void)clearCache {
    // Clear URL cache
    [_urlCache removeAllObjects];
    // Clear tile data cache
    [[AMapTileCache sharedCache] clearAllCache];
    // Clear URL session cache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

@end
