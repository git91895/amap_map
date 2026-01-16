// Copyright 2024
// TileOverlayUpdates for amap_map plugin

import 'package:flutter/foundation.dart' show setEquals;
import 'types.dart';

/// 该类主要用以描述 [TileOverlay] 的增删改等更新操作
class TileOverlayUpdates {
  /// 通过 tileOverlay 的前后更新集合构造一个 TileOverlayUpdates
  TileOverlayUpdates.from(
      Set<TileOverlay> previous, Set<TileOverlay> current) {
    final Map<String, TileOverlay> previousTileOverlays =
        keyByTileOverlayId(previous);
    final Map<String, TileOverlay> currentTileOverlays =
        keyByTileOverlayId(current);

    final Set<String> prevTileOverlayIds = previousTileOverlays.keys.toSet();
    final Set<String> currentTileOverlayIds = currentTileOverlays.keys.toSet();

    TileOverlay idToCurrentTileOverlay(String id) {
      return currentTileOverlays[id]!;
    }

    final Set<String> tempTileOverlayIdsToRemove =
        prevTileOverlayIds.difference(currentTileOverlayIds);

    final Set<TileOverlay> tempTileOverlaysToAdd = currentTileOverlayIds
        .difference(prevTileOverlayIds)
        .map(idToCurrentTileOverlay)
        .toSet();

    bool hasChanged(TileOverlay current) {
      final TileOverlay previous = previousTileOverlays[current.id]!;
      return current != previous;
    }

    final Set<TileOverlay> tempTileOverlaysToChange = currentTileOverlayIds
        .intersection(prevTileOverlayIds)
        .map(idToCurrentTileOverlay)
        .where(hasChanged)
        .toSet();

    tileOverlaysToAdd = tempTileOverlaysToAdd;
    tileOverlayIdsToRemove = tempTileOverlayIdsToRemove;
    tileOverlaysToChange = tempTileOverlaysToChange;
  }

  /// 用于添加 tileOverlay 的集合
  Set<TileOverlay>? tileOverlaysToAdd;

  /// 需要删除的 tileOverlay 的 id 集合
  Set<String>? tileOverlayIdsToRemove;

  /// 用于更新 tileOverlay 的集合
  Set<TileOverlay>? tileOverlaysToChange;

  /// 将对象转换为可序列化的对象
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> updateMap = <String, dynamic>{};

    void addIfNonNull(String fieldName, dynamic value) {
      if (value != null) {
        updateMap[fieldName] = value;
      }
    }

    addIfNonNull(
        'tileOverlaysToAdd', serializeOverlaySet(tileOverlaysToAdd!));
    addIfNonNull(
        'tileOverlaysToChange', serializeOverlaySet(tileOverlaysToChange!));
    addIfNonNull('tileOverlayIdsToRemove', tileOverlayIdsToRemove?.toList());

    return updateMap;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! TileOverlayUpdates) return false;
    final TileOverlayUpdates typedOther = other;
    return setEquals(tileOverlaysToAdd, typedOther.tileOverlaysToAdd) &&
        setEquals(tileOverlayIdsToRemove, typedOther.tileOverlayIdsToRemove) &&
        setEquals(tileOverlaysToChange, typedOther.tileOverlaysToChange);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        tileOverlaysToAdd,
        tileOverlayIdsToRemove,
        tileOverlaysToChange,
      ]);

  @override
  String toString() {
    return 'TileOverlayUpdates{tileOverlaysToAdd: $tileOverlaysToAdd, '
        'tileOverlayIdsToRemove: $tileOverlayIdsToRemove, '
        'tileOverlaysToChange: $tileOverlaysToChange}';
  }
}
