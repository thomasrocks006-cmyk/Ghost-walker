//
//  WalkingEngine.m
//  Ghost Walker
//
//  Core location simulation with static hold, walking, driving modes
//  Uses CLSimulationManager (via LocationSimulator) for native location spoofing
//  Features: background persistence, rubber-band failsafe, configurable accuracy
//

#import "WalkingEngine.h"
#import "LocationSimulator.h"

// Legacy JSON paths for backwards compatibility with tweak
static NSString *const kJSONPath = @"/var/mobile/Library/Preferences/com.ghostwalker.live.json";
static NSString *const kPersistPath = @"/var/mobile/Library/Preferences/com.ghostwalker.persist.json";

@interface WalkingEngine ()

// State
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isMoving;
@property (nonatomic, assign) GhostSpoofStatus status;

@property (nonatomic, strong) NSMutableArray<CLLocation *> *currentRoute;
@property (nonatomic, strong) NSMutableArray<CLLocation *> *walkedPath;

// Timers
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSTimer *accuracyTimer;  // Separate timer for accuracy updates

// Route state
@property (nonatomic, assign) NSUInteger routeIndex;
@property (nonatomic, assign) double segmentProgress;

// Accuracy state
@property (nonatomic, assign) double currentAccuracy;
@property (nonatomic, assign) NSTimeInterval lastAccuracyChange;

// Failsafe state
@property (nonatomic, assign) CLLocationCoordinate2D lastKnownGoodLocation;
@property (nonatomic, assign) double lastKnownGoodAccuracy;

// Verification
@property (nonatomic, strong) NSDate *spoofStartTime;
@property (nonatomic, assign) NSUInteger updateCount;

// Persistence
@property (nonatomic, assign) BOOL persistentModeEnabled;

@end

@implementation WalkingEngine

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        // State
        _isActive = NO;
        _isMoving = NO;
        _status = GhostSpoofStatusIdle;
        _movementMode = GhostMovementModeWalking;
        
        // Speed
        _walkingSpeed = 1.4;       // Normal walking pace
        _drivingSpeed = 13.9;      // ~50 km/h
        
        // Accuracy (FindMy-like defaults)
        _accuracyMin = 10.0;
        _accuracyMax = 45.0;
        _accuracyUpdateInterval = 10.0;  // Change circle every 10 seconds
        _currentAccuracy = 25.0;
        
        // Drift
        _driftMin = 2.0;
        _driftMax = 5.0;
        
        // Update interval
        _updateInterval = 1.0;     // Update every second for live look
        
        // Failsafe
        _maxJumpDistance = 100.0;  // 100m max jump before failsafe
        _failsafeTriggered = NO;
        
        // Route
        _routeIndex = 0;
        _segmentProgress = 0;
        _currentRoute = [NSMutableArray array];
        _walkedPath = [NSMutableArray array];
        
        // Locations
        _destination = CLLocationCoordinate2DMake(0, 0);
        _currentSpoofedLocation = CLLocationCoordinate2DMake(0, 0);
        _staticHoldLocation = CLLocationCoordinate2DMake(0, 0);
        _lastKnownGoodLocation = CLLocationCoordinate2DMake(0, 0);
        
        // Verification
        _updateCount = 0;
        
        // Persistence
        _persistentModeEnabled = YES;  // On by default
        
        // Check for persistent state on init
        [self loadPersistentState];
        
        // Register for app lifecycle notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.updateTimer invalidate];
    [self.accuracyTimer invalidate];
}

#pragma mark - Legacy Compatibility

- (BOOL)isWalking {
    return self.isMoving;
}

- (void)setIsWalking:(BOOL)isWalking {
    self.isMoving = isWalking;
}

- (double)driftAmount {
    return self.driftMax;
}

- (void)setDriftAmount:(double)driftAmount {
    self.driftMax = driftAmount;
}

