# 👻 Ghost Walker - Complete Source Code & Fix Guide

## Document Purpose
This contains the COMPLETE source code for Ghost Walker. The agent can use this to understand the app architecture, diagnose issues, and apply fixes directly on-device if needed.

---

# 🚨 CURRENT ISSUE: Map Not Loading

## Problem
The map is blank because it's waiting for `CLLocationManager` to provide a location update before centering. If the location manager never fires (due to permission issues, our own tweak interfering, or iOS quirks), the map stays at (0,0) - middle of the ocean.

## Root Cause
In `MainViewController.m`, the map only centers when `didUpdateLocations:` is called:

```objc
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (!location) return;
    
    if (!self.hasInitializedMap) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000, 1000);
        [self.mapView setRegion:region animated:YES];
        self.hasInitializedMap = YES;  // <-- Only set when we get a location
    }
}
```

If this delegate method never fires, `hasInitializedMap` stays `NO` and the map never centers.

## The Fix
Add a fallback that centers the map on a default US location after 3 seconds if no GPS update arrives.

---

# 🔧 ON-DEVICE FIX (Without Rebuild)

Since we can't rebuild on-device, the best approach is to:

1. **Test if the tweak is interfering with the app's own location requests**
2. **Manually inject a location via JSON to test the tweak works**
3. **Check if MapKit itself is working**

## Test 1: Is our tweak blocking the app from getting real GPS?

Our tweak hooks ALL apps including our own app. This might be causing a chicken-and-egg problem where:
- App asks for location → Tweak intercepts → Tweak looks for JSON file → JSON file doesn't exist → Returns nothing

**Fix: Temporarily disable the tweak for our own app**

Check the bundle filter:
```bash
cat /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist
```

If it says something like `{ Filter = { Bundles = ( ... ); }; }` without excluding our app, that's the problem.

**The plist SHOULD exclude our own app.** Let me show you what it should contain:

---

# 📄 CORRECT GhostWalker.plist (Bundle Filter)

The tweak should NOT inject into our own app. Here's the correct content:

```bash
# Create the correct bundle filter
cat > /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist << 'EOF'
{ 
    Filter = { 
        Bundles = ( 
            "com.apple.locationd",
            "com.apple.CoreLocation", 
            "com.apple.springboard",
            "com.apple.findmy",
            "com.apple.mobileme.fmf1",
            "com.apple.Maps"
        ); 
    }; 
}
EOF

echo "Updated bundle filter"
killall -9 SpringBoard
```

**IMPORTANT:** Notice that `com.ghostwalker.app` is NOT in the list. This means the tweak won't inject into our app, so our app can get REAL GPS to display on the map.

---

# 🧪 Test 2: Test MapKit Independently

Create a simple test to see if MapKit works at all:

```bash
# Check if the app can reach Apple's map tile servers
ping -c 2 gspe1-ssl.ls.apple.com && echo "Map servers reachable" || echo "Cannot reach map servers"
```

---

# 🧪 Test 3: Manual Location Injection

Even if the app's map is broken, test if the TWEAK works by creating a location file manually:

```bash
# Create a spoofed location at the Eiffel Tower, Paris
cat > /var/mobile/Library/Preferences/com.ghostwalker.live.json << 'EOF'
{
    "lat": 48.8584,
    "lon": 2.2945,
    "alt": 10,
    "accuracy": 15.0,
    "verticalAccuracy": 10.0,
    "course": 0,
    "speed": 0,
    "timestamp": 1732900000
}
EOF

# Restart locationd to pick up the new location
killall -9 locationd

echo "Location set to Eiffel Tower, Paris"
echo "Open Find My or Apple Maps to verify"
```

Then open **Find My** or **Apple Maps** (NOT Ghost Walker) and check if it shows Paris.

If it does → Tweak works! The issue is just the app's map display.
If it doesn't → Tweak isn't loading properly.

---

# 📄 COMPLETE SOURCE FILES

## File 1: MainViewController.m (The Problem File)

