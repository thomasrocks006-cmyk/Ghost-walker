/*
 * Ghost Walker - Tweak.x
 * Advanced location spoofing with persistent fallback
 * 
 * Features:
 * - Hooks CLLocationManager to return spoofed GPS coordinates
 * - Reads live location from JSON file (written by app)
 * - Falls back to persist.json if app is closed
 * - Caches last known good location for failsafe
 * - 30-second stale data protection
 * 
 * Files:
 * - Live: /var/mobile/Library/Preferences/com.ghostwalker.live.json
 * - Persist: /var/mobile/Library/Preferences/com.ghostwalker.persist.json
 */

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============================================================================
// MARK: - Configuration
// ============================================================================

#define GHOST_LIVE_JSON @"/var/mobile/Library/Preferences/com.ghostwalker.live.json"
#define GHOST_PERSIST_JSON @"/var/mobile/Library/Preferences/com.ghostwalker.persist.json"
#define GHOST_MAX_STALE_TIME 30.0      // Seconds before live data is stale
#define GHOST_PERSIST_MAX_AGE 3600.0   // 1 hour max for persist data
#define GHOST_READ_RATE_LIMIT 0.1      // Min seconds between file reads

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
    NSTimeInterval fileReadTime;
} GhostLocation;

// Global state
static GhostLocation g_liveLocation = {0};
static GhostLocation g_persistLocation = {0};
static GhostLocation g_cachedLocation = {0};  // Last known good
static NSTimeInterval g_lastReadTime = 0;
static BOOL g_initialized = NO;

// ============================================================================
// MARK: - JSON Parsing
// ============================================================================

static GhostLocation parseJSONFile(NSString *path, double maxAge) {
    GhostLocation loc = {0};
    loc.isValid = NO;
    
    @autoreleasepool {
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:path 
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
        
        if (!lat || !lon) {
            return loc;
        }
        
        // Check age
        NSTimeInterval dataTimestamp = timestamp ? [timestamp doubleValue] : 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval age = now - dataTimestamp;
        
        if (dataTimestamp > 0 && age > maxAge) {
            // Data too old
            return loc;
        }
        
        // Parse all fields with defaults
        loc.latitude = [lat doubleValue];
        loc.longitude = [lon doubleValue];
        loc.altitude = json[@"alt"] ? [json[@"alt"] doubleValue] : 0.0;
        loc.horizontalAccuracy = json[@"accuracy"] ? [json[@"accuracy"] doubleValue] : 25.0;
        loc.verticalAccuracy = json[@"verticalAccuracy"] ? [json[@"verticalAccuracy"] doubleValue] : 10.0;
        loc.course = json[@"course"] ? [json[@"course"] doubleValue] : -1.0;
        loc.speed = json[@"speed"] ? [json[@"speed"] doubleValue] : -1.0;
        loc.timestamp = dataTimestamp > 0 ? dataTimestamp : now;
        loc.fileReadTime = now;
        loc.isValid = YES;
    }
    
    return loc;
}

static GhostLocation getGhostLocation(void) {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    // Rate limit file reads
    if (now - g_lastReadTime < GHOST_READ_RATE_LIMIT && g_liveLocation.isValid) {
        // Check if cached live location is still fresh
        if (now - g_liveLocation.timestamp < GHOST_MAX_STALE_TIME) {
            return g_liveLocation;
        }
    }
    
    g_lastReadTime = now;
    
    // Try 1: Live JSON (app is actively writing)
    g_liveLocation = parseJSONFile(GHOST_LIVE_JSON, GHOST_MAX_STALE_TIME);
    
    if (g_liveLocation.isValid) {
        // Cache as last known good
        g_cachedLocation = g_liveLocation;
        return g_liveLocation;
    }
    
    // Try 2: Persist JSON (app closed but was spoofing)
    g_persistLocation = parseJSONFile(GHOST_PERSIST_JSON, GHOST_PERSIST_MAX_AGE);
    
    if (g_persistLocation.isValid) {
        // Use persist location but apply some drift to keep it "live"
        double metersPerDegree = 111000.0;
        double driftMeters = 3.0;  // Default drift
        double driftDegrees = driftMeters / metersPerDegree;
        double angle = ((double)arc4random() / UINT32_MAX) * 2 * M_PI;
        
        g_persistLocation.latitude += driftDegrees * cos(angle);
        g_persistLocation.longitude += driftDegrees * sin(angle);
        g_persistLocation.timestamp = now;  // Update timestamp to now
        
        // Cache as last known good
        g_cachedLocation = g_persistLocation;
        return g_persistLocation;
    }
    
    // Try 3: Cached last known good (failsafe)
    if (g_cachedLocation.isValid) {
        // Check if cache is not too old (5 minutes max)
        if (now - g_cachedLocation.fileReadTime < 300.0) {
            // Apply drift to cached location
            double metersPerDegree = 111000.0;
            double driftMeters = 2.0;
            double driftDegrees = driftMeters / metersPerDegree;
            double angle = ((double)arc4random() / UINT32_MAX) * 2 * M_PI;
            
            GhostLocation driftedCache = g_cachedLocation;
            driftedCache.latitude += driftDegrees * cos(angle);
            driftedCache.longitude += driftDegrees * sin(angle);
            driftedCache.timestamp = now;
            
            return driftedCache;
        }
    }
    
    // No valid location found - return invalid to fall back to real
    GhostLocation invalid = {0};
    invalid.isValid = NO;
    return invalid;
}

// ============================================================================
// MARK: - CLLocation Creation
// ============================================================================

static CLLocation* createSpoofedLocation(GhostLocation ghostLoc) {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(ghostLoc.latitude, ghostLoc.longitude);
    
    CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:coord
                                                        altitude:ghostLoc.altitude
                                              horizontalAccuracy:ghostLoc.horizontalAccuracy
                                                verticalAccuracy:ghostLoc.verticalAccuracy
                                                          course:ghostLoc.course
                                                           speed:ghostLoc.speed
                                                       timestamp:[NSDate dateWithTimeIntervalSince1970:ghostLoc.timestamp]];
    
    return spoofed;
}

// ============================================================================
// MARK: - CLLocationManager Hooks
// ============================================================================

%hook CLLocationManager

- (CLLocation *)location {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return createSpoofedLocation(ghostLoc);
    }
    
    return %orig;
}

- (void)requestLocation {
    %orig;
}

- (void)startUpdatingLocation {
    %orig;
}

- (void)stopUpdatingLocation {
    %orig;
}

%end

// ============================================================================
// MARK: - CLLocation Property Hooks
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

- (NSDate *)timestamp {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return [NSDate dateWithTimeIntervalSince1970:ghostLoc.timestamp];
    }
    
    return %orig;
}

%end

// ============================================================================
// MARK: - Constructor
// ============================================================================

%ctor {
    @autoreleasepool {
        g_initialized = YES;
        
        // Pre-load persist location if available
        g_persistLocation = parseJSONFile(GHOST_PERSIST_JSON, GHOST_PERSIST_MAX_AGE);
        if (g_persistLocation.isValid) {
            g_cachedLocation = g_persistLocation;
            NSLog(@"[GhostWalker] Loaded persistent location: %f, %f", 
                  g_persistLocation.latitude, g_persistLocation.longitude);
        }
        
        NSLog(@"[GhostWalker] Tweak v2.0 loaded!");
        NSLog(@"[GhostWalker] Live JSON: %@", GHOST_LIVE_JSON);
        NSLog(@"[GhostWalker] Persist JSON: %@", GHOST_PERSIST_JSON);
    }
}