- (void)startWalkingFrom:(CLLocationCoordinate2D)start {
    self.movementMode = GhostMovementModeWalking;
    [self startMovingFrom:start];
}

- (void)stopWalking {
    [self pauseMovement];
}

#pragma mark - Static Mode

- (void)startStaticSpoofAtLocation:(CLLocationCoordinate2D)location {
    NSLog(@"[GhostWalker] Starting STATIC spoof at: %f, %f", location.latitude, location.longitude);
    
    self.staticHoldLocation = location;
    self.currentSpoofedLocation = location;
    self.lastKnownGoodLocation = location;
    self.isActive = YES;
    self.isMoving = NO;
    self.status = GhostSpoofStatusActive;
    self.failsafeTriggered = NO;
    self.spoofStartTime = [NSDate date];
    self.updateCount = 0;
    
    // Start update timer for continuous location updates
    [self startUpdateTimer];
    [self startAccuracyTimer];
    
    // Save persistent state
    [self savePersistentState];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(walkingEngineStatusDidChange:)]) {
        [self.delegate walkingEngineStatusDidChange:self];
    }
}

#pragma mark - Route Mode

- (void)setDestination:(CLLocationCoordinate2D)coordinate {
    _destination = coordinate;
    [self.currentRoute removeAllObjects];
    self.routeIndex = 0;
    self.segmentProgress = 0;
}

- (void)startMovingFrom:(CLLocationCoordinate2D)start {
    if (self.destination.latitude == 0 && self.destination.longitude == 0) {
        return;
    }
    
    NSLog(@"[GhostWalker] Starting ROUTE mode from: %f, %f to: %f, %f", 
          start.latitude, start.longitude, 
          self.destination.latitude, self.destination.longitude);
    
    self.isActive = YES;
    self.isMoving = YES;
    self.status = GhostSpoofStatusMoving;
    self.currentSpoofedLocation = start;
    self.lastKnownGoodLocation = start;
    self.failsafeTriggered = NO;
    self.spoofStartTime = [NSDate date];
    self.updateCount = 0;
    
    [self.walkedPath removeAllObjects];
    [self.walkedPath addObject:[[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude]];
    
    // Fetch route from OSRM
    NSString *profile = (self.movementMode == GhostMovementModeDriving) ? @"car" : @"foot";
    [self fetchRouteFrom:start to:self.destination profile:profile completion:^(NSArray<CLLocation *> *route) {
        if (route) {
            [self.currentRoute removeAllObjects];
            [self.currentRoute addObjectsFromArray:route];
            self.routeIndex = 0;
            self.segmentProgress = 0;
            [self startUpdateTimer];
            [self startAccuracyTimer];
            [self savePersistentState];
        }
    }];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(walkingEngineStatusDidChange:)]) {
        [self.delegate walkingEngineStatusDidChange:self];
    }
}

- (void)pauseMovement {
    NSLog(@"[GhostWalker] Pausing movement, holding current position");
    self.isMoving = NO;
    
    // Keep static spoofing at current location
    if (self.currentSpoofedLocation.latitude != 0) {
        self.staticHoldLocation = self.currentSpoofedLocation;
        self.status = GhostSpoofStatusActive;
    }
    
    [self savePersistentState];
    
    if ([self.delegate respondsToSelector:@selector(walkingEngineStatusDidChange:)]) {
        [self.delegate walkingEngineStatusDidChange:self];
    }
}

- (void)resumeMovement {
    if (self.currentRoute.count > 0 && self.routeIndex < self.currentRoute.count) {
        NSLog(@"[GhostWalker] Resuming movement");
        self.isMoving = YES;
        self.status = GhostSpoofStatusMoving;
        
        if ([self.delegate respondsToSelector:@selector(walkingEngineStatusDidChange:)]) {
            [self.delegate walkingEngineStatusDidChange:self];
        }
    }
}

