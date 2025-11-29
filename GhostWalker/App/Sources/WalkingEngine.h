//
//  WalkingEngine.h
//  Ghost Walker
//
//  Core location simulation engine with walking, driving, and static modes
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class WalkingEngine;

// Movement modes
typedef NS_ENUM(NSInteger, GhostMovementMode) {
    GhostMovementModeStatic = 0,    // Hold location forever
    GhostMovementModeWalking = 1,   // Walk along route
    GhostMovementModeDriving = 2,   // Drive along route (faster)
};

// Spoof status for UI feedback
typedef NS_ENUM(NSInteger, GhostSpoofStatus) {
    GhostSpoofStatusIdle = 0,       // Not spoofing
    GhostSpoofStatusActive = 1,     // Actively spoofing (static hold)
    GhostSpoofStatusMoving = 2,     // Moving along route
    GhostSpoofStatusError = 3,      // Error detected (failsafe)
};

@protocol WalkingEngineDelegate <NSObject>
@optional
- (void)walkingEngineDidUpdateLocation:(WalkingEngine *)engine;
- (void)walkingEngineDidFinish:(WalkingEngine *)engine;
- (void)walkingEngineDidDetectRubberBand:(WalkingEngine *)engine;
- (void)walkingEngineStatusDidChange:(WalkingEngine *)engine;
@end

@interface WalkingEngine : NSObject

// Delegate
@property (nonatomic, weak) id<WalkingEngineDelegate> delegate;

// State
@property (nonatomic, assign, readonly) BOOL isActive;           // Any spoofing active
@property (nonatomic, assign, readonly) BOOL isMoving;           // Moving along route
@property (nonatomic, assign, readonly) GhostSpoofStatus status;
@property (nonatomic, assign) GhostMovementMode movementMode;

// Locations
@property (nonatomic, assign) CLLocationCoordinate2D destination;
@property (nonatomic, assign) CLLocationCoordinate2D currentSpoofedLocation;
@property (nonatomic, assign) CLLocationCoordinate2D staticHoldLocation;  // For static mode
@property (nonatomic, assign) double remainingDistance;

// Route
@property (nonatomic, strong, readonly) NSMutableArray<CLLocation *> *currentRoute;
@property (nonatomic, strong, readonly) NSMutableArray<CLLocation *> *walkedPath;

// Speed Settings
@property (nonatomic, assign) double walkingSpeed;    // m/s (default 1.4)
@property (nonatomic, assign) double drivingSpeed;    // m/s (default 13.9 = 50 km/h)

// Accuracy Settings (user configurable)
@property (nonatomic, assign) double accuracyMin;     // Min accuracy in meters (default 10)
@property (nonatomic, assign) double accuracyMax;     // Max accuracy in meters (default 45)
@property (nonatomic, assign) double accuracyUpdateInterval;  // How often to change circle (default 10 seconds)

// Drift Settings
@property (nonatomic, assign) double driftMin;        // Min drift in meters (default 2)
@property (nonatomic, assign) double driftMax;        // Max drift in meters (default 5)

// Update interval
@property (nonatomic, assign) double updateInterval;  // Seconds between updates (default 1.0)

// Failsafe
@property (nonatomic, assign) double maxJumpDistance; // Max allowed jump before failsafe (default 100m)
@property (nonatomic, assign) BOOL failsafeTriggered;

// Verification
@property (nonatomic, strong, readonly) NSDate *spoofStartTime;
@property (nonatomic, assign, readonly) NSUInteger updateCount;

// Methods - Static Mode
- (void)startStaticSpoofAtLocation:(CLLocationCoordinate2D)location;
- (void)stopAllSpoofing;

// Methods - Route Mode
- (void)setDestination:(CLLocationCoordinate2D)coordinate;
- (void)startMovingFrom:(CLLocationCoordinate2D)start;
- (void)pauseMovement;
- (void)resumeMovement;

// Methods - Control
- (void)resetAll;

// Persistence control
- (void)enablePersistentMode:(BOOL)enabled;  // Keep spoofing even when app backgrounds

// Legacy compatibility
@property (nonatomic, assign) BOOL isWalking;  // Alias for isMoving
- (void)startWalkingFrom:(CLLocationCoordinate2D)start;
- (void)stopWalking;
@property (nonatomic, assign) double driftAmount;  // Legacy: uses driftMax

@end
