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

/// 从字典创建实例
+ (instancetype)tileOverlayWithDict:(NSDictionary *)dict;

/// 更新属性
- (void)updateWithDict:(NSDictionary *)dict;

@end

/// 自定义 MATileOverlay 子类，支持 URL 模板
@interface AMapURLTileOverlay : MATileOverlay

/// 关联的 Flutter TileOverlay ID
@property (nonatomic, copy) NSString *tileOverlayId;

/// URL 模板
@property (nonatomic, copy) NSString *urlTemplate;

/// 最小缩放级别
@property (nonatomic, assign) NSInteger minZoom;

/// 最大缩放级别
@property (nonatomic, assign) NSInteger maxZoom;

/// 从 AMapTileOverlay 创建
+ (instancetype)tileOverlayWithModel:(AMapTileOverlay *)model;

/// 更新属性
- (void)updateWithModel:(AMapTileOverlay *)model;

@end

NS_ASSUME_NONNULL_END