- (void)stopAllSpoofing {
    NSLog(@"[GhostWalker] Stopping ALL spoofing, returning to real location");
    
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    [self.accuracyTimer invalidate];
    self.accuracyTimer = nil;
    
    self.isActive = NO;
    self.isMoving = NO;
    self.status = GhostSpoofStatusIdle;
    self.failsafeTriggered = NO;
    
    // Clear the JSON file so tweak returns real location
    [self clearJSONFile];
    [self clearPersistentState];
    
    if ([self.delegate respondsToSelector:@selector(walkingEngineStatusDidChange:)]) {
        [self.delegate walkingEngineStatusDidChange:self];
    }
}

- (void)resetAll {
    [self stopAllSpoofing];
    self.destination = CLLocationCoordinate2DMake(0, 0);
    self.currentSpoofedLocation = CLLocationCoordinate2DMake(0, 0);
    self.staticHoldLocation = CLLocationCoordinate2DMake(0, 0);
    [self.currentRoute removeAllObjects];
    [self.walkedPath removeAllObjects];
    self.remainingDistance = 0;
    self.updateCount = 0;
}

#pragma mark - Timers

- (void)startUpdateTimer {
    [self.updateTimer invalidate];
    
    // Use faster interval for driving mode
    double interval = self.updateInterval;
    if (self.movementMode == GhostMovementModeDriving && self.isMoving) {
        interval = 0.5;  // Update every 0.5 seconds for smooth driving
    }
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(performUpdate)
                                                      userInfo:nil
                                                       repeats:YES];
    
    // Immediate first update
    [self performUpdate];
}

- (void)startAccuracyTimer {
    [self.accuracyTimer invalidate];
    
    // Change accuracy every N seconds (default 10)
    self.accuracyTimer = [NSTimer scheduledTimerWithTimeInterval:self.accuracyUpdateInterval
                                                          target:self
                                                        selector:@selector(updateAccuracy)
                                                        userInfo:nil
                                                         repeats:YES];
    
    // Set initial accuracy
    [self updateAccuracy];
}

- (void)updateAccuracy {
    // Random accuracy within user-defined range
    double range = self.accuracyMax - self.accuracyMin;
    self.currentAccuracy = self.accuracyMin + (((double)arc4random() / UINT32_MAX) * range);
    self.lastAccuracyChange = [[NSDate date] timeIntervalSince1970];
    
    NSLog(@"[GhostWalker] Accuracy updated to: %.1f meters", self.currentAccuracy);
}

#pragma mark - Update Loop

- (void)performUpdate {
    if (!self.isActive) return;
    
    self.updateCount++;
    
    if (self.isMoving && self.currentRoute.count > 0) {
        [self updateRoutePosition];
    } else if (self.staticHoldLocation.latitude != 0 || self.currentSpoofedLocation.latitude != 0) {
        [self updateStaticPosition];
    }
}

- (void)updateStaticPosition {
    // Get base location (either static hold or current spoofed)
    CLLocationCoordinate2D baseLocation = self.staticHoldLocation;
    if (baseLocation.latitude == 0) {
        baseLocation = self.currentSpoofedLocation;
    }
    
    // Apply random drift for realistic look
    double driftLat, driftLon;
    [self calculateDriftLat:&driftLat lon:&driftLon];
    
    double newLat = baseLocation.latitude + driftLat;
    double newLon = baseLocation.longitude + driftLon;
    
    // Failsafe check - detect rubber banding
    if ([self checkForRubberBand:CLLocationCoordinate2DMake(newLat, newLon)]) {
        return;  // Failsafe triggered, using last known good location
    }
    
    self.currentSpoofedLocation = CLLocationCoordinate2DMake(newLat, newLon);
    self.lastKnownGoodLocation = self.currentSpoofedLocation;
    
    // Write to JSON
    [self writeLocationToJSON:newLat
                          lon:newLon
                          alt:0
                     accuracy:self.currentAccuracy
                       course:-1
                        speed:0];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(walkingEngineDidUpdateLocation:)]) {
        [self.delegate walkingEngineDidUpdateLocation:self];
    }
}

