# Ghost Walker Tweak - Makefile
# Hooks CLLocationManager to return spoofed coordinates

# Target: iPhone 7, iOS 15.8.5, Dopamine Rootless
TARGET := iphone:clang:13.7:15.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GhostWalker

GhostWalker_FILES = Tweak.x
GhostWalker_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-everything
GhostWalker_FRAMEWORKS = CoreLocation Foundation

# For rootless jailbreaks (Dopamine, etc.)
GhostWalker_INSTALL_PATH = /var/jb/Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
