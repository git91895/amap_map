package com.amap.flutter.map.overlays.marker;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.AnimatorSet;
import android.animation.ObjectAnimator;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.view.View;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;

import androidx.annotation.NonNull;

import com.amap.api.maps.AMap;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.model.Poi;
import com.amap.flutter.map.MyMethodCallHandler;
import com.amap.flutter.map.overlays.AbstractOverlayController;
import com.amap.flutter.map.utils.Const;
import com.amap.flutter.map.utils.ConvertUtil;
import com.amap.flutter.map.utils.LogUtil;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * @author whm
 * @date 2020/11/6 5:38 PM
 * @mail hongming.whm@alibaba-inc.com
 * @since
 */
public class MarkersController
        extends AbstractOverlayController<MarkerController>
        implements MyMethodCallHandler,
        AMap.OnMapClickListener,
        AMap.OnMarkerClickListener,
        AMap.OnMarkerDragListener,
        AMap.OnPOIClickListener {
    private static final String CLASS_NAME = "MarkersController";
    private String selectedMarkerDartId;
    private View selectedMarkerView; // 当前选中的标记点视图
    private float selectedViewOriginalScaleX = 1.0f; // 选中视图的原始 scaleX
    private float selectedViewOriginalScaleY = 1.0f; // 选中视图的原始 scaleY

    public MarkersController(MethodChannel methodChannel, AMap amap) {
        super(methodChannel, amap);
        amap.addOnMarkerClickListener(this);
        amap.addOnMarkerDragListener(this);
        amap.addOnMapClickListener(this);
        amap.addOnPOIClickListener(this);
    }

    @Override
    public String[] getRegisterMethodIdArray() {
        return Const.METHOD_ID_LIST_FOR_MARKER;
    }


    @Override
    public void doMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LogUtil.i(CLASS_NAME, "doMethodCall===>" + call.method);
        switch (call.method) {
            case Const.METHOD_MARKER_UPDATE:
                invokeMarkerOptions(call, result);
                break;
            case Const.METHOD_MARKER_DESELECT:
                deselectCurrentMarker();
                result.success(null);
                break;
            case Const.METHOD_MARKER_SELECT:
                String markerId = call.argument("markerId");
                selectMarkerWithId(markerId);
                result.success(null);
                break;
        }
    }


    /**
     * 执行主动方法更新marker
     *
     * @param methodCall
     * @param result
     */
    public void invokeMarkerOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object markersToAdd = methodCall.argument("markersToAdd");
        addByList((List<Object>) markersToAdd);
        Object markersToChange = methodCall.argument("markersToChange");
        updateByList((List<Object>) markersToChange);
        Object markerIdsToRemove = methodCall.argument("markerIdsToRemove");
        removeByIdList((List<Object>) markerIdsToRemove);
        result.success(null);
    }

    public void addByList(List<Object> markersToAdd) {
        if (markersToAdd != null) {
            for (Object markerToAdd : markersToAdd) {
                add(markerToAdd);
            }
        }
    }

    private void add(Object markerObj) {
        if (null != amap) {
            MarkerOptionsBuilder builder = new MarkerOptionsBuilder();
            String dartMarkerId = MarkerUtil.interpretMarkerOptions(markerObj, builder);
            if (!TextUtils.isEmpty(dartMarkerId)) {
                MarkerOptions markerOptions = builder.build();
                final Marker marker = amap.addMarker(markerOptions);
                Object clickable = ConvertUtil.getKeyValueFromMapObject(markerObj, "clickable");
                if (null != clickable) {
                    marker.setClickable(ConvertUtil.toBoolean(clickable));
                }
                MarkerController markerController = new MarkerController(marker);
                controllerMapByDartId.put(dartMarkerId, markerController);
                idMapByOverlyId.put(marker.getId(), dartMarkerId);
            }
        }

    }

    private void updateByList(List<Object> markersToChange) {
        if (markersToChange != null) {
            for (Object markerToChange : markersToChange) {
                update(markerToChange);
            }
        }
    }

    private void update(Object markerToChange) {
        Object dartMarkerId = ConvertUtil.getKeyValueFromMapObject(markerToChange, "id");
        if (null != dartMarkerId) {
            MarkerController markerController = controllerMapByDartId.get(dartMarkerId);
            if (null != markerController) {
                MarkerUtil.interpretMarkerOptions(markerToChange, markerController);
            }
        }
    }


    private void removeByIdList(List<Object> markerIdsToRemove) {
        if (markerIdsToRemove == null) {
            return;
        }
        for (Object rawMarkerId : markerIdsToRemove) {
            if (rawMarkerId == null) {
                continue;
            }
            String markerId = (String) rawMarkerId;
            final MarkerController markerController = controllerMapByDartId.remove(markerId);
            if (markerController != null) {

                idMapByOverlyId.remove(markerController.getMarkerId());
                markerController.remove();
            }
        }
    }

    private void showMarkerInfoWindow(String dartMarkId) {
        MarkerController markerController = controllerMapByDartId.get(dartMarkId);
        if (null != markerController) {
            markerController.showInfoWindow();
        }
    }

    private void hideMarkerInfoWindow(String dartMarkId, LatLng newPosition) {
        if (TextUtils.isEmpty(dartMarkId)) {
            return;
        }
        if (!controllerMapByDartId.containsKey(dartMarkId)) {
            return;
        }
        MarkerController markerController = controllerMapByDartId.get(dartMarkId);
        if (null != markerController) {
            if (null != newPosition && null != markerController.getPosition()) {
                if (markerController.getPosition().equals(newPosition)) {
                    return;
                }
            }
            markerController.hideInfoWindow();
        }
    }

    @Override
    public void onMapClick(LatLng latLng) {
        hideMarkerInfoWindow(selectedMarkerDartId, null);
    }

    @Override
    public boolean onMarkerClick(Marker marker) {
        String dartId = idMapByOverlyId.get(marker.getId());
        if (null == dartId) {
            return false;
        }

        // 执行点击放大动画
        animateMarkerClick(marker);

        final Map<String, Object> data = new HashMap<>(1);
        data.put("markerId", dartId);
        selectedMarkerDartId = dartId;
        showMarkerInfoWindow(dartId);
        methodChannel.invokeMethod("marker#onTap", data);
        LogUtil.i(CLASS_NAME, "onMarkerClick==>" + data);
        return true;
    }

    /**
     * 执行 Marker 点击缩放动画
     * 通过反射获取 Marker 内部的 View 并执行动画
     *
     * @param marker 需要执行动画的 Marker
     */
    private void animateMarkerClick(final Marker marker) {
        try {
            // 尝试通过反射获取 Marker 内部的 View
            Field field = marker.getClass().getDeclaredField("aq");
            field.setAccessible(true);
            Object glOverlayLayer = field.get(marker);

            if (glOverlayLayer != null) {
                Field viewField = glOverlayLayer.getClass().getDeclaredField("c");
                viewField.setAccessible(true);
                final View markerView = (View) viewField.get(glOverlayLayer);

                if (markerView != null) {
                    new Handler(Looper.getMainLooper()).post(new Runnable() {
                        @Override
                        public void run() {
                            executeScaleAnimation(markerView);
                        }
                    });
                    return;
                }
            }
        } catch (Exception e) {
            LogUtil.i(CLASS_NAME, "Reflection failed, using alternative animation: " + e.getMessage());
        }

        // 备用方案：使用透明度动画模拟点击反馈
        executeAlphaAnimation(marker);
    }

    /**
     * 执行 View 的放大+多次弹跳动画
     *
     * @param view 需要执行动画的 View
     */
    private void executeScaleAnimation(final View view) {
        // 先取消之前选中的标记点（无动画）
        deselectCurrentMarkerWithoutAnimation();

        // 保存原始值
        final float originalScaleX = view.getScaleX();
        final float originalScaleY = view.getScaleY();
        final float originalTranslationY = view.getTranslationY();

        // 记录当前选中的标记点和原始缩放值
        selectedMarkerView = view;
        selectedViewOriginalScaleX = originalScaleX;
        selectedViewOriginalScaleY = originalScaleY;

        // 放大动画（保持放大状态，不回弹）
        ObjectAnimator scaleUpX = ObjectAnimator.ofFloat(view, "scaleX", originalScaleX, originalScaleX * 1.4f);
        ObjectAnimator scaleUpY = ObjectAnimator.ofFloat(view, "scaleY", originalScaleY, originalScaleY * 1.4f);
        scaleUpX.setDuration(400);
        scaleUpY.setDuration(400);
        scaleUpX.setInterpolator(new DecelerateInterpolator());
        scaleUpY.setInterpolator(new DecelerateInterpolator());

        AnimatorSet scaleAnimator = new AnimatorSet();
        scaleAnimator.playTogether(scaleUpX, scaleUpY);

        // 放大完成后开始多次弹跳
        scaleAnimator.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                performBounceAnimation(view, originalTranslationY, 0);
            }
        });

        scaleAnimator.start();
    }

    /**
     * 取消选中当前标记点，恢复原始大小（带动画）
     */
    private void deselectCurrentMarker() {
        if (selectedMarkerView == null) {
            return;
        }

        final View view = selectedMarkerView;
        final float targetScaleX = selectedViewOriginalScaleX;
        final float targetScaleY = selectedViewOriginalScaleY;

        // 清除选中状态
        selectedMarkerView = null;

        // 执行恢复动画
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                ObjectAnimator scaleDownX = ObjectAnimator.ofFloat(view, "scaleX", view.getScaleX(), targetScaleX);
                ObjectAnimator scaleDownY = ObjectAnimator.ofFloat(view, "scaleY", view.getScaleY(), targetScaleY);
                scaleDownX.setDuration(250);
                scaleDownY.setDuration(250);
                scaleDownX.setInterpolator(new DecelerateInterpolator());
                scaleDownY.setInterpolator(new DecelerateInterpolator());

                AnimatorSet animatorSet = new AnimatorSet();
                animatorSet.playTogether(scaleDownX, scaleDownY);
                animatorSet.start();
            }
        });
    }

    /**
     * 取消选中当前标记点，立即恢复原始大小（无动画）
     */
    private void deselectCurrentMarkerWithoutAnimation() {
        if (selectedMarkerView == null) {
            return;
        }

        selectedMarkerView.setScaleX(selectedViewOriginalScaleX);
        selectedMarkerView.setScaleY(selectedViewOriginalScaleY);
        selectedMarkerView = null;
    }

    /**
     * 根据 markerId 选中指定标记点（执行放大+弹跳动画）
     *
     * @param markerId 标记点 ID (dartId)
     */
    private void selectMarkerWithId(String markerId) {
        if (markerId == null || markerId.isEmpty()) {
            return;
        }

        // 从 controllerMapByDartId 中获取 MarkerController
        MarkerController controller = controllerMapByDartId.get(markerId);
        if (controller == null) {
            LogUtil.i(CLASS_NAME, "selectMarkerWithId: marker not found for id=" + markerId);
            return;
        }

        // 获取 Marker 对象并执行动画
        Marker marker = controller.getMarker();
        if (marker != null) {
            animateMarkerClick(marker);
            selectedMarkerDartId = markerId;
            LogUtil.i(CLASS_NAME, "selectMarkerWithId: selected marker id=" + markerId);
        }
    }

    /**
     * 执行多次弹跳动画（递归）
     *
     * @param view 需要执行动画的 View
     * @param originalY 原始 Y 位置
     * @param bounceIndex 当前弹跳索引
     */
    private void performBounceAnimation(final View view, final float originalY, final int bounceIndex) {
        // 弹跳参数：高度逐渐递减
        final float[] bounceHeights = {50f, 24f, 12f};
        final long[] upDurations = {250, 180, 120};
        final long[] downDurations = {200, 150, 100};
        final int totalBounces = 3;

        if (bounceIndex >= totalBounces) {
            return;
        }

        float currentHeight = bounceHeights[bounceIndex];
        long upDuration = upDurations[bounceIndex];
        long downDuration = downDurations[bounceIndex];

        // 向上跳跃
        ObjectAnimator jumpUp = ObjectAnimator.ofFloat(view, "translationY", originalY, originalY - currentHeight);
        jumpUp.setDuration(upDuration);
        jumpUp.setInterpolator(new DecelerateInterpolator());

        // 落下
        ObjectAnimator jumpDown = ObjectAnimator.ofFloat(view, "translationY", originalY - currentHeight, originalY);
        jumpDown.setDuration(downDuration);
        jumpDown.setInterpolator(new AccelerateInterpolator());

        AnimatorSet bounceAnimator = new AnimatorSet();
        bounceAnimator.playSequentially(jumpUp, jumpDown);

        // 落下完成后继续下一次弹跳
        bounceAnimator.addListener(new AnimatorListenerAdapter() {
            @Override
            public void onAnimationEnd(Animator animation) {
                performBounceAnimation(view, originalY, bounceIndex + 1);
            }
        });

        bounceAnimator.start();
    }

    /**
     * 备用方案：执行透明度+位移动画模拟跳跃
     *
     * @param marker 需要执行动画的 Marker
     */
    private void executeAlphaAnimation(final Marker marker) {
        // 高德地图 Marker 不支持直接设置位移，使用透明度变化作为点击反馈
        final float originalAlpha = marker.getAlpha();
        final Handler handler = new Handler(Looper.getMainLooper());

        // 快速闪烁效果
        handler.post(new Runnable() {
            @Override
            public void run() {
                marker.setAlpha(originalAlpha * 0.5f);
            }
        });

        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                marker.setAlpha(originalAlpha);
            }
        }, 100);

        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                marker.setAlpha(originalAlpha * 0.7f);
            }
        }, 200);

        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                marker.setAlpha(originalAlpha);
            }
        }, 300);
    }

    @Override
    public void onMarkerDragStart(Marker marker) {

    }

    @Override
    public void onMarkerDrag(Marker marker) {

    }

    @Override
    public void onMarkerDragEnd(Marker marker) {
        String markerId = marker.getId();
        String dartId = idMapByOverlyId.get(markerId);
        LatLng latLng = marker.getPosition();
        if (null == dartId) {
            return;
        }
        final Map<String, Object> data = new HashMap<>(2);
        data.put("markerId", dartId);
        data.put("position", ConvertUtil.latLngToList(latLng));
        methodChannel.invokeMethod("marker#onDragEnd", data);

        LogUtil.i(CLASS_NAME, "onMarkerDragEnd==>" + data);
    }

    @Override
    public void onPOIClick(Poi poi) {
        hideMarkerInfoWindow(selectedMarkerDartId, null != poi ? poi.getCoordinate() : null);
    }

}