- (void)updateRoutePosition {
    if (self.routeIndex >= self.currentRoute.count - 1) {
        [self arriveAtDestination];
        return;
    }
    
    CLLocation *from = self.currentRoute[self.routeIndex];
    CLLocation *to = self.currentRoute[self.routeIndex + 1];
    
    // Get current speed based on mode
    double currentSpeed = (self.movementMode == GhostMovementModeDriving) ? self.drivingSpeed : self.walkingSpeed;
    
    // Calculate distance to travel this tick
    double tickInterval = (self.movementMode == GhostMovementModeDriving) ? 0.5 : self.updateInterval;
    double segmentDistance = [from distanceFromLocation:to];
    double distanceToTravel = currentSpeed * tickInterval;
    
    // Calculate segment progress
    double segmentProgress = distanceToTravel / MAX(segmentDistance, 0.1);
    self.segmentProgress += segmentProgress;
    
    if (self.segmentProgress >= 1.0) {
        // Move to next segment
        self.routeIndex++;
        self.segmentProgress = 0;
        
        if (self.routeIndex >= self.currentRoute.count - 1) {
            [self arriveAtDestination];
            return;
        }
        
        from = self.currentRoute[self.routeIndex];
        to = self.currentRoute[self.routeIndex + 1];
    }
    
    // Interpolate position
    double progress = MIN(self.segmentProgress, 1.0);
    double newLat = from.coordinate.latitude + (to.coordinate.latitude - from.coordinate.latitude) * progress;
    double newLon = from.coordinate.longitude + (to.coordinate.longitude - from.coordinate.longitude) * progress;
    
    // Apply drift (less for driving)
    double driftLat, driftLon;
    [self calculateDriftLat:&driftLat lon:&driftLon];
    if (self.movementMode == GhostMovementModeDriving) {
        driftLat *= 0.3;  // Less drift when driving
        driftLon *= 0.3;
    }
    newLat += driftLat;
    newLon += driftLon;
    
    // Failsafe check
    if ([self checkForRubberBand:CLLocationCoordinate2DMake(newLat, newLon)]) {
        return;
    }
    
    // Calculate bearing
    double bearing = [self bearingFrom:from.coordinate to:to.coordinate];
    
    // Update state
    self.currentSpoofedLocation = CLLocationCoordinate2DMake(newLat, newLon);
    self.lastKnownGoodLocation = self.currentSpoofedLocation;
    self.lastKnownGoodAccuracy = self.currentAccuracy;
    [self.walkedPath addObject:[[CLLocation alloc] initWithLatitude:newLat longitude:newLon]];
    
    // Calculate remaining distance
    self.remainingDistance = [self calculateRemainingDistance];
    
    // Write to JSON
    [self writeLocationToJSON:newLat
                          lon:newLon
                          alt:0
                     accuracy:self.currentAccuracy
                       course:bearing
                        speed:currentSpeed];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(walkingEngineDidUpdateLocation:)]) {
        [self.delegate walkingEngineDidUpdateLocation:self];
    }
}

- (void)arriveAtDestination {
    NSLog(@"[GhostWalker] Arrived at destination, switching to static hold");
    
    self.isMoving = NO;
    self.remainingDistance = 0;
    
    // Switch to static mode at destination
    self.staticHoldLocation = self.destination;
    self.currentSpoofedLocation = self.destination;
    self.status = GhostSpoofStatusActive;
    
    // Keep spoofing at destination
    [self writeLocationToJSON:self.destination.latitude
                          lon:self.destination.longitude
                          alt:0
                     accuracy:self.currentAccuracy
                       course:-1
                        speed:0];
    
    [self savePersistentState];
    
    if ([self.delegate respondsToSelector:@selector(walkingEngineDidFinish:)]) {
        [self.delegate walkingEngineDidFinish:self];
    }
    if ([self.delegate respondsToSelector:@selector(walkingEngineStatusDidChange:)]) {
        [self.delegate walkingEngineStatusDidChange:self];
    }
}

