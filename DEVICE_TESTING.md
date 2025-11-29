# 👻 Ghost Walker - Device Testing & Troubleshooting Guide

## Document Purpose
Complete instructions for an agent with root SSH access to test, diagnose, and fix Ghost Walker installation on the target device.

---

# 📱 TARGET DEVICE INFORMATION

| Property | Value |
|----------|-------|
| Device | iPhone 7 |
| iOS Version | 15.8.5 |
| Architecture | arm64 |
| Jailbreak | Dopamine (Rootless) |
| Root Path Prefix | `/var/jb/` |
| Package Manager | Sileo |

---

# 📦 PACKAGE INFORMATION

| Property | Value |
|----------|-------|
| Package ID | `com.ghostwalker.app` |
| Version | 3.0.1 |
| .deb File | `com.ghostwalker.app_3.0.1_iphoneos-arm64.deb` |
| Repo URL | `https://raw.githubusercontent.com/thomasrocks006-cmyk/Ghost-walker/main/repo/` |

---

# 📁 EXPECTED FILE LOCATIONS (After Install)

## App Bundle
```
/var/jb/Applications/GhostWalker.app/
├── GhostWalker          # Main executable binary
├── Info.plist           # App configuration
├── embedded.mobileprovision (optional)
└── (other resources)
```

## Tweak Files
```
/var/jb/Library/MobileSubstrate/DynamicLibraries/
├── GhostWalker.dylib    # The tweak binary that hooks CLLocationManager
└── GhostWalker.plist    # Bundle filter (which processes to inject into)
```

## Runtime Data Files (Created when app runs)
```
/var/mobile/Library/Preferences/
├── com.ghostwalker.live.json     # Live location data (app writes, tweak reads)
└── com.ghostwalker.persist.json  # Persistent state for resume after app close
```

---

# 🔧 WHAT EACH COMPONENT DOES

## 1. GhostWalker.app (The App)
**Purpose:** User interface for controlling location spoofing

**Features:**
- Map view showing real location (gray pin) and spoofed location (green pin)
- Three modes: Hold, Walk, Drive
- Speed/accuracy/drift sliders
- Writes spoofed coordinates to `/var/mobile/Library/Preferences/com.ghostwalker.live.json`
- Verification banner showing spoof status

**Expected Behavior:**
- App icon should appear on home screen
- Opens to a map view
- User can long-press map to set spoof location
- Tap "Hold" to start spoofing at that location

## 2. GhostWalker.dylib (The Tweak)
**Purpose:** System-wide hook that intercepts location requests

**How it works:**
1. Injected into processes listed in GhostWalker.plist
2. Hooks `CLLocationManager` and `CLLocation` methods
3. Reads JSON file written by app
4. Returns spoofed coordinates instead of real ones

**Hooked Methods:**
- `CLLocationManager.location` → Returns spoofed CLLocation
- `CLLocation.coordinate` → Returns spoofed lat/lon
- `CLLocation.horizontalAccuracy` → Returns spoofed accuracy
- `CLLocation.altitude`, `speed`, `course`, `timestamp`

## 3. GhostWalker.plist (Bundle Filter)
**Purpose:** Tells MobileSubstrate which processes to inject the tweak into

**Expected Content:**
```xml
{ Filter = { Bundles = ( "com.apple.locationd", "com.apple.CoreLocation", "com.apple.springboard" ); }; }
```

## 4. JSON IPC Files
**com.ghostwalker.live.json** - Written every 1-2 seconds by app:
```json
{
    "lat": 37.7749,
    "lon": -122.4194,
    "alt": 0,
    "accuracy": 25.0,
    "verticalAccuracy": 25.0,
    "course": -1,
    "speed": 0,
    "timestamp": 1732819200.0,
    "updateCount": 150
}
```

**com.ghostwalker.persist.json** - Saved when app closes for resume:
```json
{
    "isActive": true,
    "staticLat": 37.7749,
    "staticLon": -122.4194,
    "accuracyMin": 10,
    "accuracyMax": 45,
    ...
}
```

---

# 🔍 DIAGNOSTIC COMMANDS

Run these commands via SSH or NewTerm to diagnose the issue:

## Step 1: Verify Package Installation
```bash
# Check if package is installed
dpkg -l | grep ghost

# Expected output:
# ii  com.ghostwalker.app  3.0.1  iphoneos-arm64  Ghost Walker
```

