//
//  AMapTileOverlay.h
//  amap_map
//
//  TileOverlay support for amap_map plugin
//

#import <Foundation/Foundation.h>
#import <MAMapKit/MAMapKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Flutter TileOverlay 模型类
@interface AMapTileOverlay : NSObject

/// 唯一标识
@property (nonatomic, copy) NSString *id_;

/// URL 模板
@property (nonatomic, copy) NSString *urlTemplate;

/// 瓦片宽度
@property (nonatomic, assign) NSInteger tileWidth;

/// 瓦片高度
@property (nonatomic, assign) NSInteger tileHeight;

/// 是否可见
@property (nonatomic, assign) BOOL visible;

/// 透明度 (0.0 - 1.0)
@property (nonatomic, assign) CGFloat transparency;

/// 层级
@property (nonatomic, assign) NSInteger zIndex;

/// 最小缩放级别
@property (nonatomic, assign) NSInteger minZoom;

/// 最大缩放级别
@property (nonatomic, assign) NSInteger maxZoom;

/// 是否启用磁盘缓存
@property (nonatomic, assign) BOOL diskCacheEnabled;

/// 磁盘缓存大小（MB）
@property (nonatomic, assign) NSInteger diskCacheSize;

/// 是否启用内存缓存
@property (nonatomic, assign) BOOL memoryCacheEnabled;

/// 内存缓存大小
@property (nonatomic, assign) NSInteger memoryCacheSize;

/// 预加载边界瓦片数（P1优化）
@property (nonatomic, assign) NSInteger preloadMargin;

/// 最大并行请求数（P1优化）
@property (nonatomic, assign) NSInteger maxConcurrentRequests;

/// 从字典创建实例
+ (instancetype)tileOverlayWithDict:(NSDictionary *)dict;

/// 更新属性
- (void)updateWithDict:(NSDictionary *)dict;

@end

/// 自定义 MATileOverlay 子类，支持 URL 模板
/// P0/P1优化：支持缓存和并行请求控制
@interface AMapURLTileOverlay : MATileOverlay

/// 关联的 Flutter TileOverlay ID
@property (nonatomic, copy) NSString *tileOverlayId;

/// URL 模板
@property (nonatomic, copy) NSString *urlTemplate;

/// 最小缩放级别
@property (nonatomic, assign) NSInteger minZoom;

/// 最大缩放级别
@property (nonatomic, assign) NSInteger maxZoom;

/// P0: 磁盘缓存开关
@property (nonatomic, assign) BOOL diskCacheEnabled;

/// P0: 磁盘缓存大小（MB）
@property (nonatomic, assign) NSInteger diskCacheSize;

/// P0: 内存缓存开关
@property (nonatomic, assign) BOOL memoryCacheEnabled;

/// P0: 内存缓存大小
@property (nonatomic, assign) NSInteger memoryCacheSize;

/// P1: 预加载边界瓦片数
@property (nonatomic, assign) NSInteger preloadMargin;

/// P1: 最大并行请求数
@property (nonatomic, assign) NSInteger maxConcurrentRequests;

/// 从 AMapTileOverlay 创建
+ (instancetype)tileOverlayWithModel:(AMapTileOverlay *)model;

/// 更新属性
- (void)updateWithModel:(AMapTileOverlay *)model;

/// P0: 配置缓存
- (void)configureCacheWithDiskEnabled:(BOOL)diskEnabled
                         diskSizeMB:(NSInteger)diskSizeMB
                       memoryEnabled:(BOOL)memoryEnabled
                          memoryCacheSize:(NSInteger)memoryCacheSize;

/// P0: 清除缓存
- (void)clearCache;

/// 获取瓦片数据缓存 key
- (NSString *)cacheKeyForPath:(MATileOverlayPath)path;

@end

#pragma mark - AMapTileCache

/// 瓦片数据缓存管理器
/// 实现真正的瓦片图像数据缓存，解决每次滑动重复加载问题
@interface AMapTileCache : NSObject

/// 单例
+ (instancetype)sharedCache;

/// 内存缓存大小限制（字节）
@property (nonatomic, assign) NSUInteger memoryCacheLimit;

/// 磁盘缓存大小限制（字节）
@property (nonatomic, assign) NSUInteger diskCacheLimit;

/// 从缓存获取瓦片数据
- (NSData *)tileDataForKey:(NSString *)key;

/// 存储瓦片数据到缓存
- (void)setTileData:(NSData *)data forKey:(NSString *)key;

/// 检查缓存是否存在
- (BOOL)hasCacheForKey:(NSString *)key;

/// 清除所有缓存
- (void)clearAllCache;

/// 清除内存缓存
- (void)clearMemoryCache;

/// 获取磁盘缓存路径
- (NSString *)diskCachePath;

@end

NS_ASSUME_NONNULL_END