#pragma mark - Failsafe

- (BOOL)checkForRubberBand:(CLLocationCoordinate2D)newLocation {
    if (self.lastKnownGoodLocation.latitude == 0) {
        return NO;  // No previous location to compare
    }
    
    CLLocation *lastGood = [[CLLocation alloc] initWithLatitude:self.lastKnownGoodLocation.latitude
                                                      longitude:self.lastKnownGoodLocation.longitude];
    CLLocation *newLoc = [[CLLocation alloc] initWithLatitude:newLocation.latitude
                                                    longitude:newLocation.longitude];
    
    double distance = [lastGood distanceFromLocation:newLoc];
    
    // For route mode, allow larger jumps based on speed
    double maxAllowed = self.maxJumpDistance;
    if (self.isMoving) {
        double speed = (self.movementMode == GhostMovementModeDriving) ? self.drivingSpeed : self.walkingSpeed;
        maxAllowed = MAX(self.maxJumpDistance, speed * 5);  // 5 seconds of movement
    }
    
    if (distance > maxAllowed) {
        NSLog(@"[GhostWalker] ⚠️ RUBBER BAND DETECTED! Jump of %.1f meters (max: %.1f)", distance, maxAllowed);
        
        self.failsafeTriggered = YES;
        self.status = GhostSpoofStatusError;
        
        // Freeze at last known good location
        [self writeLocationToJSON:self.lastKnownGoodLocation.latitude
                              lon:self.lastKnownGoodLocation.longitude
                              alt:0
                         accuracy:self.lastKnownGoodAccuracy
                           course:-1
                            speed:0];
        
        if ([self.delegate respondsToSelector:@selector(walkingEngineDidDetectRubberBand:)]) {
            [self.delegate walkingEngineDidDetectRubberBand:self];
        }
        
        return YES;
    }
    
    return NO;
}

#pragma mark - Drift Calculation

- (void)calculateDriftLat:(double *)driftLat lon:(double *)driftLon {
    // Convert meters to degrees (approximate)
    double metersPerDegree = 111000.0;
    
    // Random drift within range
    double driftAmount = self.driftMin + (((double)arc4random() / UINT32_MAX) * (self.driftMax - self.driftMin));
    double driftDegrees = driftAmount / metersPerDegree;
    
    // Random direction
    double angle = ((double)arc4random() / UINT32_MAX) * 2 * M_PI;
    
    *driftLat = driftDegrees * cos(angle);
    *driftLon = driftDegrees * sin(angle);
}

- (double)bearingFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to {
    double lat1 = from.latitude * M_PI / 180;
    double lat2 = to.latitude * M_PI / 180;
    double dLon = (to.longitude - from.longitude) * M_PI / 180;
    
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    
    double bearing = atan2(y, x) * 180 / M_PI;
    return fmod(bearing + 360, 360);
}

- (double)calculateRemainingDistance {
    if (self.currentRoute.count == 0 || self.routeIndex >= self.currentRoute.count) {
        return 0;
    }
    
    double total = 0;
    
    if (self.routeIndex < self.currentRoute.count - 1) {
        CLLocation *from = self.currentRoute[self.routeIndex];
        CLLocation *to = self.currentRoute[self.routeIndex + 1];
        double segmentDist = [from distanceFromLocation:to];
        total += segmentDist * (1 - self.segmentProgress);
    }
    
    for (NSUInteger i = self.routeIndex + 1; i < self.currentRoute.count - 1; i++) {
        CLLocation *from = self.currentRoute[i];
        CLLocation *to = self.currentRoute[i + 1];
        total += [from distanceFromLocation:to];
    }
    
    return total;
}

#pragma mark - OSRM Routing

