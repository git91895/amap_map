package com.amap.flutter.map.overlays.tileoverlay;

import com.amap.api.maps.model.TileOverlayOptions;
import com.amap.api.maps.model.UrlTileProvider;

import java.net.MalformedURLException;
import java.net.URL;

/**
 * TileOverlay options builder
 */
public class TileOverlayOptionsBuilder implements TileOverlayOptionsSink {
    private String urlTemplate;
    private int tileWidth = 256;
    private int tileHeight = 256;
    private boolean visible = true;
    private float transparency = 0.0f;
    private float zIndex = 0.0f;
    private int minZoom = 3;
    private int maxZoom = 20;
    private boolean diskCacheEnabled = true;
    private int diskCacheSize = 100;
    private boolean memoryCacheEnabled = true;
    private int memoryCacheSize = 50;

    @Override
    public void setUrlTemplate(String urlTemplate) {
        this.urlTemplate = urlTemplate;
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
        this.visible = visible;
    }

    @Override
    public void setTransparency(float transparency) {
        this.transparency = transparency;
    }

    @Override
    public void setZIndex(float zIndex) {
        this.zIndex = zIndex;
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

    public TileOverlayOptions build() {
        TileOverlayOptions options = new TileOverlayOptions();

        // Create URL tile provider
        if (urlTemplate != null && !urlTemplate.isEmpty()) {
            final String template = urlTemplate;
            UrlTileProvider tileProvider = new UrlTileProvider(tileWidth, tileHeight) {
                @Override
                public URL getTileUrl(int x, int y, int zoom) {
                    // Replace placeholders in URL template
                    String urlStr = template;
                    urlStr = urlStr.replace("{x}", String.valueOf(x));
                    urlStr = urlStr.replace("{y}", String.valueOf(y));
                    urlStr = urlStr.replace("{z}", String.valueOf(zoom));
                    try {
                        return new URL(urlStr);
                    } catch (MalformedURLException e) {
                        return null;
                    }
                }
            };
            options.tileProvider(tileProvider);
        }

        options.visible(visible);
        options.zIndex(zIndex);
        options.diskCacheEnabled(diskCacheEnabled);
        options.diskCacheDir("/storage/emulated/0/amap/cache");
        options.memoryCacheEnabled(memoryCacheEnabled);

        return options;
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

    public boolean isVisible() {
        return visible;
    }

    public float getTransparency() {
        return transparency;
    }

    public float getZIndex() {
        return zIndex;
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
}
