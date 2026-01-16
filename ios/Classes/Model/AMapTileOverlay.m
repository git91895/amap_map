//
//  AMapTileOverlay.m
//  amap_map
//
//  TileOverlay support for amap_map plugin
//

#import "AMapTileOverlay.h"

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
}

@end


@implementation AMapURLTileOverlay

+ (instancetype)tileOverlayWithModel:(AMapTileOverlay *)model {
    AMapURLTileOverlay *tileOverlay = [[AMapURLTileOverlay alloc] init];
    [tileOverlay updateWithModel:model];
    return tileOverlay;
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
}

/// 重写 URL 生成方法
- (NSURL *)URLForTilePath:(MATileOverlayPath)path {
    if (self.urlTemplate == nil || self.urlTemplate.length == 0) {
        return nil;
    }

    // 替换 URL 模板中的占位符
    NSString *url = self.urlTemplate;
    url = [url stringByReplacingOccurrencesOfString:@"{x}" withString:[NSString stringWithFormat:@"%ld", (long)path.x]];
    url = [url stringByReplacingOccurrencesOfString:@"{y}" withString:[NSString stringWithFormat:@"%ld", (long)path.y]];
    url = [url stringByReplacingOccurrencesOfString:@"{z}" withString:[NSString stringWithFormat:@"%ld", (long)path.z]];

    return [NSURL URLWithString:url];
}

@end