## Step 2: Check App Bundle Location
```bash
# List Applications folder
ls -la /var/jb/Applications/ | grep -i ghost

# If found, check contents
ls -la /var/jb/Applications/GhostWalker.app/

# Check if binary is executable
file /var/jb/Applications/GhostWalker.app/GhostWalker
```

## Step 3: Check Tweak Installation
```bash
# Check if dylib exists
ls -la /var/jb/Library/MobileSubstrate/DynamicLibraries/ | grep -i ghost

# Should show:
# GhostWalker.dylib
# GhostWalker.plist

# Check plist content
cat /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist
```

## Step 4: Refresh Icon Cache
```bash
# This registers the app with SpringBoard
uicache -p /var/jb/Applications/GhostWalker.app

# If that fails, try full refresh
uicache -a

# Then respring
killall -9 SpringBoard
```

## Step 5: Check for Conflicts
```bash
# List all installed tweaks
dpkg -l | grep -E "spoof|locat|gps"

# Remove SpooferPro if installed (conflicts with our hooks)
dpkg -r com.spooferpro.jb 2>/dev/null || echo "SpooferPro not installed"
```

## Step 6: Check Runtime Logs
```bash
# Watch system log for our tweak
tail -f /var/log/syslog 2>/dev/null | grep -i ghost

# Or use os_log (iOS 15+)
log stream --predicate 'eventMessage contains "GhostWalker"' --level debug
```

## Step 7: Verify Tweak is Loading
```bash
# Check if dylib is being injected
# First, find locationd PID
ps aux | grep locationd

# Then check loaded libraries (requires root)
# Note: This may not work on all setups
cat /proc/$(pgrep locationd)/maps 2>/dev/null | grep -i ghost
```

## Step 8: Test JSON File Creation
```bash
# Check if prefs directory is writable
ls -la /var/mobile/Library/Preferences/

# Try creating a test file
echo '{"test":true}' > /var/mobile/Library/Preferences/com.ghostwalker.test.json
cat /var/mobile/Library/Preferences/com.ghostwalker.test.json
rm /var/mobile/Library/Preferences/com.ghostwalker.test.json
```

---

# 🛠️ COMMON ISSUES & FIXES

## Issue 1: App Icon Not Appearing
**Cause:** uicache not run, or app bundle in wrong location

**Fix:**
```bash
# Verify app exists
ls /var/jb/Applications/GhostWalker.app/

# Refresh cache
uicache -p /var/jb/Applications/GhostWalker.app

# Respring
killall -9 SpringBoard
```

## Issue 2: App Crashes on Launch
**Cause:** Missing dependencies, signing issues, or architecture mismatch

**Fix:**
```bash
# Check binary architecture
file /var/jb/Applications/GhostWalker.app/GhostWalker
# Should say: Mach-O 64-bit executable arm64

# Check entitlements
ldid -e /var/jb/Applications/GhostWalker.app/GhostWalker

# Re-sign if needed
ldid -S /var/jb/Applications/GhostWalker.app/GhostWalker

# Check for crash logs
ls -la /var/mobile/Library/Logs/CrashReporter/
cat /var/mobile/Library/Logs/CrashReporter/GhostWalker-*.ips 2>/dev/null | head -100
```

## Issue 3: Tweak Not Loading
**Cause:** Substrate not injecting, wrong bundle filter, or conflicting tweaks

**Fix:**
```bash
# Check plist syntax
plutil /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist

# Verify bundle filter targets
cat /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.plist

# Restart locationd to force reload
killall -9 locationd

# Respring for SpringBoard
killall -9 SpringBoard
```

## Issue 4: Location Not Changing in Apps
**Cause:** JSON file not being written or read

**Fix:**
```bash
# Watch for JSON file updates
watch -n 1 'cat /var/mobile/Library/Preferences/com.ghostwalker.live.json 2>/dev/null'

# If no file, app isn't writing - check app logs
# If file exists but not updating, app timer issue
# If file updating but location not changing, tweak issue
```

## Issue 5: App Installed But Wrong Location
**Cause:** Rootless path issue - app might be in `/Applications/` instead of `/var/jb/Applications/`

**Fix:**
```bash
# Check both locations
ls -la /Applications/ | grep -i ghost
ls -la /var/jb/Applications/ | grep -i ghost

# For rootless (Dopamine), must be in /var/jb/Applications/
# If in wrong place, move it:
mv /Applications/GhostWalker.app /var/jb/Applications/
uicache -a
```

