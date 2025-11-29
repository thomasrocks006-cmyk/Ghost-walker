# 👻 Ghost Walker - Master Development Document

## Version: 2.0.0 RELEASED ✅
## Target Device: iPhone 7, iOS 15.8.5, Dopamine Rootless Jailbreak
## Last Updated: November 28, 2025 - 17:25 UTC

---

# 🚀 BUILD STATUS

| Component | Status | Version |
|-----------|--------|--------|
| App (UIKit) | ✅ Built | 2.1.0 |
| Tweak (Logos) | ✅ Built | 2.1.0 |
| .deb Package | ✅ Ready | 2.1.0 |
| Sileo Repo | ✅ Updated | Live |
| Device Install | ⚠️ Testing | locationd injection issue |
| Tweak Injection | ⚠️ Partial | SpringBoard works, locationd fails |

**Repo URL:** `https://raw.githubusercontent.com/thomasrocks006-cmyk/Ghost-walker/main/repo/`

**Direct .deb:** `repo/debs/com.ghostwalker.app_2.1.0_iphoneos-arm64.deb`

**v2.1.0 Changes:**
- Multi-path JSON support (checks /var/mobile, /var/jb/var/mobile, /tmp)
- Executables filter for locationd daemon injection
- Enhanced logging for path debugging

**Debug Docs:**
- `DEVICE_TESTING.md` - Installation diagnostics
- `SOURCE_CODE_FIX.md` - Map loading fix & source code

---

