package com.amap.flutter.map.overlays.tileoverlay;

import com.amap.flutter.map.utils.ConvertUtil;

import java.util.Map;

/**
 * Utility class for parsing TileOverlay options
 */
public class TileOverlayUtil {

    /**
     * Parse tile overlay options from Flutter arguments
     *
     * @param tileOverlayObj The raw object from Flutter
     * @param sink           The sink to receive parsed options
     * @return The dart ID of the tile overlay
     */
    @SuppressWarnings("unchecked")
    public static String interpretOptions(Object tileOverlayObj, TileOverlayOptionsSink sink) {
        if (null == tileOverlayObj) {
            return null;
        }

        Map<?, ?> data = ConvertUtil.toMap(tileOverlayObj);
        String dartId = (String) data.get("id");

        // Parse tileProvider
        Object tileProviderObj = data.get("tileProvider");
        if (tileProviderObj != null) {
            Map<?, ?> tileProvider = ConvertUtil.toMap(tileProviderObj);
            if (tileProvider != null) {
                Object urlTemplate = tileProvider.get("urlTemplate");
                if (urlTemplate != null) {
                    sink.setUrlTemplate((String) urlTemplate);
                }

                Object tileWidth = tileProvider.get("tileWidth");
                if (tileWidth != null) {
                    sink.setTileWidth(ConvertUtil.toInt(tileWidth));
                }

                Object tileHeight = tileProvider.get("tileHeight");
                if (tileHeight != null) {
                    sink.setTileHeight(ConvertUtil.toInt(tileHeight));
                }
            }
        }

        Object visible = data.get("visible");
        if (visible != null) {
            sink.setVisible(ConvertUtil.toBoolean(visible));
        }

        Object transparency = data.get("transparency");
        if (transparency != null) {
            sink.setTransparency(ConvertUtil.toFloat(transparency));
        }

        Object zIndex = data.get("zIndex");
        if (zIndex != null) {
            sink.setZIndex(ConvertUtil.toFloat(zIndex));
        }

        Object minZoom = data.get("minZoom");
        if (minZoom != null) {
            sink.setMinZoom(ConvertUtil.toInt(minZoom));
        }

        Object maxZoom = data.get("maxZoom");
        if (maxZoom != null) {
            sink.setMaxZoom(ConvertUtil.toInt(maxZoom));
        }

        Object diskCacheEnabled = data.get("diskCacheEnabled");
        if (diskCacheEnabled != null) {
            sink.setDiskCacheEnabled(ConvertUtil.toBoolean(diskCacheEnabled));
        }

        Object diskCacheSize = data.get("diskCacheSize");
        if (diskCacheSize != null) {
            sink.setDiskCacheSize(ConvertUtil.toInt(diskCacheSize));
        }

        Object memoryCacheEnabled = data.get("memoryCacheEnabled");
        if (memoryCacheEnabled != null) {
            sink.setMemoryCacheEnabled(ConvertUtil.toBoolean(memoryCacheEnabled));
        }

        Object memoryCacheSize = data.get("memoryCacheSize");
        if (memoryCacheSize != null) {
            sink.setMemoryCacheSize(ConvertUtil.toInt(memoryCacheSize));
        }

        return dartId;
    }
}
