// Copyright 2024
// TileOverlay support for amap_map plugin

import 'base_overlay.dart';

/// 瓦片提供者抽象类
///
/// 用于提供在线瓦片图层的 URL 模板
abstract class TileProvider {
  /// 获取瓦片的 URL
  ///
  /// [x] 瓦片的 x 坐标
  /// [y] 瓦片的 y 坐标
  /// [zoom] 缩放级别
  String getTileUrl(int x, int y, int zoom);

  /// 将 TileProvider 转换为 Map
  Map<String, dynamic> toMap();
}

/// URL 瓦片提供者
///
/// 通过 URL 模板加载在线瓦片
/// URL 模板支持以下占位符：
/// - {x} 或 %d(第一个): 瓦片 x 坐标
/// - {y} 或 %d(第二个): 瓦片 y 坐标
/// - {z} 或 %d(第三个): 缩放级别
///
/// 示例 URL 模板：
/// - "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
/// - "https://example.com/tiles/%d/%d/%d.png"
class UrlTileProvider extends TileProvider {
  /// URL 模板
  final String urlTemplate;

  /// 瓦片宽度，默认 256
  final int tileWidth;

  /// 瓦片高度，默认 256
  final int tileHeight;

  UrlTileProvider({
    required this.urlTemplate,
    this.tileWidth = 256,
    this.tileHeight = 256,
  });

  @override
  String getTileUrl(int x, int y, int zoom) {
    String url = urlTemplate;
    // 支持 {x}, {y}, {z} 占位符
    url = url.replaceAll('{x}', x.toString());
    url = url.replaceAll('{y}', y.toString());
    url = url.replaceAll('{z}', zoom.toString());
    return url;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'url',
      'urlTemplate': urlTemplate,
      'tileWidth': tileWidth,
      'tileHeight': tileHeight,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! UrlTileProvider) return false;
    return urlTemplate == other.urlTemplate &&
        tileWidth == other.tileWidth &&
        tileHeight == other.tileHeight;
  }

  @override
  int get hashCode => Object.hash(urlTemplate, tileWidth, tileHeight);
}

/// 瓦片图层覆盖物
///
/// 用于在地图上显示在线瓦片图层，如 OSM、天地图等
class TileOverlay extends BaseOverlay {
  /// 瓦片提供者
  final TileProvider tileProvider;

  /// 是否可见
  final bool visible;

  /// 透明度 (0.0 - 1.0)
  final double transparency;

  /// 层级，数值越大越靠上
  final int zIndex;

  /// 最小缩放级别
  final int minZoom;

  /// 最大缩放级别
  final int maxZoom;

  /// 是否启用磁盘缓存
  final bool diskCacheEnabled;

  /// 磁盘缓存大小（MB）
  final int diskCacheSize;

  /// 是否启用内存缓存
  final bool memoryCacheEnabled;

  /// 内存缓存大小（个数）
  final int memoryCacheSize;

  /// 预加载边界瓦片数（默认1，即预加载周围1圈瓦片）
  final int preloadMargin;

  /// 最大并行请求数（默认4）
  final int maxConcurrentRequests;

  /// 坐标系类型: 0=WGS84, 1=GCJ02, 2=BD09 (默认0)
  /// 用于瓦片服务与高德地图坐标系对齐
  final int coordinateType;

  /// 是否翻转Y坐标 (TMS格式需要设置为true)
  /// TMS格式的Y坐标从下往上增加，需要翻转
  final bool flipY;

  /// 是否启用高清模式 (Retina屏幕优化)
  /// 启用后会请求更高级别的瓦片 (z+1) 并合成为 512x512 的高清瓦片
  /// 适用于 Retina 屏幕，可显著提升瓦片清晰度
  final bool retinaMode;

  TileOverlay({
    required this.tileProvider,
    this.visible = true,
    this.transparency = 0.0,
    this.zIndex = 0,
    this.minZoom = 3,
    this.maxZoom = 20,
    this.diskCacheEnabled = true,
    this.diskCacheSize = 100,
    this.memoryCacheEnabled = true,
    this.memoryCacheSize = 50,
    this.preloadMargin = 1,
    this.maxConcurrentRequests = 4,
    this.coordinateType = 0,
    this.flipY = false,
    this.retinaMode = false,
  }) : super();

