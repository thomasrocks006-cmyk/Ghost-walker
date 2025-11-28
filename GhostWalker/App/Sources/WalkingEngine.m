//
//  WalkingEngine.m
//  Ghost Walker
//
//  Core walking simulation with OSRM routing and human-like movement
//

#import "WalkingEngine.h"

static NSString *const kJSONPath = @"/var/mobile/Library/Preferences/com.ghostwalker.live.json";

@interface WalkingEngine ()

@property (nonatomic, assign) BOOL isWalking;
@property (nonatomic, strong) NSMutableArray<CLLocation *> *currentRoute;
@property (nonatomic, strong) NSMutableArray<CLLocation *> *walkedPath;

@property (nonatomic, strong) NSTimer *walkingTimer;
@property (nonatomic, assign) NSUInteger routeIndex;
@property (nonatomic, assign) double segmentProgress;
@property (nonatomic, assign) double pulsePhase;

@end

@implementation WalkingEngine

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _isWalking = NO;
        _walkingSpeed = 1.4;
        _driftAmount = 3.0;
        _accuracyMin = 10.0;
        _accuracyMax = 45.0;
        _routeIndex = 0;
        _segmentProgress = 0;
        _pulsePhase = 0;
        _destination = CLLocationCoordinate2DMake(0, 0);
        _currentSpoofedLocation = CLLocationCoordinate2DMake(0, 0);
        _currentRoute = [NSMutableArray array];
        _walkedPath = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public Methods

- (void)setDestination:(CLLocationCoordinate2D)coordinate {
    _destination = coordinate;
    [self.currentRoute removeAllObjects];
    self.routeIndex = 0;
    self.segmentProgress = 0;
}

- (void)startWalkingFrom:(CLLocationCoordinate2D)start {
    if (self.destination.latitude == 0 && self.destination.longitude == 0) {
        return;
    }
    
    self.isWalking = YES;
    self.currentSpoofedLocation = start;
    [self.walkedPath removeAllObjects];
    [self.walkedPath addObject:[[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude]];
    
    // Fetch route from OSRM
    [self fetchRouteFrom:start to:self.destination completion:^(NSArray<CLLocation *> *route) {
        if (route) {
            [self.currentRoute removeAllObjects];
            [self.currentRoute addObjectsFromArray:route];
            self.routeIndex = 0;
            self.segmentProgress = 0;
            [self startWalkingTimer];
        }
    }];
}

- (void)stopWalking {
    self.isWalking = NO;
    [self.walkingTimer invalidate];
    self.walkingTimer = nil;
    [self clearJSONFile];
}

- (void)resetAll {
    [self stopWalking];
    self.destination = CLLocationCoordinate2DMake(0, 0);
    self.currentSpoofedLocation = CLLocationCoordinate2DMake(0, 0);
    [self.currentRoute removeAllObjects];
    [self.walkedPath removeAllObjects];
    self.remainingDistance = 0;
}

#pragma mark - Timer

- (void)startWalkingTimer {
    [self.walkingTimer invalidate];
    
    self.walkingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updatePosition)
                                                       userInfo:nil
                                                        repeats:YES];
    
    // Immediate first update
    [self updatePosition];
}

- (void)updatePosition {
    if (!self.isWalking || self.currentRoute.count == 0) {
        return;
    }
    
    if (self.routeIndex >= self.currentRoute.count - 1) {
        [self arriveAtDestination];
        return;
    }
    
    CLLocation *from = self.currentRoute[self.routeIndex];
    CLLocation *to = self.currentRoute[self.routeIndex + 1];
    
    // Calculate distance to travel this tick
    double segmentDistance = [from distanceFromLocation:to];
    double distanceToTravel = self.walkingSpeed; // meters per second
    
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
    
    // Apply human-like drift (Brownian motion)
    double driftLat, driftLon;
    [self calculateDriftLat:&driftLat lon:&driftLon];
    newLat += driftLat;
    newLon += driftLon;
    
    // Calculate bearing (course)
    double bearing = [self bearingFrom:from.coordinate to:to.coordinate];
    
    // Calculate pulsing accuracy
    double accuracy = [self calculatePulsingAccuracy];
    
    // Update state
    self.currentSpoofedLocation = CLLocationCoordinate2DMake(newLat, newLon);
    [self.walkedPath addObject:[[CLLocation alloc] initWithLatitude:newLat longitude:newLon]];
    
    // Calculate remaining distance
    self.remainingDistance = [self calculateRemainingDistance];
    
    // Write to JSON file
    [self writeLocationToJSON:newLat 
                          lon:newLon 
                          alt:0 
                     accuracy:accuracy 
                       course:bearing 
                        speed:self.walkingSpeed];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(walkingEngineDidUpdateLocation:)]) {
        [self.delegate walkingEngineDidUpdateLocation:self];
    }
}