Here's the FULL source code. The key section that needs to work is the location delegate:

```objc
//
//  MainViewController.m
//  Ghost Walker
//

#import "MainViewController.h"
#import "WalkingEngine.h"
#import "DestinationSearchController.h"
#import "SettingsViewController.h"

@interface MainViewController () <MKMapViewDelegate, CLLocationManagerDelegate, WalkingEngineDelegate>

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) MKPointAnnotation *realLocationAnnotation;
@property (nonatomic, strong) MKPointAnnotation *spoofedLocationAnnotation;
@property (nonatomic, strong) MKPointAnnotation *destinationAnnotation;
@property (nonatomic, strong) WalkingEngine *walkingEngine;
@property (nonatomic, assign) BOOL hasInitializedMap;

// ... more properties ...

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupWalkingEngine];
    [self setupLocationManager];
    [self setupMapView];
    [self setupVerificationBanner];
    [self setupControlPanel];
    [self setupGestures];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Request location permission
    [self.locationManager requestAlwaysAuthorization];
    
    // FALLBACK: If no location after 3 seconds, center on default location
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.hasInitializedMap) {
            NSLog(@"[GhostWalker] No GPS received, centering on default location");
            // Default to San Francisco
            CLLocationCoordinate2D defaultLocation = CLLocationCoordinate2DMake(37.7749, -122.4194);
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(defaultLocation, 5000, 5000);
            [self.mapView setRegion:region animated:YES];
            self.hasInitializedMap = YES;
        }
    });
}

- (void)setupLocationManager {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager startUpdatingLocation];  // Start immediately
}

- (void)setupMapView {
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;  // Show blue dot
    [self.view addSubview:self.mapView];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"[GhostWalker] Location authorization status: %d", (int)status);
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    NSLog(@"[GhostWalker] Got location: %f, %f", location.coordinate.latitude, location.coordinate.longitude);
    
    if (!self.hasInitializedMap && location) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000, 1000);
        [self.mapView setRegion:region animated:YES];
        self.hasInitializedMap = YES;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[GhostWalker] Location error: %@", error);
}

@end
```

---

## File 2: GhostWalker.plist (Bundle Filter) - CRITICAL

This file controls which apps the tweak injects into. **Our app should NOT be in this list!**

Current location: `/var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist`

**Check current content:**
```bash
cat /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist
```

**It should look like this:**
```
{ Filter = { Bundles = ( "com.apple.locationd", "com.apple.CoreLocation", "com.apple.springboard" ); }; }
```

**If `com.ghostwalker.app` is in the list, THAT'S THE BUG!** The tweak is hooking our own app and returning empty/stale data.

---

## File 3: Tweak.x (Location Hook)

This is the tweak that intercepts location. It reads from the JSON file:

```objc
// Key function that returns spoofed location
static GhostLocation getGhostLocation(void) {
    // Try to read live.json
    GhostLocation loc = parseJSONFile(@"/var/mobile/Library/Preferences/com.ghostwalker.live.json", 30.0);
    
    if (loc.isValid) {
        return loc;  // Return spoofed location
    }
    
    // No valid spoof data - tweak should return original location
    GhostLocation invalid = {0};
    invalid.isValid = NO;
    return invalid;
}

// Hook for CLLocationManager.location
%hook CLLocationManager
- (CLLocation *)location {
    GhostLocation ghostLoc = getGhostLocation();
    
    if (ghostLoc.isValid) {
        return createSpoofedLocation(ghostLoc);  // Return fake
    }
    
    return %orig;  // Return real location
}
%end
```

**The problem:** If the JSON file doesn't exist, the tweak calls `%orig` which should return the real location. But if locationd itself is being blocked or confused, it might return nil.

---

# 🔍 DIAGNOSTIC SCRIPT

Run this complete diagnostic:

```bash
#!/bin/bash
echo "=========================================="
echo "GHOST WALKER COMPLETE DIAGNOSTIC"
echo "=========================================="

echo ""
echo "=== 1. Check Bundle Filter ==="
echo "Looking for our app in the filter (should NOT be there):"
cat /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist
echo ""

echo "=== 2. Check if JSON file exists ==="
ls -la /var/mobile/Library/Preferences/com.ghostwalker.*.json 2>/dev/null || echo "No JSON files found"
echo ""

echo "=== 3. Check location services ==="
echo "Location authorization for our app:"
# This may not work but worth trying
sqlite3 /var/mobile/Library/TCC/TCC.db "SELECT client,auth_value FROM access WHERE service='kTCCServiceLocation' AND client LIKE '%ghost%';" 2>/dev/null || echo "Cannot query TCC database"
echo ""

echo "=== 4. Check if locationd is running ==="
ps aux | grep -i locationd | grep -v grep
echo ""

echo "=== 5. Check app logs ==="
echo "Recent Ghost Walker logs:"
log show --predicate 'processImagePath contains "GhostWalker"' --last 1m 2>/dev/null | tail -20 || echo "No logs found"
echo ""

echo "=== 6. Test network connectivity ==="
ping -c 1 gspe1-ssl.ls.apple.com > /dev/null 2>&1 && echo "Map servers: REACHABLE" || echo "Map servers: UNREACHABLE"
echo ""

echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="
```

---

# 🛠️ FIX ATTEMPTS

## Fix 1: Update Bundle Filter (Most Likely Fix)

```bash
# Backup original
cp /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist.bak

# Create correct filter that EXCLUDES our app
cat > /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist << 'EOF'
{ Filter = { Bundles = ( "com.apple.locationd", "com.apple.CoreLocation", "com.apple.springboard", "com.apple.findmy", "com.apple.Maps" ); }; }
EOF

echo "Bundle filter updated"

# Restart everything
killall -9 locationd
killall -9 GhostWalker 2>/dev/null
killall -9 SpringBoard

echo "Respringing... open the app again after it reloads"
```

## Fix 2: Test Without Tweak

Temporarily disable the tweak to see if the map works:

```bash
# Rename dylib to disable it
mv /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.dylib /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.dylib.disabled

# Restart
killall -9 locationd
killall -9 SpringBoard

echo "Tweak disabled. Test if the app map works now."
echo "If it does, the tweak was interfering with the app."
```

To re-enable:
```bash
mv /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.dylib.disabled /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.dylib
killall -9 SpringBoard
```

## Fix 3: Grant Location Permission Manually

```bash
# Try to insert permission into TCC database
sqlite3 /var/mobile/Library/TCC/TCC.db "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) VALUES ('kTCCServiceLocation', 'com.ghostwalker.app', 0, 2, 0, 1);"

sqlite3 /var/mobile/Library/TCC/TCC.db "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) VALUES ('kTCCServiceLocationAlwaysOn', 'com.ghostwalker.app', 0, 2, 0, 1);"

echo "Location permissions injected"
killall -9 locationd
```

---

# 📋 SUMMARY: Most Likely Issue

**The tweak is probably injecting into our own app and returning invalid/empty location data because no JSON file exists yet.**

**Solution:**
1. Run Fix 1 above to update the bundle filter
2. Or run Fix 2 to test with tweak disabled
3. If map works with tweak disabled, the bundle filter is the problem

---

# 📄 ALL SOURCE FILES LOCATION

All source code is in the GitHub repo:
- **Repo:** https://github.com/thomasrocks006-cmyk/Ghost-walker
- **App Sources:** `GhostWalker/App/Sources/`
- **Tweak Source:** `GhostWalker/Tweak/Tweak.x`
- **Bundle Filter:** `GhostWalker/Tweak/GhostWalker.plist`

The agent can clone and inspect:
```bash
cd /var/mobile/Documents
git clone https://github.com/thomasrocks006-cmyk/Ghost-walker.git
ls Ghost-walker/GhostWalker/
```

---

*Document created: November 28, 2025*
*For debugging Ghost Walker v2.0.0 map loading issue*
