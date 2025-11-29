//
//  CLSimulationManager.h
//  Ghost Walker
//
//  Private CoreLocation API for location simulation
//  This is the same API that locsim and Geranium use
//  It communicates with locationd via XPC - no tweak injection needed!
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

// CLSimulationManager - Apple's private location simulation API
// This class exists in CoreLocation.framework but is not public
@interface CLSimulationManager : NSObject

// Simulation behavior settings
@property (assign, nonatomic) uint8_t locationDeliveryBehavior;
// 0 = pass through
// 1 = consider other factors  
// 2 = immediately deliver (default for simulation)

@property (assign, nonatomic) uint8_t locationRepeatBehavior;
// 0 = unavailable after last location
// 1 = repeat last location (good for static spoofing)
// 2 = loop (for GPX routes)

@property (assign, nonatomic) double locationDistance;
@property (assign, nonatomic) double locationInterval;
@property (assign, nonatomic) double locationSpeed;

// Simulation control
- (void)clearSimulatedLocations;
- (void)startLocationSimulation;
- (void)stopLocationSimulation;
- (void)appendSimulatedLocation:(CLLocation *)location;
- (void)flush;

// Scenario support (for GPX files)
- (void)loadScenarioFromURL:(NSURL *)url;

// WiFi/Cell simulation (optional)
- (void)setSimulatedWifiPower:(BOOL)power;
- (void)startWifiSimulation;
- (void)stopWifiSimulation;
- (void)setSimulatedCell:(id)cell;
- (void)startCellSimulation;
- (void)stopCellSimulation;

@end
