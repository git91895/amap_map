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

    // 替换 URL 模板中的占位符
    NSString *urlString = self.urlTemplate;
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{x}" withString:[NSString stringWithFormat:@"%ld", (long)path.x]];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{y}" withString:[NSString stringWithFormat:@"%ld", (long)path.y]];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{z}" withString:[NSString stringWithFormat:@"%ld", (long)path.z]];

    NSURL *url = [NSURL URLWithString:urlString];

    // P0: Store in memory cache
    if (self.memoryCacheEnabled && url) {
        [_urlCache setObject:url forKey:cacheKey];
    }

    return url;
}

/// 重写瓦片加载方法 - 实现真正的瓦片数据缓存
/// 这是解决每次滑动重复加载问题的关键方法
- (void)loadTileAtPath:(MATileOverlayPath)path result:(void (^)(NSData * _Nullable, NSError * _Nullable))result {
    if (!result) {
        return;
    }

    NSString *cacheKey = [self cacheKeyForPath:path];
    AMapTileCache *cache = [AMapTileCache sharedCache];

    // 1. 先检查缓存
    NSData *cachedData = [cache tileDataForKey:cacheKey];
    if (cachedData) {
        // 缓存命中，直接返回
        result(cachedData, nil);
        return;
    }

    // 2. 缓存未命中，从网络加载
    NSURL *url = [self URLForTilePath:path];
    if (!url) {
        result(nil, [NSError errorWithDomain:@"AMapTileOverlay"
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid tile URL"}]);
        return;
    }

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
            // 存入缓存
            [cache setTileData:data forKey:cacheKey];
        }

        result(data, nil);
    }];

    [task resume];
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