# 📋 TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [Current Architecture](#2-current-architecture)
3. [How It Works](#3-how-it-works)
4. [Files & Components](#4-files--components)
5. [Installed Packages Analysis](#5-installed-packages-analysis)
6. [Feature Gap Analysis](#6-feature-gap-analysis)
7. [Implementation Plan](#7-implementation-plan)
8. [Technical Decisions](#8-technical-decisions)

---

# 1. PROJECT OVERVIEW

## 1.1 Goal
Create a location spoofing suite that emulates **realistic GPS behavior** as seen on Find My and Apple Maps, including:
- Live location updates (green circle look)
- Accuracy circle that changes size periodically
- Location dot that drifts naturally
- Route simulation for walking/driving
- **Persistent operation** that survives app closure/crash
- Failsafe protection against rubber-banding detection

## 1.2 Target Apps to Fool
- Find My (primary target)
- Apple Maps
- Any app using CoreLocation

## 1.3 What "Real" iPhone GPS Looks Like
Based on observation of real iPhone behavior:

| Behavior | Real iPhone | Our Target |
|----------|-------------|------------|
| Location update frequency | ~1 second | 1-2 seconds (user configurable) |
| Accuracy circle change | Every 5-15 seconds | Every 10 seconds (user configurable: 5-30s) |
| Accuracy range | 5m - 65m typical | User defined (e.g., 10-20m, 15-45m) |
| Location drift | 1-5 meters naturally | User defined (e.g., 2-5m, 5-10m) |
| Drift pattern | Random walk (Brownian) | Brownian motion simulation |

---

# 2. CURRENT ARCHITECTURE

## 2.1 Two-Component Design

```
┌─────────────────────────────────────────────────────────────────┐
│                         GHOST WALKER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐         ┌─────────────────────┐        │
│  │                     │         │                     │        │
│  │    GhostWalker      │  JSON   │    GhostWalker      │        │
│  │       APP           │ ──────► │      TWEAK          │        │
│  │   (UIKit/Obj-C)     │  File   │   (Logos/Obj-C)     │        │
│  │                     │         │                     │        │
│  └─────────────────────┘         └─────────────────────┘        │
│           │                               │                      │
│           │ User controls                 │ Hooks                │
│           │ location/settings             │ CLLocationManager    │
│           ▼                               ▼                      │
│  ┌─────────────────────┐         ┌─────────────────────┐        │
│  │ /var/mobile/Library │         │   locationd         │        │
│  │ /Preferences/       │         │   CoreLocation      │        │
│  │ com.ghostwalker.    │         │   All Apps          │        │
│  │ live.json           │         │                     │        │
│  └─────────────────────┘         └─────────────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 2.2 IPC Method: JSON File

**Path:** `/var/mobile/Library/Preferences/com.ghostwalker.live.json`

**Format:**
```json
{
    "lat": 37.7749,
    "lon": -122.4194,
    "alt": 0,
    "accuracy": 25.0,
    "verticalAccuracy": 25.0,
    "course": 180.0,
    "speed": 1.4,
    "timestamp": 1732819200.0,
    "updateCount": 150,
    "mode": 1,
    "isMoving": true
}
```

## 2.3 Why NOT Using LocSim

You have `locsim` (1.1.8-1) installed. Here's the comparison:

| Feature | LocSim | Ghost Walker |
|---------|--------|--------------|
| Method | Sets location once via CLI | Continuous updates via tweak |
| Drift simulation | ❌ None | ✅ Brownian motion |
| Accuracy pulsing | ❌ None | ✅ Circle changes periodically |
| Route walking | ❌ None | ✅ OSRM routing |
| Background persistence | ❌ Stops | ✅ Tweak keeps running |
| Find My realism | ❌ Static dot | ✅ Live moving dot |
| Speed control | ❌ None | ✅ Walk/drive modes |

**Verdict:** LocSim is CLI-based for quick one-off spoofs. Ghost Walker provides the realistic "live location" look that Find My expects.

**However:** We could potentially USE locsim as a fallback or integration point. It's already installed and working.

---

# 3. HOW IT WORKS

## 3.1 App Flow

```
User opens app
       │
       ▼
┌─────────────────────────────┐
│ Check for persistent state  │ ◄── Resume if was spoofing
│ from previous session       │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Display map with:           │
│ • Real location (gray pin)  │
│ • Spoofed location (green)  │
│ • Destination (red pin)     │
└─────────────────────────────┘
       │
       ▼
User selects location (tap map, search, or set current)
       │
       ▼
┌─────────────────────────────┐
│ STATIC HOLD MODE            │
│ or                          │
│ ROUTE MODE (walk/drive)     │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Start update timer          │
│ (every 1-2 seconds)         │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Each tick:                  │
│ 1. Calculate position       │
│ 2. Apply drift              │
│ 3. Check for rubber-band    │
│ 4. Write to JSON file       │
│ 5. Update UI                │
└─────────────────────────────┘
       │
       ▼
Tweak reads JSON, returns spoofed location to all apps
```

## 3.2 Tweak Flow

```
App requests location
       │
       ▼
┌─────────────────────────────┐
│ CLLocationManager.location  │
│ (hooked by our tweak)       │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Read JSON file              │
│ (rate limited to 100ms)     │
└─────────────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Is data valid & fresh?      │
│ (< 30 seconds old)          │
└─────────────────────────────┘
       │
       ├── YES ──► Return spoofed CLLocation
       │
       └── NO ───► Return real location (failsafe)
```

---

# 4. FILES & COMPONENTS

## 4.1 App Files

| File | Purpose |
|------|---------|
| `App/Sources/main.m` | UIKit app entry point |
| `App/Sources/AppDelegate.m/h` | App lifecycle, creates main view |
| `App/Sources/MainViewController.m/h` | Map view, control panel, status indicators |
| `App/Sources/WalkingEngine.m/h` | Core simulation engine - routing, drift, accuracy |
| `App/Sources/DestinationSearchController.m/h` | MapKit location search |
| `App/Sources/SettingsViewController.m/h` | User settings UI |
| `App/Info.plist` | App bundle configuration |
| `App/Entitlements.plist` | Location permissions, platform entitlements |
| `App/Makefile` | Theos build configuration |

## 4.2 Tweak Files

| File | Purpose |
|------|---------|
| `Tweak/Tweak.x` | Logos hooks for CLLocationManager & CLLocation |
| `Tweak/GhostWalker.plist` | Bundle filter (locationd, CoreLocation, SpringBoard) |
| `Tweak/Makefile` | Theos build configuration |

## 4.3 Build Files

| File | Purpose |
|------|---------|
| `Makefile` | Master aggregator |
| `control` | Debian package metadata |
| `Dockerfile` | Linux build environment |

## 4.4 Runtime Files (on device)

| Path | Purpose |
|------|---------|
| `/var/jb/Applications/GhostWalker.app/` | Installed app bundle |
| `/var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.dylib` | Installed tweak |
| `/var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist` | Tweak filter |
| `/var/mobile/Library/Preferences/com.ghostwalker.live.json` | Live location data (IPC) |
| `/var/mobile/Library/Preferences/com.ghostwalker.persist.json` | Persistent state for resume |

---

# 5. INSTALLED PACKAGES ANALYSIS

## 5.1 Potentially Useful Packages

| Package | Version | Usefulness | How We Could Use It |
|---------|---------|------------|---------------------|
| **locsim** | 1.1.8-1 | ⭐⭐⭐ Medium | Fallback CLI method, already works |
| **libkrw0** | 1.1.1-2 | ⭐⭐⭐⭐ High | Kernel read/write for advanced hooks |
| **libkrw0-dopamine** | 2.0.4 | ⭐⭐⭐⭐ High | Dopamine-specific kernel access |
| **Cephei** | 2.0 | ⭐⭐⭐ Medium | Preference bundle support for settings |
| **libroot-dopamine** | 1.0.1 | ⭐⭐⭐⭐ High | Rootless path resolution |
| **launchctl** | 1:1.1.1 | ⭐⭐⭐⭐⭐ Critical | Launch daemon control for persistence |
| **openssh** | 9.7p1-1 | ⭐⭐ Low | Remote debugging |

## 5.2 Packages to Remove (Conflicts)

| Package | Reason |
|---------|--------|
| **SpooferPro** | May conflict with our hooks, using same methods |

## 5.3 Recommended Additional Packages

| Package | Purpose | Available From |
|---------|---------|----------------|
| **Choicy** | Disable other tweaks per-app to prevent conflicts | BigBoss/Havoc |
| **PowerGuard** | Prevent jetsam from killing background processes | Various |
| **PreferenceLoader** | Native settings integration | BigBoss |

---

# 6. FEATURE GAP ANALYSIS

## What We HAVE ✅

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Map with interactive view | ✅ Done | MKMapView with annotations |
| 2 | OSRM routing | ✅ Done | Walking & driving routes |
| 3 | Speed control slider | ✅ Done | 0.5 - 8.0 m/s |
| 4 | Basic accuracy pulsing | ✅ Done | Sine wave oscillation |
| 5 | Status indicators | ✅ Done | Colored dot + label |
| 6 | Route visualization | ✅ Done | Polyline overlays |
| 7 | Location search | ✅ Done | MapKit MKLocalSearch |
| 8 | Settings page | ✅ Done | Speed/drift/accuracy sliders |
| 9 | Tweak hooks | ✅ Done | CLLocationManager/CLLocation |
| 10 | JSON IPC | ✅ Done | File-based communication |

## What's MISSING ❌ → Implementation Plan

| # | Feature | Priority | Complexity | Status |
|---|---------|----------|------------|--------|
| 1 | **Hold location forever with drift** | 🔴 Critical | Medium | ✅ DONE - startStaticSpoofAtLocation: |
| 2 | **Background persistence (survive app close)** | 🔴 Critical | Hard | ✅ DONE - persist.json + tweak fallback |
| 3 | **Jetsam prevention** | 🔴 Critical | Hard | 🔄 Settings added, needs daemon |
| 4 | **Driving mode** | 🟡 High | Easy | ✅ DONE - GhostMovementModeDriving |
| 5 | **Rubber-band failsafe** | 🟡 High | Medium | ✅ DONE - checkForRubberBand: |
| 6 | **Configurable accuracy ranges** | 🟡 High | Easy | ✅ DONE - accuracyMin/Max sliders |
| 7 | **Realistic accuracy update interval** | 🟡 High | Easy | ✅ DONE - 5-30s configurable |
| 8 | **Verification markers UI** | 🟢 Medium | Easy | ✅ DONE - banner with status/timestamp |
| 9 | **Last known location fallback** | 🟢 Medium | Easy | ✅ DONE - g_cachedLocation in tweak |
| 10 | **Better drift configuration** | 🟢 Medium | Easy | ✅ DONE - driftMin/Max sliders |

---

# 7. IMPLEMENTATION PLAN

## Phase 1: Core Location Persistence (CRITICAL)

### Task 1.1: Hold Location Forever with Drift
**Goal:** User sets a location, it stays there FOREVER until explicitly stopped, with realistic drift.

**Implementation:**
```
- Add "Hold Here" button that sets current map center as spoof location
- Timer runs continuously (even when not "walking")
- Each tick:
  - Base position = user's set location
  - Apply random drift within user's specified range
  - Write to JSON
- Never stops unless user taps "Stop Spoofing"
```

**Files to modify:**
- `WalkingEngine.m` - Add `startHoldingAtLocation:` method
- `MainViewController.m` - Add "Hold Here" and "Stop All" buttons

### Task 1.2: Background Persistence (Survive App Close)
**Goal:** Location continues spoofing even when app is killed.

**Implementation Options:**

**Option A: Launch Daemon (Best)**
```
- Create LaunchDaemon plist
- Daemon reads persist.json and writes live.json
- Runs independently of app
- Use launchctl to manage
```

**Option B: Tweak-Based Fallback (Current)**
```
- Tweak reads persist.json if live.json is stale
- Applies saved drift/accuracy settings
- Less precise but simpler
```

**Files to create:**
- `Daemon/ghostwalkerd.m` - Standalone daemon
- `Daemon/com.ghostwalker.daemon.plist` - LaunchDaemon config

### Task 1.3: Jetsam Prevention
**Goal:** Prevent iOS from killing our background processes.

**Implementation:**
```
- Set QoS flags on our process
- Use background task assertions
- Consider process-specific jetsam limit adjustment (requires libkrw)
```

**Options:**
1. Use existing tweak like PowerGuard
2. Create our own jetsam exception plist
3. Use `memorystatus_control()` syscall (advanced)

---

## Phase 2: Realistic GPS Simulation

### Task 2.1: Configurable Accuracy Ranges
**Goal:** User can set specific ranges like "10-20m" or "15-45m"

**Implementation:**
```
Settings UI:
- "Accuracy Min" slider: 5m - 50m
- "Accuracy Max" slider: 10m - 100m
- Validation: max > min

Engine:
- Random value within range each update
```

### Task 2.2: Realistic Accuracy Update Interval
**Goal:** Accuracy circle changes every 5-30 seconds (like real iPhone)

**Based on real iPhone observation:**
- Accuracy typically updates every **5-15 seconds**
- Not every second (too fast, looks fake)
- Add some randomness (+/- 2 seconds)

**Implementation:**
```
Settings UI:
- "Circle Update Interval" slider: 5s - 30s (default 10s)

Engine:
- Separate timer for accuracy updates
- Only change accuracy when this timer fires
- Add ±2 second random variation
```

### Task 2.3: Better Drift Configuration
**Goal:** User specifies drift range like "2-5m" or "5-10m"

**Implementation:**
```
Settings UI:
- "Drift Min" slider: 0m - 10m
- "Drift Max" slider: 1m - 20m
- Preset buttons: "Subtle (1-3m)", "Normal (2-5m)", "Wide (5-10m)"
```

---

## Phase 3: Route & Movement

### Task 3.1: Driving Mode
**Goal:** Simulate driving with faster speeds and appropriate routing.

**Implementation:**
```
- Mode selector: Walk | Drive
- Walking: 0.5 - 3.0 m/s, OSRM "foot" profile
- Driving: 5 - 40 m/s, OSRM "car" profile
- Faster update interval for driving (0.5s)
- Less drift when driving (more GPS accuracy in cars)
```

### Task 3.2: Rubber-Band Failsafe
**Goal:** If location jumps unexpectedly, freeze at last known good position.

**Implementation:**
```
- Track last N positions
- Calculate jump distance between updates
- If jump > threshold (based on speed + margin):
  - Trigger failsafe
  - Freeze at last known good location
  - Show warning to user
  - Keep writing last good location to JSON
```

---

## Phase 4: UI & UX

### Task 4.1: Verification Markers UI
**Goal:** Clear visual confirmation that spoofing is active and working.

**Implementation:**
```
Main screen additions:
- Large banner: "🟢 SPOOFING ACTIVE" or "⚪ IDLE"
- Timestamp: "Last update: 1 second ago"
- Update counter: "Updates: 1,234"
- Session duration: "Active for: 2h 15m"
- Accuracy indicator: "Circle: 25m"
- Failsafe status: "✅ Normal" or "⚠️ Failsafe Active"
```

### Task 4.2: Last Known Location Fallback
**Goal:** If JSON write fails, keep using last successful location.

**Implementation:**
```
Engine:
- Always cache last successfully written location
- If write fails, don't update currentSpoofedLocation
- Retry write on next tick

Tweak:
- If JSON is missing or corrupt, use cached location
- Only return to real location if cache is >30s old
```

---

# 8. TECHNICAL DECISIONS

## 8.1 Why JSON File IPC?

| Method | Pros | Cons |
|--------|------|------|
| **JSON File** ✅ | Simple, persistent, debuggable | Disk I/O overhead |
| Darwin Notifications | Low overhead | No data payload, just signals |
| Mach Messages | Fast, bidirectional | Complex, crash-prone |
| Shared Memory | Fastest | Requires same process group |
| XPC | Apple's preferred | Requires entitlements |

**Decision:** JSON file is best for:
- Persistence (survives crashes)
- Debuggability (can inspect file)
- Simplicity (easy to implement)
- Cross-process (app → tweak → daemon)

## 8.2 Why Not Use LocSim Directly?

LocSim is great but:
1. **One-shot** - Sets location once, doesn't update
2. **No drift** - Static point, looks fake on Find My
3. **No persistence** - Must re-run after reboot
4. **No UI** - CLI only

We could use LocSim as a **fallback** if our method fails.

## 8.3 Accuracy Timing Analysis

From observing real iPhones:

```
Scenario: Standing still outdoors
- GPS accuracy: 5m - 15m (good conditions)
- Update pattern: Smooth, every ~1 second
- Circle size change: Every 5-10 seconds

Scenario: Walking
- GPS accuracy: 10m - 30m
- Update pattern: Smooth with slight variations
- Circle size change: Every 8-15 seconds

Scenario: Indoors
- GPS accuracy: 30m - 65m+
- Update pattern: Jumpier
- Circle size change: Every 10-20 seconds
```

**Our defaults:**
- Update frequency: 1 second (configurable 0.5s - 2s)
- Accuracy change interval: 10 seconds (configurable 5s - 30s)
- Accuracy range: 10m - 45m (user configurable)

---

# 9. NEXT STEPS

## Completed Actions ✅

1. ✅ Create this master document
2. ✅ Complete WalkingEngine.m with new features (Hold/Walk/Drive modes)
3. ✅ Create improved Tweak.x with persistent fallback + caching
4. ✅ Update MainViewController.m with new UI elements (mode selector, verification banner)
5. ✅ Update SettingsViewController.m with new options (all 16 settings)
6. ✅ Build v2.0.0 .deb package
7. ✅ Push to GitHub
8. ✅ Update Sileo repo with v2.0.0

## Remaining Tasks ⏳

1. ⏳ Create launch daemon for TRUE background operation (currently using persist.json fallback)
2. ⏳ Add jetsam prevention via daemon or kernel hooks
3. ⏳ Test on physical device (iPhone 7, iOS 15.8.5)
4. ⏳ Remove SpooferPro before testing
5. ⏳ Verify Find My shows realistic spoofed location

## Commands to Remove SpooferPro

```bash
# SSH to device
ssh mobile@<device-ip>

# Remove SpooferPro
sudo dpkg -r com.spooferpro.jb

# Or via Sileo: long-press on SpooferPro → Uninstall
```

---

*Document created for Ghost Walker v2.0 development*
*This is a living document - update as implementation progresses*
