//
//  WalkingEngine.h
//  Ghost Walker
//
//  Core walking simulation with OSRM routing and human-like movement
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class WalkingEngine;

@protocol WalkingEngineDelegate <NSObject>
@optional
- (void)walkingEngineDidUpdateLocation:(WalkingEngine *)engine;
- (void)walkingEngineDidFinish:(WalkingEngine *)engine;
@end

@interface WalkingEngine : NSObject

// Delegate
@property (nonatomic, weak) id<WalkingEngineDelegate> delegate;

// State
@property (nonatomic, assign, readonly) BOOL isWalking;
@property (nonatomic, assign) CLLocationCoordinate2D destination;
@property (nonatomic, assign) CLLocationCoordinate2D currentSpoofedLocation;
@property (nonatomic, assign) double remainingDistance;

// Route
@property (nonatomic, strong, readonly) NSMutableArray<CLLocation *> *currentRoute;
@property (nonatomic, strong, readonly) NSMutableArray<CLLocation *> *walkedPath;

// Settings
@property (nonatomic, assign) double walkingSpeed;    // m/s (default 1.4)
@property (nonatomic, assign) double driftAmount;     // meters (default 3.0)
@property (nonatomic, assign) double accuracyMin;     // meters (default 10)
@property (nonatomic, assign) double accuracyMax;     // meters (default 45)

// Methods
- (void)setDestination:(CLLocationCoordinate2D)coordinate;
- (void)startWalkingFrom:(CLLocationCoordinate2D)start;
- (void)stopWalking;
- (void)resetAll;

@end
