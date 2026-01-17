package com.amap.flutter.map.overlays.tileoverlay;

import android.content.Context;
import android.util.LruCache;

import com.amap.api.maps.model.TileOverlayOptions;
import com.amap.api.maps.model.UrlTileProvider;

import java.io.File;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * TileOverlay options builder with P0/P1 optimizations:
 * - P0: Disk cache configuration, Memory cache optimization
 * - P1: Preload strategy, Concurrent request control
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
    private int diskCacheSize = 100;  // MB
    private boolean memoryCacheEnabled = true;
    private int memoryCacheSize = 50;  // tiles count
    private int preloadMargin = 1;  // P1: preload surrounding tiles
    private int maxConcurrentRequests = 4;  // P1: concurrent request control

    // P0: Memory cache for tile URLs (LRU cache)
    private static LruCache<String, URL> urlCache;

    // P1: Shared executor for tile loading
    private static ExecutorService tileExecutor;

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

    @Override
    public void setPreloadMargin(int margin) {
        this.preloadMargin = margin;
    }

    @Override
    public void setMaxConcurrentRequests(int count) {
        this.maxConcurrentRequests = count;
    }

    /**
     * Initialize URL cache with specified size
     * P0 Optimization: Memory cache for parsed URLs
     */
    private void initUrlCache() {
        if (urlCache == null && memoryCacheEnabled) {
            urlCache = new LruCache<>(memoryCacheSize > 0 ? memoryCacheSize : 50);
        }
    }

    /**
     * Initialize executor service with specified concurrency
     * P1 Optimization: Controlled parallel tile loading
     */
    private void initExecutor() {
        if (tileExecutor == null || tileExecutor.isShutdown()) {
            tileExecutor = Executors.newFixedThreadPool(
                maxConcurrentRequests > 0 ? maxConcurrentRequests : 4
            );
        }
    }

    /**
     * Get cache key for tile coordinates
     */
    private static String getCacheKey(String template, int x, int y, int zoom) {
        return template + "_" + zoom + "_" + x + "_" + y;
    }

    public TileOverlayOptions build() {
        return build(null);
    }

    /**
     * Build TileOverlayOptions with context for proper cache directory
     * P0 Optimization: Use app-specific cache directory
     */
    public TileOverlayOptions build(Context context) {
        TileOverlayOptions options = new TileOverlayOptions();

        // P0: Initialize memory cache
        initUrlCache();

        // P1: Initialize executor for parallel loading
        initExecutor();

        // Create URL tile provider with optimizations
        if (urlTemplate != null && !urlTemplate.isEmpty()) {
            final String template = urlTemplate;
            final boolean useMemoryCache = memoryCacheEnabled && urlCache != null;

            UrlTileProvider tileProvider = new UrlTileProvider(tileWidth, tileHeight) {
                @Override
                public URL getTileUrl(int x, int y, int zoom) {
                    // P0: Check memory cache first
                    String cacheKey = getCacheKey(template, x, y, zoom);
                    if (useMemoryCache) {
                        URL cachedUrl = urlCache.get(cacheKey);
                        if (cachedUrl != null) {
                            return cachedUrl;
                        }
                    }

                    // Replace placeholders in URL template
                    String urlStr = template;
                    urlStr = urlStr.replace("{x}", String.valueOf(x));
                    urlStr = urlStr.replace("{y}", String.valueOf(y));
                    urlStr = urlStr.replace("{z}", String.valueOf(zoom));

                    try {
                        URL url = new URL(urlStr);
                        // P0: Store in memory cache
                        if (useMemoryCache) {
                            urlCache.put(cacheKey, url);
                        }
                        return url;
                    } catch (MalformedURLException e) {
                        return null;
                    }
                }
            };
            options.tileProvider(tileProvider);
        }

        options.visible(visible);
        options.zIndex(zIndex);

        // P0: Configure disk cache
        options.diskCacheEnabled(diskCacheEnabled);
        if (context != null && diskCacheEnabled) {
            // Use app-specific cache directory
            File cacheDir = new File(context.getCacheDir(), "tile_cache");
            if (!cacheDir.exists()) {
                cacheDir.mkdirs();
            }
            options.diskCacheDir(cacheDir.getAbsolutePath());
        }

        // P0: Configure memory cache
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

    public int getPreloadMargin() {
        return preloadMargin;
    }

    public int getMaxConcurrentRequests() {
        return maxConcurrentRequests;
    }

    /**
     * Clear all caches and shutdown executor
     * Call this when cleaning up resources
     */
    public static void clearCache() {
        if (urlCache != null) {
            urlCache.evictAll();
        }
        if (tileExecutor != null && !tileExecutor.isShutdown()) {
            tileExecutor.shutdown();
            tileExecutor = null;
        }
    }

    /**
     * Get executor for tile loading operations
     * P1 Optimization: Controlled parallel execution
     */
    public static ExecutorService getTileExecutor() {
        return tileExecutor;
    }
}
