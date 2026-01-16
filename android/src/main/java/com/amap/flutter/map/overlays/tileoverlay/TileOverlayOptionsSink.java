package com.amap.flutter.map.overlays.tileoverlay;

/**
 * TileOverlay options sink interface
 */
public interface TileOverlayOptionsSink {
    void setUrlTemplate(String urlTemplate);
    void setTileWidth(int tileWidth);
    void setTileHeight(int tileHeight);
    void setVisible(boolean visible);
    void setTransparency(float transparency);
    void setZIndex(float zIndex);
    void setMinZoom(int minZoom);
    void setMaxZoom(int maxZoom);
    void setDiskCacheEnabled(boolean enabled);
    void setDiskCacheSize(int size);
    void setMemoryCacheEnabled(boolean enabled);
    void setMemoryCacheSize(int size);
}
