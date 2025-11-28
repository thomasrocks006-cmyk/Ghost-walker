/*
 * Ghost Walker - Tweak.x
 * Hooks CLLocationManager to return spoofed GPS coordinates
 * 
 * Reads from: /var/mobile/Library/Preferences/com.ghostwalker.live.json
 * JSON Format: {"lat": 0.0, "lon": 0.0, "alt": 0.0, "accuracy": 10.0, 
 *               "course": 0.0, "speed": 0.0, "timestamp": 1234567890}
 */

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============================================================================
// MARK: - Configuration
// ============================================================================

#define GHOST_WALKER_JSON_PATH @"/var/mobile/Library/Preferences/com.ghostwalker.live.json"
#define GHOST_WALKER_MAX_AGE 30.0  // Seconds before data is considered stale

// ============================================================================
// MARK: - Spoofed Location Data Structure
// ============================================================================

typedef struct {
    BOOL isValid;
    double latitude;
    double longitude;
    double altitude;
    double horizontalAccuracy;
    double verticalAccuracy;
    double course;
    double speed;
    NSTimeInterval timestamp;
} GhostLocation;

// Global cached location
static GhostLocation g_ghostLocation = {0};
static NSTimeInterval g_lastReadTime = 0;
static dispatch_queue_t g_readQueue = nil;

// ============================================================================
// MARK: - JSON Parsing
// ============================================================================

static GhostLocation parseGhostLocationJSON(void) {
    GhostLocation loc = {0};
    loc.isValid = NO;
    
    @autoreleasepool {
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:GHOST_WALKER_JSON_PATH 
                                              options:0 
                                                error:&error];
        
        if (!data || error) {
            return loc;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data 
                                                             options:0 
                                                               error:&error];
        
        if (!json || error || ![json isKindOfClass:[NSDictionary class]]) {
            return loc;
        }
        
        // Parse required fields
        NSNumber *lat = json[@"lat"];
        NSNumber *lon = json[@"lon"];
        NSNumber *timestamp = json[@"timestamp"];
        
        if (!lat || !lon || !timestamp) {
            return loc;
        }
        
        // Check if data is fresh (within MAX_AGE seconds)
        NSTimeInterval dataAge = [[NSDate date] timeIntervalSince1970] - [timestamp doubleValue];
        if (dataAge > GHOST_WALKER_MAX_AGE) {
            // Data is stale - don't spoof (safety feature)
            return loc;
        }
        
        // Parse all fields
        loc.latitude = [lat doubleValue];
        loc.longitude = [lon doubleValue];
        loc.altitude = [json[@"alt"] doubleValue] ?: 0.0;
        loc.horizontalAccuracy = [json[@"accuracy"] doubleValue] ?: 10.0;
        loc.verticalAccuracy = [json[@"verticalAccuracy"] doubleValue] ?: 10.0;
        loc.course = [json[@"course"] doubleValue] ?: -1.0;
        loc.speed = [json[@"speed"] doubleValue] ?: -1.0;
        loc.timestamp = [timestamp doubleValue];
        loc.isValid = YES;
    }
    
    return loc;
}

static GhostLocation getGhostLocation(void) {
    // Rate limit reads to once per 100ms
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - g_lastReadTime < 0.1 && g_ghostLocation.isValid) {
        return g_ghostLocation;
    }
    
    g_lastReadTime = now;
    g_ghostLocation = parseGhostLocationJSON();
    return g_ghostLocation;
}

// ============================================================================
// MARK: - CLLocation Fake Constructor
// ============================================================================

static CLLocation* createFakeLocation(GhostLocation ghostLoc) {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(ghostLoc.latitude, ghostLoc.longitude);
    
    // Use the full initializer for maximum realism
    CLLocation *fakeLocation = [[CLLocation alloc] initWithCoordinate:coord
                                                             altitude:ghostLoc.altitude
                                                   horizontalAccuracy:ghostLoc.horizontalAccuracy
                                                     verticalAccuracy:ghostLoc.verticalAccuracy
                                                               course:ghostLoc.course
                                                                speed:ghostLoc.speed
                                                            timestamp:[NSDate dateWithTimeIntervalSince1970:ghostLoc.timestamp]];
    
    return fakeLocation;
}

// ============================================================================
// MARK: - CLLocationManager Hooks
// ============================================================================

%hook CLLocationManager

// Hook the location property getter
- (CLLocation *)location {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return createFakeLocation(ghostLoc);
    }
    
    // Fall back to real location if no spoof data
    return %orig;
}

%end

// ============================================================================
// MARK: - CLLocationManagerDelegate Hooks (for async updates)
// ============================================================================

%hook CLLocationManager

// Intercept delegate calls for location updates
- (void)setDelegate:(id<CLLocationManagerDelegate>)delegate {
    %orig;
}

%end

// Hook into the internal location update mechanism
%hook CLLocationManager

- (void)startUpdatingLocation {
    %orig;
}

- (void)requestLocation {
    %orig;
}

%end

// ============================================================================
// MARK: - Hook the actual location delivery
// ============================================================================

// This hooks the internal method that delivers locations to delegates
%hook CLLocationManager

%new
- (NSArray<CLLocation *> *)ghostWalker_spoofLocations:(NSArray<CLLocation *> *)locations {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (!ghostLoc.isValid || locations.count == 0) {
        return locations;
    }
    
    // Replace all locations with our spoofed one
    CLLocation *fake = createFakeLocation(ghostLoc);
    NSMutableArray *spoofed = [NSMutableArray arrayWithCapacity:locations.count];
    
    for (NSUInteger i = 0; i < locations.count; i++) {
        [spoofed addObject:fake];
    }
    
    return spoofed;
}

%end

// ============================================================================
// MARK: - Hook CLLocation itself for coordinate access
// ============================================================================

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return CLLocationCoordinate2DMake(ghostLoc.latitude, ghostLoc.longitude);
    }
    
    return %orig;
}

- (CLLocationDistance)altitude {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return ghostLoc.altitude;
    }
    
    return %orig;
}

- (CLLocationAccuracy)horizontalAccuracy {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return ghostLoc.horizontalAccuracy;
    }
    
    return %orig;
}

- (CLLocationAccuracy)verticalAccuracy {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return ghostLoc.verticalAccuracy;
    }
    
    return %orig;
}

- (CLLocationDirection)course {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return ghostLoc.course;
    }
    
    return %orig;
}

- (CLLocationSpeed)speed {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return ghostLoc.speed;
    }
    
    return %orig;
}

%end

// ============================================================================
// MARK: - Constructor
// ============================================================================

%ctor {
    @autoreleasepool {
        // Initialize the read queue for thread-safe file access
        g_readQueue = dispatch_queue_create("com.ghostwalker.readqueue", DISPATCH_QUEUE_SERIAL);
        
        NSLog(@"[GhostWalker] Tweak loaded successfully!");
        NSLog(@"[GhostWalker] Watching: %@", GHOST_WALKER_JSON_PATH);
    }
}
