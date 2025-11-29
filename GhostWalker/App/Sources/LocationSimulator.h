//
//  LocationSimulator.h
//  Ghost Walker
//
//  High-level wrapper around CLSimulationManager that provides:
//  - Continuous location updates with drift/accuracy simulation
//  - Timer-based updates for "live" location appearance
//  - Support for static, walking, and driving modes
//
//  This uses Apple's native location simulation API - the same method
//  that locsim and Geranium use. Works on all jailbreaks!
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class LocationSimulator;

@protocol LocationSimulatorDelegate <NSObject>
@optional
- (void)locationSimulator:(LocationSimulator *)simulator didUpdateToLocation:(CLLocationCoordinate2D)location;
- (void)locationSimulatorDidStart:(LocationSimulator *)simulator;
- (void)locationSimulatorDidStop:(LocationSimulator *)simulator;
- (void)locationSimulator:(LocationSimulator *)simulator didFailWithError:(NSError *)error;
@end

@interface LocationSimulator : NSObject

@property (nonatomic, weak) id<LocationSimulatorDelegate> delegate;

// Current state
@property (nonatomic, readonly) BOOL isSimulating;
@property (nonatomic, readonly) CLLocationCoordinate2D currentLocation;
@property (nonatomic, readonly) double currentAccuracy;
@property (nonatomic, assign) double currentSpeed;
@property (nonatomic, assign) double currentCourse;
@property (nonatomic, readonly) NSUInteger updateCount;
@property (nonatomic, readonly) NSDate *startTime;

// Accuracy settings (meters)
@property (nonatomic, assign) double accuracyMin;      // Default 10m
@property (nonatomic, assign) double accuracyMax;      // Default 45m
@property (nonatomic, assign) double accuracyUpdateInterval;  // Default 10 seconds

// Drift settings (meters)
@property (nonatomic, assign) double driftMin;         // Default 2m
@property (nonatomic, assign) double driftMax;         // Default 5m

// Altitude settings (meters)
@property (nonatomic, assign) double altitude;         // Default 0
@property (nonatomic, assign) BOOL altitudeEnabled;    // Default NO

// Update interval (seconds)
@property (nonatomic, assign) double updateInterval;   // Default 1.0

// Singleton (for global access)
+ (instancetype)sharedSimulator;

// Core simulation methods
- (BOOL)startSimulatingLocation:(CLLocationCoordinate2D)location;
- (BOOL)startSimulatingLocation:(CLLocationCoordinate2D)location 
                       accuracy:(double)accuracy 
                          speed:(double)speed 
                         course:(double)course;

- (void)updateLocation:(CLLocationCoordinate2D)location;
- (void)updateLocation:(CLLocationCoordinate2D)location 
              accuracy:(double)accuracy 
                 speed:(double)speed 
                course:(double)course;

- (void)stopSimulating;

// Convenience methods
- (void)setBaseLocation:(CLLocationCoordinate2D)location;  // For drift calculations
- (void)applyDriftToCurrentLocation;  // Manually trigger drift

@end