- (void)fetchRouteFrom:(CLLocationCoordinate2D)start to:(CLLocationCoordinate2D)end profile:(NSString *)profile completion:(void (^)(NSArray<CLLocation *> *))completion {
    NSString *urlString = [NSString stringWithFormat:
        @"https://router.project-osrm.org/route/v1/%@/%f,%f;%f,%f?overview=full&geometries=geojson&steps=true",
        profile, start.longitude, start.latitude, end.longitude, end.latitude];
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        completion(@[
            [[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude],
            [[CLLocation alloc] initWithLatitude:end.latitude longitude:end.longitude]
        ]);
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[
                    [[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude],
                    [[CLLocation alloc] initWithLatitude:end.latitude longitude:end.longitude]
                ]);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError || !json) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[
                    [[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude],
                    [[CLLocation alloc] initWithLatitude:end.latitude longitude:end.longitude]
                ]);
            });
            return;
        }
        
        NSArray *routes = json[@"routes"];
        if (routes.count > 0) {
            NSDictionary *firstRoute = routes[0];
            NSDictionary *geometry = firstRoute[@"geometry"];
            NSArray *coordinates = geometry[@"coordinates"];
            
            NSMutableArray *routeLocations = [NSMutableArray array];
            for (NSArray *coord in coordinates) {
                double lon = [coord[0] doubleValue];
                double lat = [coord[1] doubleValue];
                [routeLocations addObject:[[CLLocation alloc] initWithLatitude:lat longitude:lon]];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(routeLocations);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[
                    [[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude],
                    [[CLLocation alloc] initWithLatitude:end.latitude longitude:end.longitude]
                ]);
            });
        }
    }];
    
    [task resume];
}

#pragma mark - JSON File Operations (Now uses CLSimulationManager!)