- (void)arriveAtDestination {
    self.isWalking = NO;
    [self.walkingTimer invalidate];
    self.walkingTimer = nil;
    self.remainingDistance = 0;
    
    // Keep spoofing at destination but stopped
    [self writeLocationToJSON:self.destination.latitude 
                          lon:self.destination.longitude 
                          alt:0 
                     accuracy:self.accuracyMin 
                       course:-1 
                        speed:0];
    
    if ([self.delegate respondsToSelector:@selector(walkingEngineDidFinish:)]) {
        [self.delegate walkingEngineDidFinish:self];
    }
}

#pragma mark - Human Simulation

- (void)calculateDriftLat:(double *)driftLat lon:(double *)driftLon {
    // Convert meters to degrees (approximate)
    double metersPerDegree = 111000.0;
    double driftDegrees = self.driftAmount / metersPerDegree;
    
    // Random walk (Brownian motion)
    double angle = ((double)arc4random() / UINT32_MAX) * 2 * M_PI;
    double magnitude = ((double)arc4random() / UINT32_MAX) * driftDegrees;
    
    *driftLat = magnitude * cos(angle);
    *driftLon = magnitude * sin(angle);
}

- (double)calculatePulsingAccuracy {
    self.pulsePhase += 0.2;
    
    // Sine wave oscillation
    double range = self.accuracyMax - self.accuracyMin;
    double accuracy = self.accuracyMin + (range / 2) + (range / 2) * sin(self.pulsePhase);
    
    // Add small random variation
    double noise = (((double)arc4random() / UINT32_MAX) * 4) - 2; // -2 to +2
    
    return MAX(self.accuracyMin, MIN(self.accuracyMax, accuracy + noise));
}

- (double)bearingFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to {
    double lat1 = from.latitude * M_PI / 180;
    double lat2 = to.latitude * M_PI / 180;
    double dLon = (to.longitude - from.longitude) * M_PI / 180;
    
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    
    double bearing = atan2(y, x) * 180 / M_PI;
    bearing = fmod(bearing + 360, 360);
    
    return bearing;
}

- (double)calculateRemainingDistance {
    if (self.currentRoute.count == 0 || self.routeIndex >= self.currentRoute.count) {
        return 0;
    }
    
    double total = 0;
    
    // Current segment remaining
    if (self.routeIndex < self.currentRoute.count - 1) {
        CLLocation *from = self.currentRoute[self.routeIndex];
        CLLocation *to = self.currentRoute[self.routeIndex + 1];
        double segmentDist = [from distanceFromLocation:to];
        total += segmentDist * (1 - self.segmentProgress);
    }
    
    // Future segments
    for (NSUInteger i = self.routeIndex + 1; i < self.currentRoute.count - 1; i++) {
        CLLocation *from = self.currentRoute[i];
        CLLocation *to = self.currentRoute[i + 1];
        total += [from distanceFromLocation:to];
    }
    
    return total;
}

#pragma mark - OSRM Routing

- (void)fetchRouteFrom:(CLLocationCoordinate2D)start to:(CLLocationCoordinate2D)end completion:(void (^)(NSArray<CLLocation *> *))completion {
    NSString *urlString = [NSString stringWithFormat:
        @"https://router.project-osrm.org/route/v1/foot/%f,%f;%f,%f?overview=full&geometries=geojson&steps=true",
        start.longitude, start.latitude, end.longitude, end.latitude];
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"[WalkingEngine] Invalid URL");
        completion(@[
            [[CLLocation alloc] initWithLatitude:start.latitude longitude:start.longitude],
            [[CLLocation alloc] initWithLatitude:end.latitude longitude:end.longitude]
        ]);
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[WalkingEngine] Route fetch error: %@", error.localizedDescription);
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

#pragma mark - JSON File Operations

- (void)writeLocationToJSON:(double)lat lon:(double)lon alt:(double)alt accuracy:(double)accuracy course:(double)course speed:(double)speed {
    NSDictionary *locationData = @{
        @"lat": @(lat),
        @"lon": @(lon),
        @"alt": @(alt),
        @"accuracy": @(accuracy),
        @"verticalAccuracy": @(accuracy),
        @"course": @(course),
        @"speed": @(speed),
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:locationData options:0 error:&error];
    
    if (error) {
        NSLog(@"[GhostWalker] JSON serialization error: %@", error.localizedDescription);
        return;
    }
    
    // Ensure directory exists
    NSString *directory = [kJSONPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory 
                              withIntermediateDirectories:YES 
                                               attributes:nil 
                                                    error:nil];
    
    // Write atomically
    [jsonData writeToFile:kJSONPath atomically:YES];
    
    NSLog(@"[GhostWalker] Wrote location: %f, %f", lat, lon);
}

- (void)clearJSONFile {
    [[NSFileManager defaultManager] removeItemAtPath:kJSONPath error:nil];
    NSLog(@"[GhostWalker] Cleared spoofed location");
}

@end
