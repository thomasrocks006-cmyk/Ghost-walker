# Ghost Walker App - Makefile
# UIKit Dashboard for location spoofing control (Objective-C)
# Target: iPhone 7, iOS 15.8.5, Dopamine Rootless

TARGET := iphone:clang:13.7:15.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = GhostWalker

GhostWalker_FILES = $(wildcard Sources/*.m)
GhostWalker_FRAMEWORKS = UIKit MapKit CoreLocation Foundation
GhostWalker_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# Codesign with entitlements (use absolute path from App directory)
GhostWalker_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/App/Entitlements.plist

# For rootless jailbreaks
GhostWalker_INSTALL_PATH = /var/jb/Applications

include $(THEOS_MAKE_PATH)/application.mk

# Copy resources after staging
after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/var/jb/Applications/GhostWalker.app
	@cp $(THEOS_PROJECT_DIR)/App/Info.plist $(THEOS_STAGING_DIR)/var/jb/Applications/GhostWalker.app/
	@cp $(THEOS_PROJECT_DIR)/App/Entitlements.plist $(THEOS_STAGING_DIR)/var/jb/Applications/GhostWalker.app/
