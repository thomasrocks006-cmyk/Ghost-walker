//
//  LocationSimulator.m
//  Ghost Walker
//
//  Implementation of CLSimulationManager wrapper
//  Provides continuous location updates with drift and accuracy variation
//

#import "LocationSimulator.h"
#import "CLSimulationManager.h"
#import <objc/runtime.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@interface LocationSimulator ()

// CLSimulationManager instance
@property (nonatomic, strong) CLSimulationManager *simManager;

// State (readwrite versions of readonly public properties)
@property (nonatomic, assign, readwrite) BOOL isSimulating;
@property (nonatomic, assign) CLLocationCoordinate2D currentLocation;
@property (nonatomic, assign) CLLocationCoordinate2D baseLocation;  // Location before drift
@property (nonatomic, assign, readwrite) double currentAccuracy;
@property (nonatomic, assign, readwrite) NSUInteger updateCount;
@property (nonatomic, strong, readwrite) NSDate *startTime;

// Timers
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSTimer *accuracyTimer;

// Last accuracy update time
@property (nonatomic, assign) NSTimeInterval lastAccuracyUpdate;

@end

@implementation LocationSimulator

#pragma mark - Singleton

static LocationSimulator *_sharedSimulator = nil;

+ (instancetype)sharedSimulator {
    @synchronized(self) {
        if (_sharedSimulator == nil) {
            _sharedSimulator = [[LocationSimulator alloc] init];
        }
    }
    return _sharedSimulator;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        // Check if CLSimulationManager exists
        Class simClass = NSClassFromString(@"CLSimulationManager");
        if (simClass) {
            _simManager = [[simClass alloc] init];
            NSLog(@"[GhostWalker] CLSimulationManager initialized successfully!");
        } else {
            NSLog(@"[GhostWalker] WARNING: CLSimulationManager class not found!");
            // Will need to fall back to locsim CLI
        }
        
        // Default settings
        _accuracyMin = 10.0;
        _accuracyMax = 45.0;
        _accuracyUpdateInterval = 10.0;
        _driftMin = 2.0;
        _driftMax = 5.0;
        _updateInterval = 1.0;
        
        _isSimulating = NO;
        _updateCount = 0;
        _currentAccuracy = 25.0;
        _currentSpeed = 0;
        _currentCourse = -1;
        
        // Register for app lifecycle
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillTerminate)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopSimulating];
}

#pragma mark - Core Simulation

- (BOOL)startSimulatingLocation:(CLLocationCoordinate2D)location {
    return [self startSimulatingLocation:location 
                                accuracy:self.currentAccuracy 
                                   speed:0 
                                  course:-1];
}

- (BOOL)startSimulatingLocation:(CLLocationCoordinate2D)location 
                       accuracy:(double)accuracy 
                          speed:(double)speed 
                         course:(double)course {
    
    NSLog(@"[GhostWalker] Starting simulation at: %f, %f (accuracy: %.1f)", 
          location.latitude, location.longitude, accuracy);
    
    // Store base location for drift calculations
    self.baseLocation = location;
    self.currentLocation = location;
    self.currentAccuracy = accuracy;
    self.currentSpeed = speed;
    self.currentCourse = course;
    self.updateCount = 0;
    self.startTime = [NSDate date];
    
    // Try CLSimulationManager first
    if (self.simManager) {
        @try {
            // Configure simulation behavior
            self.simManager.locationDeliveryBehavior = 2;  // Immediate delivery
            self.simManager.locationRepeatBehavior = 1;     // Repeat last location
            
            // Stop any existing simulation
            [self.simManager stopLocationSimulation];
            [self.simManager clearSimulatedLocations];
            
            // Create CLLocation with our parameters
            CLLocation *simLocation = [self createLocationWithCoordinate:location 
                                                                accuracy:accuracy 
                                                                   speed:speed 
                                                                  course:course];
            
            // Append and start
            [self.simManager appendSimulatedLocation:simLocation];
            [self.simManager flush];
            [self.simManager startLocationSimulation];
            
            self.isSimulating = YES;
            
            NSLog(@"[GhostWalker] CLSimulationManager started successfully!");
            
            // Start update timer for continuous drift
            [self startUpdateTimer];
            [self startAccuracyTimer];
            
            // Notify delegate
            if ([self.delegate respondsToSelector:@selector(locationSimulatorDidStart:)]) {
                [self.delegate locationSimulatorDidStart:self];
            }
            
            return YES;
        }
        @catch (NSException *exception) {
            NSLog(@"[GhostWalker] CLSimulationManager exception: %@", exception);
        }
    }
    
    // Fallback to locsim CLI
    return [self startWithLocSimCLI:location accuracy:accuracy speed:speed course:course];
}

