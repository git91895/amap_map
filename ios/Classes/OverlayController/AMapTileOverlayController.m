//
//  AMapTileOverlayController.m
//  amap_map
//
//  TileOverlay Controller for amap_map plugin
//

#import "AMapTileOverlayController.h"
#import "AMapTileOverlay.h"
#import "FlutterMethodChannel+MethodCallDispatch.h"

@interface AMapTileOverlayController ()

@property (nonatomic, strong) FlutterMethodChannel *methodChannel;
@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) NSObject<FlutterPluginRegistrar> *registrar;

/// 存储 TileOverlay 模型 (key: dartId)
@property (nonatomic, strong) NSMutableDictionary<NSString *, AMapTileOverlay *> *tileOverlayModels;

/// 存储 MATileOverlay 对象 (key: dartId)
@property (nonatomic, strong) NSMutableDictionary<NSString *, AMapURLTileOverlay *> *tileOverlays;

@end

@implementation AMapTileOverlayController

- (instancetype)init:(FlutterMethodChannel *)methodChannel
             mapView:(MAMapView *)mapView
           registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    if (self) {
        _methodChannel = methodChannel;
        _mapView = mapView;
        _registrar = registrar;
        _tileOverlayModels = [NSMutableDictionary dictionary];
        _tileOverlays = [NSMutableDictionary dictionary];

        [self setMethodCallHandler];
    }
    return self;
}

- (void)setMethodCallHandler {
    __weak __typeof__(self) weakSelf = self;

    [self.methodChannel addMethodName:@"tileOverlays#update" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult _Nonnull result) {
        id tileOverlaysToAdd = call.arguments[@"tileOverlaysToAdd"];
        if ([tileOverlaysToAdd isKindOfClass:[NSArray class]]) {
            [weakSelf addTileOverlays:tileOverlaysToAdd];
        }

        id tileOverlaysToChange = call.arguments[@"tileOverlaysToChange"];
        if ([tileOverlaysToChange isKindOfClass:[NSArray class]]) {
            [weakSelf changeTileOverlays:tileOverlaysToChange];
        }

        id tileOverlayIdsToRemove = call.arguments[@"tileOverlayIdsToRemove"];
        if ([tileOverlayIdsToRemove isKindOfClass:[NSArray class]]) {
            [weakSelf removeTileOverlayIds:tileOverlayIdsToRemove];
        }

        result(nil);
    }];
}

- (nullable AMapTileOverlay *)tileOverlayForId:(NSString *)tileOverlayId {
    return self.tileOverlayModels[tileOverlayId];
}

- (void)addTileOverlays:(NSArray *)tileOverlaysToAdd {
    for (NSDictionary *dict in tileOverlaysToAdd) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        AMapTileOverlay *model = [AMapTileOverlay tileOverlayWithDict:dict];
        if (model.id_ == nil || model.id_.length == 0) {
            continue;
        }

        // 创建 MATileOverlay
        AMapURLTileOverlay *tileOverlay = [AMapURLTileOverlay tileOverlayWithModel:model];

        // 存储
        self.tileOverlayModels[model.id_] = model;
        self.tileOverlays[model.id_] = tileOverlay;

        // 添加到地图
        // 使用 MAOverlayLevelAboveRoads 层级，确保 TileOverlay 在道路之上但在轨迹线之下
        // 轨迹线(Polyline)默认使用 MAOverlayLevelAboveLabels，层级更高
        if (model.visible) {
            [self.mapView addOverlay:tileOverlay level:MAOverlayLevelAboveRoads];
        }
    }
}

- (void)changeTileOverlays:(NSArray *)tileOverlaysToChange {
    for (NSDictionary *dict in tileOverlaysToChange) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *tileOverlayId = dict[@"id"];
        if (tileOverlayId == nil || tileOverlayId.length == 0) {
            continue;
        }

        AMapTileOverlay *model = self.tileOverlayModels[tileOverlayId];
        AMapURLTileOverlay *tileOverlay = self.tileOverlays[tileOverlayId];

        if (model == nil || tileOverlay == nil) {
            continue;
        }

        // 更新模型
        BOOL wasVisible = model.visible;
        [model updateWithDict:dict];
        [tileOverlay updateWithModel:model];

        // 处理可见性变化
        if (wasVisible && !model.visible) {
            // 从地图移除
            [self.mapView removeOverlay:tileOverlay];
        } else if (!wasVisible && model.visible) {
            // 添加到地图，使用 MAOverlayLevelAboveRoads 确保在轨迹线之下
            [self.mapView addOverlay:tileOverlay level:MAOverlayLevelAboveRoads];
        } else if (model.visible) {
            // 刷新瓦片 - 通过移除再添加来刷新
            [self.mapView removeOverlay:tileOverlay];
            [self.mapView addOverlay:tileOverlay level:MAOverlayLevelAboveRoads];
        }
    }
}

- (void)removeTileOverlayIds:(NSArray *)tileOverlayIdsToRemove {
    for (NSString *tileOverlayId in tileOverlayIdsToRemove) {
        if (![tileOverlayId isKindOfClass:[NSString class]]) {
            continue;
        }

        AMapURLTileOverlay *tileOverlay = self.tileOverlays[tileOverlayId];
        if (tileOverlay) {
            [self.mapView removeOverlay:tileOverlay];
        }

        [self.tileOverlayModels removeObjectForKey:tileOverlayId];
        [self.tileOverlays removeObjectForKey:tileOverlayId];
    }
}

@end