  /// 复制并修改属性
  TileOverlay copyWith({
    TileProvider? tileProviderParam,
    bool? visibleParam,
    double? transparencyParam,
    int? zIndexParam,
    int? minZoomParam,
    int? maxZoomParam,
    bool? diskCacheEnabledParam,
    int? diskCacheSizeParam,
    bool? memoryCacheEnabledParam,
    int? memoryCacheSizeParam,
    int? preloadMarginParam,
    int? maxConcurrentRequestsParam,
    int? coordinateTypeParam,
    bool? flipYParam,
    bool? retinaModeParam,
  }) {
    TileOverlay copy = TileOverlay(
      tileProvider: tileProviderParam ?? tileProvider,
      visible: visibleParam ?? visible,
      transparency: transparencyParam ?? transparency,
      zIndex: zIndexParam ?? zIndex,
      minZoom: minZoomParam ?? minZoom,
      maxZoom: maxZoomParam ?? maxZoom,
      diskCacheEnabled: diskCacheEnabledParam ?? diskCacheEnabled,
      diskCacheSize: diskCacheSizeParam ?? diskCacheSize,
      memoryCacheEnabled: memoryCacheEnabledParam ?? memoryCacheEnabled,
      memoryCacheSize: memoryCacheSizeParam ?? memoryCacheSize,
      preloadMargin: preloadMarginParam ?? preloadMargin,
      maxConcurrentRequests: maxConcurrentRequestsParam ?? maxConcurrentRequests,
      coordinateType: coordinateTypeParam ?? coordinateType,
      flipY: flipYParam ?? flipY,
      retinaMode: retinaModeParam ?? retinaMode,
    );
    copy.setIdForCopy(id);
    return copy;
  }

  @override
  TileOverlay clone() => copyWith();

  @override
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('id', id);
    addIfPresent('tileProvider', tileProvider.toMap());
    addIfPresent('visible', visible);
    addIfPresent('transparency', transparency);
    addIfPresent('zIndex', zIndex);
    addIfPresent('minZoom', minZoom);
    addIfPresent('maxZoom', maxZoom);
    addIfPresent('diskCacheEnabled', diskCacheEnabled);
    addIfPresent('diskCacheSize', diskCacheSize);
    addIfPresent('memoryCacheEnabled', memoryCacheEnabled);
    addIfPresent('memoryCacheSize', memoryCacheSize);
    addIfPresent('preloadMargin', preloadMargin);
    addIfPresent('maxConcurrentRequests', maxConcurrentRequests);
    addIfPresent('coordinateType', coordinateType);
    addIfPresent('flipY', flipY);
    addIfPresent('retinaMode', retinaMode);

    return json;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! TileOverlay) return false;
    return id == other.id &&
        tileProvider == other.tileProvider &&
        visible == other.visible &&
        transparency == other.transparency &&
        zIndex == other.zIndex &&
        minZoom == other.minZoom &&
        maxZoom == other.maxZoom &&
        diskCacheEnabled == other.diskCacheEnabled &&
        diskCacheSize == other.diskCacheSize &&
        memoryCacheEnabled == other.memoryCacheEnabled &&
        memoryCacheSize == other.memoryCacheSize &&
        preloadMargin == other.preloadMargin &&
        maxConcurrentRequests == other.maxConcurrentRequests &&
        coordinateType == other.coordinateType &&
        flipY == other.flipY &&
        retinaMode == other.retinaMode;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        tileProvider,
        visible,
        transparency,
        zIndex,
        minZoom,
        maxZoom,
        diskCacheEnabled,
        diskCacheSize,
        memoryCacheEnabled,
        memoryCacheSize,
        preloadMargin,
        maxConcurrentRequests,
        coordinateType,
        flipY,
        retinaMode,
      ]);
}

/// 根据 ID 将 TileOverlay 列表转换为 Map
Map<String, TileOverlay> keyByTileOverlayId(Iterable<TileOverlay> tileOverlays) {
  return Map<String, TileOverlay>.fromEntries(
    tileOverlays.map(
      (TileOverlay tileOverlay) => MapEntry<String, TileOverlay>(
        tileOverlay.id,
        tileOverlay.clone(),
      ),
    ),
  );
}