- (BOOL)startWithLocSimCLI:(CLLocationCoordinate2D)location 
                  accuracy:(double)accuracy 
                     speed:(double)speed 
                    course:(double)course {
    
    NSLog(@"[GhostWalker] Falling back to locsim CLI...");
    
    // Build locsim command
    NSString *locsimPath = @"/var/jb/usr/local/bin/locsim";
    
    // Check if locsim exists at rootless path
    if (![[NSFileManager defaultManager] fileExistsAtPath:locsimPath]) {
        locsimPath = @"/usr/local/bin/locsim";  // Try non-rootless path
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:locsimPath]) {
        NSLog(@"[GhostWalker] ERROR: locsim not found!");
        if ([self.delegate respondsToSelector:@selector(locationSimulator:didFailWithError:)]) {
            NSError *error = [NSError errorWithDomain:@"GhostWalker" 
                                                 code:1 
                                             userInfo:@{NSLocalizedDescriptionKey: @"locsim not found"}];
            [self.delegate locationSimulator:self didFailWithError:error];
        }
        return NO;
    }
    
    // Build argument strings
    NSString *latStr = [NSString stringWithFormat:@"%f", location.latitude];
    NSString *lonStr = [NSString stringWithFormat:@"%f", location.longitude];
    NSString *accStr = [NSString stringWithFormat:@"%.1f", accuracy];
    
    // Use posix_spawn for iOS compatibility
    pid_t pid;
    int status;
    
    const char *args[10];
    int argIndex = 0;
    args[argIndex++] = [locsimPath UTF8String];
    args[argIndex++] = "start";
    args[argIndex++] = [latStr UTF8String];
    args[argIndex++] = [lonStr UTF8String];
    args[argIndex++] = "-h";
    args[argIndex++] = [accStr UTF8String];
    args[argIndex++] = NULL;
    
    int result = posix_spawn(&pid, [locsimPath UTF8String], NULL, NULL, (char * const *)args, environ);
    
    if (result == 0) {
        waitpid(pid, &status, 0);
        
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            self.isSimulating = YES;
            NSLog(@"[GhostWalker] locsim started successfully!");
            
            // Start update timer
            [self startUpdateTimer];
            [self startAccuracyTimer];
            
            if ([self.delegate respondsToSelector:@selector(locationSimulatorDidStart:)]) {
                [self.delegate locationSimulatorDidStart:self];
            }
            
            return YES;
        } else {
            NSLog(@"[GhostWalker] locsim exited with status: %d", WEXITSTATUS(status));
        }
    } else {
        NSLog(@"[GhostWalker] posix_spawn failed: %d", result);
    }
    
    return NO;
}

- (void)updateLocation:(CLLocationCoordinate2D)location {
    [self updateLocation:location 
                accuracy:self.currentAccuracy 
                   speed:self.currentSpeed 
                  course:self.currentCourse];
}

- (void)updateLocation:(CLLocationCoordinate2D)location 
              accuracy:(double)accuracy 
                 speed:(double)speed 
                course:(double)course {
    
    if (!self.isSimulating) return;
    
    self.baseLocation = location;
    self.currentAccuracy = accuracy;
    self.currentSpeed = speed;
    self.currentCourse = course;
    self.updateCount++;
    
    // Apply drift
    CLLocationCoordinate2D driftedLocation = [self applyDriftTo:location];
    self.currentLocation = driftedLocation;
    
    // Update simulation
    if (self.simManager) {
        @try {
            CLLocation *simLocation = [self createLocationWithCoordinate:driftedLocation 
                                                                accuracy:accuracy 
                                                                   speed:speed 
                                                                  course:course];
            
            [self.simManager clearSimulatedLocations];
            [self.simManager appendSimulatedLocation:simLocation];
            [self.simManager flush];
        }
        @catch (NSException *exception) {
            NSLog(@"[GhostWalker] Update exception: %@", exception);
        }
    } else {
        // Use locsim CLI for update
        [self startWithLocSimCLI:driftedLocation accuracy:accuracy speed:speed course:course];
    }
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(locationSimulator:didUpdateToLocation:)]) {
        [self.delegate locationSimulator:self didUpdateToLocation:driftedLocation];
    }
}

