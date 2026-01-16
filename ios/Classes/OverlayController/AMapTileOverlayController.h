//
//  AMapTileOverlayController.h
//  amap_map
//
//  TileOverlay Controller for amap_map plugin
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>
#import <MAMapKit/MAMapKit.h>

NS_ASSUME_NONNULL_BEGIN

@class AMapTileOverlay;

@interface AMapTileOverlayController : NSObject

- (instancetype)init:(FlutterMethodChannel *)methodChannel
             mapView:(MAMapView *)mapView
           registrar:(NSObject<FlutterPluginRegistrar> *)registrar;

- (nullable AMapTileOverlay *)tileOverlayForId:(NSString *)tileOverlayId;

- (void)addTileOverlays:(NSArray *)tileOverlaysToAdd;

- (void)changeTileOverlays:(NSArray *)tileOverlaysToChange;

- (void)removeTileOverlayIds:(NSArray *)tileOverlayIdsToRemove;

@end

NS_ASSUME_NONNULL_END
