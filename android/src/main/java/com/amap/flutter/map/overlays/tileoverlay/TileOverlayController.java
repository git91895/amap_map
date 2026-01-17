package com.amap.flutter.map.overlays.tileoverlay;

import com.amap.api.maps.model.TileOverlay;

/**
 * Controller for individual TileOverlay
 */
public class TileOverlayController implements TileOverlayOptionsSink {
    private final TileOverlay tileOverlay;
    private String urlTemplate;
    private int tileWidth = 256;
    private int tileHeight = 256;
    private int minZoom = 3;
    private int maxZoom = 20;
    private boolean diskCacheEnabled = true;
    private int diskCacheSize = 100;
    private boolean memoryCacheEnabled = true;
    private int memoryCacheSize = 50;
    private int preloadMargin = 1;
    private int maxConcurrentRequests = 4;

    public TileOverlayController(TileOverlay tileOverlay) {
        this.tileOverlay = tileOverlay;
    }

    public void remove() {
        if (tileOverlay != null) {
            tileOverlay.remove();
        }
    }

    public String getTileOverlayId() {
        return tileOverlay != null ? tileOverlay.getId() : null;
    }

    public void clearTileCache() {
        if (tileOverlay != null) {
            tileOverlay.clearTileCache();
        }
    }

    @Override
    public void setUrlTemplate(String urlTemplate) {
        this.urlTemplate = urlTemplate;
        // Note: URL template cannot be changed after creation in AMap SDK
        // The tile overlay needs to be recreated for URL changes
    }

    @Override
    public void setTileWidth(int tileWidth) {
        this.tileWidth = tileWidth;
    }

    @Override
    public void setTileHeight(int tileHeight) {
        this.tileHeight = tileHeight;
    }

    @Override
    public void setVisible(boolean visible) {
        if (tileOverlay != null) {
            tileOverlay.setVisible(visible);
        }
    }

    @Override
    public void setTransparency(float transparency) {
        // Note: AMap SDK TileOverlay does not support setTransparency
        // Store value locally for potential future use
    }

    @Override
    public void setZIndex(float zIndex) {
        if (tileOverlay != null) {
            tileOverlay.setZIndex(zIndex);
        }
    }

    @Override
    public void setMinZoom(int minZoom) {
        this.minZoom = minZoom;
    }

    @Override
    public void setMaxZoom(int maxZoom) {
        this.maxZoom = maxZoom;
    }

    @Override
    public void setDiskCacheEnabled(boolean enabled) {
        this.diskCacheEnabled = enabled;
    }

    @Override
    public void setDiskCacheSize(int size) {
        this.diskCacheSize = size;
    }

    @Override
    public void setMemoryCacheEnabled(boolean enabled) {
        this.memoryCacheEnabled = enabled;
    }

    @Override
    public void setMemoryCacheSize(int size) {
        this.memoryCacheSize = size;
    }

    @Override
    public void setPreloadMargin(int margin) {
        this.preloadMargin = margin;
    }

    @Override
    public void setMaxConcurrentRequests(int count) {
        this.maxConcurrentRequests = count;
    }

    public String getUrlTemplate() {
        return urlTemplate;
    }

    public int getTileWidth() {
        return tileWidth;
    }

    public int getTileHeight() {
        return tileHeight;
    }

    public int getMinZoom() {
        return minZoom;
    }

    public int getMaxZoom() {
        return maxZoom;
    }

    public boolean isDiskCacheEnabled() {
        return diskCacheEnabled;
    }

    public int getDiskCacheSize() {
        return diskCacheSize;
    }

    public boolean isMemoryCacheEnabled() {
        return memoryCacheEnabled;
    }

    public int getMemoryCacheSize() {
        return memoryCacheSize;
    }

    public int getPreloadMargin() {
        return preloadMargin;
    }

    public int getMaxConcurrentRequests() {
        return maxConcurrentRequests;
    }
}
