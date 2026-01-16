package com.amap.flutter.map.overlays.tileoverlay;

import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.amap.api.maps.AMap;
import com.amap.api.maps.model.TileOverlay;
import com.amap.api.maps.model.TileOverlayOptions;
import com.amap.flutter.map.MyMethodCallHandler;
import com.amap.flutter.map.overlays.AbstractOverlayController;
import com.amap.flutter.map.utils.Const;
import com.amap.flutter.map.utils.ConvertUtil;
import com.amap.flutter.map.utils.LogUtil;

import java.util.List;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Controller for managing TileOverlays
 */
public class TileOverlaysController
        extends AbstractOverlayController<TileOverlayController>
        implements MyMethodCallHandler {

    private static final String CLASS_NAME = "TileOverlaysController";

    public TileOverlaysController(MethodChannel methodChannel, AMap amap) {
        super(methodChannel, amap);
    }

    @Override
    public String[] getRegisterMethodIdArray() {
        return Const.METHOD_ID_LIST_FOR_TILE_OVERLAY;
    }

    @Override
    public void doMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LogUtil.i(CLASS_NAME, "doMethodCall===>" + call.method);
        String methodStr = call.method;
        switch (methodStr) {
            case Const.METHOD_TILE_OVERLAY_UPDATE:
                invokeTileOverlayOptions(call, result);
                break;
        }
    }

    /**
     * Handle tile overlay update method call
     */
    private void invokeTileOverlayOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object listToAdd = methodCall.argument("tileOverlaysToAdd");
        addByList((List<Object>) listToAdd);
        Object listToChange = methodCall.argument("tileOverlaysToChange");
        updateByList((List<Object>) listToChange);
        Object tileOverlayIdsToRemove = methodCall.argument("tileOverlayIdsToRemove");
        removeByIdList((List<Object>) tileOverlayIdsToRemove);
        result.success(null);
    }

    /**
     * Add tile overlays from list
     */
    public void addByList(List<Object> tileOverlaysToAdd) {
        if (tileOverlaysToAdd != null) {
            for (Object tileOverlayToAdd : tileOverlaysToAdd) {
                addTileOverlay(tileOverlayToAdd);
            }
        }
    }

    /**
     * Add a single tile overlay
     */
    private void addTileOverlay(Object tileOverlayObj) {
        if (null != amap) {
            TileOverlayOptionsBuilder builder = new TileOverlayOptionsBuilder();
            String dartId = TileOverlayUtil.interpretOptions(tileOverlayObj, builder);
            if (!TextUtils.isEmpty(dartId)) {
                TileOverlayOptions tileOverlayOptions = builder.build();
                final TileOverlay tileOverlay = amap.addTileOverlay(tileOverlayOptions);
                TileOverlayController tileOverlayController = new TileOverlayController(tileOverlay);
                // Store builder values in controller for later reference
                tileOverlayController.setUrlTemplate(builder.getUrlTemplate());
                tileOverlayController.setTileWidth(builder.getTileWidth());
                tileOverlayController.setTileHeight(builder.getTileHeight());
                tileOverlayController.setMinZoom(builder.getMinZoom());
                tileOverlayController.setMaxZoom(builder.getMaxZoom());
                tileOverlayController.setDiskCacheEnabled(builder.isDiskCacheEnabled());
                tileOverlayController.setDiskCacheSize(builder.getDiskCacheSize());
                tileOverlayController.setMemoryCacheEnabled(builder.isMemoryCacheEnabled());
                tileOverlayController.setMemoryCacheSize(builder.getMemoryCacheSize());

                controllerMapByDartId.put(dartId, tileOverlayController);
                idMapByOverlyId.put(tileOverlay.getId(), dartId);
                LogUtil.i(CLASS_NAME, "addTileOverlay success, dartId=" + dartId);
            }
        }
    }

    /**
     * Update tile overlays from list
     */
    private void updateByList(List<Object> tileOverlaysToChange) {
        if (tileOverlaysToChange != null) {
            for (Object tileOverlayToChange : tileOverlaysToChange) {
                update(tileOverlayToChange);
            }
        }
    }

    /**
     * Update a single tile overlay
     */
    private void update(Object tileOverlayToChange) {
        Object tileOverlayId = ConvertUtil.getKeyValueFromMapObject(tileOverlayToChange, "id");
        if (null != tileOverlayId) {
            TileOverlayController tileOverlayController = controllerMapByDartId.get(tileOverlayId);
            if (null != tileOverlayController) {
                TileOverlayUtil.interpretOptions(tileOverlayToChange, tileOverlayController);
                // Clear cache to refresh tiles
                tileOverlayController.clearTileCache();
                LogUtil.i(CLASS_NAME, "updateTileOverlay success, dartId=" + tileOverlayId);
            }
        }
    }

    /**
     * Remove tile overlays by ID list
     */
    private void removeByIdList(List<Object> tileOverlayIdsToRemove) {
        if (tileOverlayIdsToRemove == null) {
            return;
        }
        for (Object rawTileOverlayId : tileOverlayIdsToRemove) {
            if (rawTileOverlayId == null) {
                continue;
            }
            String tileOverlayId = (String) rawTileOverlayId;
            final TileOverlayController tileOverlayController = controllerMapByDartId.remove(tileOverlayId);
            if (tileOverlayController != null) {
                idMapByOverlyId.remove(tileOverlayController.getTileOverlayId());
                tileOverlayController.remove();
                LogUtil.i(CLASS_NAME, "removeTileOverlay success, dartId=" + tileOverlayId);
            }
        }
    }
}