- (void)stopSimulating {
    NSLog(@"[GhostWalker] Stopping simulation...");
    
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    [self.accuracyTimer invalidate];
    self.accuracyTimer = nil;
    
    if (self.simManager) {
        @try {
            [self.simManager stopLocationSimulation];
            [self.simManager clearSimulatedLocations];
            [self.simManager flush];
        }
        @catch (NSException *exception) {
            NSLog(@"[GhostWalker] Stop exception: %@", exception);
        }
    } else {
        // Stop via locsim CLI using posix_spawn
        NSString *locsimPath = @"/var/jb/usr/local/bin/locsim";
        if (![[NSFileManager defaultManager] fileExistsAtPath:locsimPath]) {
            locsimPath = @"/usr/local/bin/locsim";
        }
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:locsimPath]) {
            pid_t pid;
            int status;
            const char *args[] = {[locsimPath UTF8String], "stop", NULL};
            
            int result = posix_spawn(&pid, [locsimPath UTF8String], NULL, NULL, (char * const *)args, environ);
            if (result == 0) {
                waitpid(pid, &status, 0);
                NSLog(@"[GhostWalker] locsim stop executed");
            }
        }
    }
    
    self.isSimulating = NO;
    
    if ([self.delegate respondsToSelector:@selector(locationSimulatorDidStop:)]) {
        [self.delegate locationSimulatorDidStop:self];
    }
}

#pragma mark - Timers

- (void)startUpdateTimer {
    [self.updateTimer invalidate];
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:self.updateInterval
                                                        target:self
                                                      selector:@selector(timerUpdate)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)startAccuracyTimer {
    [self.accuracyTimer invalidate];
    
    self.accuracyTimer = [NSTimer scheduledTimerWithTimeInterval:self.accuracyUpdateInterval
                                                          target:self
                                                        selector:@selector(updateRandomAccuracy)
                                                        userInfo:nil
                                                         repeats:YES];
    
    // Initial accuracy
    [self updateRandomAccuracy];
}

- (void)timerUpdate {
    if (!self.isSimulating) return;
    
    // Apply drift to base location and push update
    [self updateLocation:self.baseLocation 
                accuracy:self.currentAccuracy 
                   speed:self.currentSpeed 
                  course:self.currentCourse];
}

- (void)updateRandomAccuracy {
    // Random accuracy within user-defined range
    double range = self.accuracyMax - self.accuracyMin;
    self.currentAccuracy = self.accuracyMin + (((double)arc4random() / UINT32_MAX) * range);
    self.lastAccuracyUpdate = [[NSDate date] timeIntervalSince1970];
    
    NSLog(@"[GhostWalker] Accuracy updated to: %.1f meters", self.currentAccuracy);
}

#pragma mark - Drift Calculation

- (CLLocationCoordinate2D)applyDriftTo:(CLLocationCoordinate2D)location {
    // Convert meters to degrees (approximate)
    double metersPerDegree = 111000.0;
    
    // Random drift within range
    double driftAmount = self.driftMin + (((double)arc4random() / UINT32_MAX) * (self.driftMax - self.driftMin));
    double driftDegrees = driftAmount / metersPerDegree;
    
    // Random direction
    double angle = ((double)arc4random() / UINT32_MAX) * 2 * M_PI;
    
    double driftLat = driftDegrees * cos(angle);
    double driftLon = driftDegrees * sin(angle);
    
    return CLLocationCoordinate2DMake(location.latitude + driftLat, 
                                      location.longitude + driftLon);
}

- (void)setBaseLocation:(CLLocationCoordinate2D)location {
    _baseLocation = location;
}

- (void)applyDriftToCurrentLocation {
    if (self.isSimulating && CLLocationCoordinate2DIsValid(self.baseLocation)) {
        [self updateLocation:self.baseLocation];
    }
}

#pragma mark - Helper Methods

- (CLLocation *)createLocationWithCoordinate:(CLLocationCoordinate2D)coordinate 
                                    accuracy:(double)accuracy 
                                       speed:(double)speed 
                                      course:(double)course {
    
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                         altitude:0
                                               horizontalAccuracy:accuracy
                                                 verticalAccuracy:accuracy
                                                           course:course
                                                            speed:speed
                                                        timestamp:[NSDate date]];
    return location;
}

#pragma mark - App Lifecycle

- (void)appWillTerminate {
    // Note: Simulation will continue because locationd maintains the state
    // This is intentional - the location persists after app closes!
    NSLog(@"[GhostWalker] App terminating - simulation will continue in locationd");
}

@end