---

# 📋 COMPLETE TESTING PROCEDURE

## Phase 1: Verify Installation
```bash
echo "=== Phase 1: Checking Installation ==="

echo "1. Package status:"
dpkg -l | grep ghost

echo ""
echo "2. App bundle:"
ls -la /var/jb/Applications/GhostWalker.app/ 2>/dev/null || echo "APP NOT FOUND!"

echo ""
echo "3. Tweak files:"
ls -la /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.* 2>/dev/null || echo "TWEAK NOT FOUND!"

echo ""
echo "4. Binary check:"
file /var/jb/Applications/GhostWalker.app/GhostWalker 2>/dev/null || echo "BINARY NOT FOUND!"
```

## Phase 2: Fix Icon Cache
```bash
echo "=== Phase 2: Refreshing Icon Cache ==="

uicache -p /var/jb/Applications/GhostWalker.app
echo "uicache complete. Respringing..."
killall -9 SpringBoard
```

## Phase 3: Test App Launch
After respring, try opening Ghost Walker from home screen.

If it crashes, check:
```bash
echo "=== Phase 3: Checking Crash Logs ==="

ls -lt /var/mobile/Library/Logs/CrashReporter/ | head -5
# Look for GhostWalker-*.ips files

# View most recent crash
cat /var/mobile/Library/Logs/CrashReporter/GhostWalker-*.ips 2>/dev/null | head -50
```

## Phase 4: Test Tweak
```bash
echo "=== Phase 4: Testing Tweak ==="

# Create test JSON manually
cat > /var/mobile/Library/Preferences/com.ghostwalker.live.json << 'EOF'
{
    "lat": 40.7128,
    "lon": -74.0060,
    "alt": 0,
    "accuracy": 25.0,
    "verticalAccuracy": 10.0,
    "course": -1,
    "speed": 0,
    "timestamp": 1732900000
}
EOF

echo "Created test location (New York City)"
echo "Now check Maps or Find My - should show NYC"

# Restart locationd to pick up new location
killall -9 locationd
echo "Restarted locationd"
```

## Phase 5: Cleanup Test
```bash
# Remove test file to stop spoofing
rm /var/mobile/Library/Preferences/com.ghostwalker.live.json
killall -9 locationd
echo "Test complete - location should return to real"
```

---

# 📊 EXPECTED OUTPUT SUMMARY

| Check | Expected Result |
|-------|-----------------|
| `dpkg -l \| grep ghost` | `ii  com.ghostwalker.app  3.0.1  iphoneos-arm64` |
| `ls /var/jb/Applications/GhostWalker.app/` | `GhostWalker  Info.plist  ...` |
| `ls /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.*` | `.dylib` and `.plist` files |
| `file .../GhostWalker` | `Mach-O 64-bit executable arm64` |
| App icon on home screen | Ghost Walker icon visible |
| Open app | Map view loads, no crash |
| Long-press map → Hold | Location spoofs in Find My |

---

# 🚨 EMERGENCY: Manual .deb Install

If Sileo repo isn't working, install manually:

```bash
# Download .deb directly
cd /var/mobile/Documents/
curl -L -o ghostwalker.deb "https://github.com/thomasrocks006-cmyk/Ghost-walker/raw/main/repo/debs/com.ghostwalker.app_3.0.1_iphoneos-arm64.deb"

# Install
dpkg -i ghostwalker.deb

# Fix dependencies if any
apt-get install -f

# Refresh icons
uicache -a

# Respring
killall -9 SpringBoard
```

---

# 📝 REPORT TEMPLATE

After running diagnostics, report back with:

```
=== GHOST WALKER DIAGNOSTIC REPORT ===

1. dpkg -l | grep ghost:
[paste output]

2. ls /var/jb/Applications/GhostWalker.app/:
[paste output]

3. ls /var/jb/Library/MobileSubstrate/DynamicLibraries/GhostWalker.*:
[paste output]

4. file /var/jb/Applications/GhostWalker.app/GhostWalker:
[paste output]

5. After uicache, does icon appear? [YES/NO]

6. Does app open without crashing? [YES/NO]

7. Crash log (if any):
[paste first 50 lines]

8. Any other errors:
[describe]
```

---

*Document created: November 28, 2025*
*For Ghost Walker v3.0.1 on Dopamine Rootless*