- (void)writeLocationToJSON:(double)lat lon:(double)lon alt:(double)alt accuracy:(double)accuracy course:(double)course speed:(double)speed {
    
    // PRIMARY: Use CLSimulationManager via LocationSimulator
    LocationSimulator *sim = [LocationSimulator sharedSimulator];
    CLLocationCoordinate2D location = CLLocationCoordinate2DMake(lat, lon);
    
    if (!sim.isSimulating) {
        // Start simulation with current settings
        sim.accuracyMin = self.accuracyMin;
        sim.accuracyMax = self.accuracyMax;
        sim.driftMin = self.driftMin;
        sim.driftMax = self.driftMax;
        sim.updateInterval = self.updateInterval;
        
        [sim startSimulatingLocation:location accuracy:accuracy speed:speed course:course];
    } else {
        // Update existing simulation - let LocationSimulator handle drift
        // We pass the base location, it applies drift internally
        [sim setBaseLocation:location];
        sim.currentSpeed = speed;
        sim.currentCourse = course;
    }
    
    // LEGACY: Also write JSON for backwards compatibility with tweak
    // (in case someone has older tweak version)
    NSDictionary *locationData = @{
        @"lat": @(lat),
        @"lon": @(lon),
        @"alt": @(alt),
        @"accuracy": @(accuracy),
        @"verticalAccuracy": @(accuracy),
        @"course": @(course),
        @"speed": @(speed),
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"updateCount": @(self.updateCount),
        @"mode": @(self.movementMode),
        @"isMoving": @(self.isMoving)
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:locationData options:0 error:&error];
    if (error) return;
    
    NSString *directory = [kJSONPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    [jsonData writeToFile:kJSONPath atomically:YES];
}

- (void)clearJSONFile {
    // Stop CLSimulationManager
    [[LocationSimulator sharedSimulator] stopSimulating];
    
    // Also clear legacy JSON
    [[NSFileManager defaultManager] removeItemAtPath:kJSONPath error:nil];
}

#pragma mark - Persistence (Background Survival)

- (void)enablePersistentMode:(BOOL)enabled {
    self.persistentModeEnabled = enabled;
    if (enabled && self.isActive) {
        [self savePersistentState];
    } else if (!enabled) {
        [self clearPersistentState];
    }
}

- (void)savePersistentState {
    if (!self.persistentModeEnabled || !self.isActive) return;
    
    NSDictionary *state = @{
        @"isActive": @(self.isActive),
        @"isMoving": @(self.isMoving),
        @"movementMode": @(self.movementMode),
        @"staticLat": @(self.staticHoldLocation.latitude),
        @"staticLon": @(self.staticHoldLocation.longitude),
        @"currentLat": @(self.currentSpoofedLocation.latitude),
        @"currentLon": @(self.currentSpoofedLocation.longitude),
        @"destLat": @(self.destination.latitude),
        @"destLon": @(self.destination.longitude),
        @"accuracyMin": @(self.accuracyMin),
        @"accuracyMax": @(self.accuracyMax),
        @"driftMin": @(self.driftMin),
        @"driftMax": @(self.driftMax),
        @"walkingSpeed": @(self.walkingSpeed),
        @"drivingSpeed": @(self.drivingSpeed),
        @"savedAt": @([[NSDate date] timeIntervalSince1970])
    };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    [data writeToFile:kPersistPath atomically:YES];
    
    NSLog(@"[GhostWalker] Saved persistent state");
}

- (void)loadPersistentState {
    if (![[NSFileManager defaultManager] fileExistsAtPath:kPersistPath]) return;
    
    NSData *data = [NSData dataWithContentsOfFile:kPersistPath];
    if (!data) return;
    
    NSDictionary *state = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!state) return;
    
    // Check if state is recent (within last hour)
    NSTimeInterval savedAt = [state[@"savedAt"] doubleValue];
    if ([[NSDate date] timeIntervalSince1970] - savedAt > 3600) {
        NSLog(@"[GhostWalker] Persistent state too old, ignoring");
        [self clearPersistentState];
        return;
    }
    
    NSLog(@"[GhostWalker] Restoring persistent state...");
    
    self.movementMode = [state[@"movementMode"] integerValue];
    self.accuracyMin = [state[@"accuracyMin"] doubleValue];
    self.accuracyMax = [state[@"accuracyMax"] doubleValue];
    self.driftMin = [state[@"driftMin"] doubleValue];
    self.driftMax = [state[@"driftMax"] doubleValue];
    self.walkingSpeed = [state[@"walkingSpeed"] doubleValue];
    self.drivingSpeed = [state[@"drivingSpeed"] doubleValue];
    
    double staticLat = [state[@"staticLat"] doubleValue];
    double staticLon = [state[@"staticLon"] doubleValue];
    double currentLat = [state[@"currentLat"] doubleValue];
    double currentLon = [state[@"currentLon"] doubleValue];
    
    if (staticLat != 0 || currentLat != 0) {
        CLLocationCoordinate2D resumeLocation;
        if (staticLat != 0) {
            resumeLocation = CLLocationCoordinate2DMake(staticLat, staticLon);
        } else {
            resumeLocation = CLLocationCoordinate2DMake(currentLat, currentLon);
        }
        
        // Resume static spoofing
        [self startStaticSpoofAtLocation:resumeLocation];
        
        NSLog(@"[GhostWalker] Resumed spoofing at: %f, %f", resumeLocation.latitude, resumeLocation.longitude);
    }
}

- (void)clearPersistentState {
    [[NSFileManager defaultManager] removeItemAtPath:kPersistPath error:nil];
}

#pragma mark - App Lifecycle

- (void)appWillResignActive {
    NSLog(@"[GhostWalker] App going to background, saving state...");
    [self savePersistentState];
    
    // Keep the location file updated even when backgrounded
    // The tweak will continue reading it
}

- (void)appDidBecomeActive {
    NSLog(@"[GhostWalker] App became active");
    // Timer will continue if spoofing was active
}

@end
