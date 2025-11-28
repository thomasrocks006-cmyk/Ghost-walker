# 👻 Ghost Walker

**Location Spoofing Suite for Jailbroken iOS 15+**

A complete location spoofing solution featuring a UIKit dashboard app and system tweak for walking virtually anywhere with realistic GPS simulation.

---

## 📱 Device Compatibility

- **Target Device:** iPhone 7 (and other arm64 devices)
- **iOS Version:** 15.0 - 15.8.5+
- **Jailbreak:** Dopamine / Rootless

---

## ✨ Features

### 🗺️ Walking Simulation
- **OSRM Routing** - Real walking paths along streets and sidewalks
- **Speed Control** - Walk at 0.5 - 3.0 m/s (adjustable)
- **Human-like Movement**:
  - Brownian motion drift (subtle random wandering)
  - GPS accuracy pulsing (simulates real device behavior)
  - Bearing calculation based on movement direction

### 📍 Map Dashboard
- Real-time map showing your actual and spoofed positions
- Three pin types:
  - **Gray Pin** - Your real location
  - **Green Pin** - Your spoofed location
  - **Red Pin** - Your destination
- Walking progress visualization with walked path overlay

### 🔍 Location Search
- Search for any destination by name
- Powered by MapKit's local search
- Categories: restaurants, stores, parks, airports, etc.

### ⚙️ Settings
- Walk Speed slider (0.5 - 3.0 m/s)
- Drift Amount (1 - 10 meters)
- GPS Accuracy range (5 - 100 meters)
- Presets: Normal, Stealth, Fast

---

## 📲 Installation

### Method 1: Add Sileo Repository (Recommended)

1. Open **Sileo** on your jailbroken iPhone
2. Go to **Sources** tab
3. Tap **+** to add a new source
4. Enter: `https://raw.githubusercontent.com/thomasrocks006-cmyk/Ghost-walker/main/repo/`
5. Find **Ghost Walker** and tap **Install**
6. Respring when prompted

### Method 2: Direct .deb Install

1. Download `com.ghostwalker.app_2.0.0_iphoneos-arm64.deb` from the `repo/debs/` folder
2. Transfer to your iPhone using AirDrop, iCloud, or SSH
3. Open with **Filza File Manager**
4. Tap the `.deb` file and select **Install**
5. Respring

---

## 🚀 Usage

1. **Open Ghost Walker** app from your home screen
2. **Tap the map** or use **Search** to set a destination
3. **Slide the speed** slider to your preferred walking speed
4. **Tap "Start Walk"** to begin spoofing
5. Watch your virtual self walk to the destination!
6. **Tap "Stop"** at any time to halt

### Tips
- Grant location permissions when prompted
- The tweak hooks `locationd` and `CoreLocation` system-wide
- Other apps will see your spoofed location
- 30-second stale data protection prevents using old coordinates

---

## 🏗️ Building from Source

### Requirements
- Docker installed on your system
- Git

### Build Steps

\`\`\`bash
# Clone the repository
git clone https://github.com/thomasrocks006-cmyk/Ghost-walker.git
cd Ghost-walker

# Build with Docker
docker build -t ghostwalker-builder .

# Compile the package
mkdir -p output
docker run --rm \
  -v "\$(pwd)/GhostWalker:/source:ro" \
  -v "\$(pwd)/output:/output" \
  ghostwalker-builder bash -c "
    mkdir -p /build
    cp -r /source/* /build/
    cd /build
    chmod -R 755 .
    chmod 644 control
    make clean
    make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
    cp packages/*.deb /output/
  "

# Package will be in ./output/
\`\`\`

---

## 📁 Project Structure

\`\`\`
GhostWalker/
├── control                 # Debian package metadata
├── Makefile               # Master build file
├── Tweak/
│   ├── Makefile
│   ├── Tweak.x            # Logos hook for CLLocationManager
│   └── GhostWalker.plist  # Bundle filter (locationd, CoreLocation)
└── App/
    ├── Makefile
    ├── Info.plist
    ├── Entitlements.plist
    └── Sources/
        ├── main.m
        ├── AppDelegate.m      # App entry point
        ├── MainViewController.m   # Map + controls UI
        ├── WalkingEngine.m        # OSRM routing + simulation
        ├── DestinationSearchController.m
        └── SettingsViewController.m
\`\`\`

---

## 🔧 How It Works

### IPC (Inter-Process Communication)
The app writes the spoofed location to a JSON file:
\`\`\`
/var/mobile/Library/Preferences/com.ghostwalker.live.json
\`\`\`

The tweak reads this file and returns the spoofed coordinates when apps request location data.

### Hooked Methods
- \`CLLocationManager.location\`
- \`CLLocationManager.startUpdatingLocation\`
- \`CLLocation.coordinate\`
- \`CLLocation.altitude\`
- \`CLLocation.horizontalAccuracy\`

---

## ⚠️ Disclaimer

This software is for educational and research purposes only. Location spoofing may violate the terms of service of certain apps and services. Use responsibly and at your own risk.

---

## 📜 License

MIT License - See LICENSE file

---

## 🙏 Credits

- [Theos](https://theos.dev/) - iOS build system
- [OSRM](http://project-osrm.org/) - Open Source Routing Machine
- Dopamine Jailbreak Team
