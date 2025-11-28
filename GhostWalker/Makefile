# Ghost Walker - Master Makefile
# Aggregates the App and Tweak subprojects
# Target: iPhone 7, iOS 15.8.5, Dopamine Rootless

THEOS_DEVICE_IP ?= iphone
THEOS_DEVICE_PORT ?= 22

TARGET := iphone:clang:13.7:15.0
ARCHS := arm64

INSTALL_TARGET_PROCESSES = SpringBoard locationd

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = Tweak App

include $(THEOS_MAKE_PATH)/aggregate.mk

# Custom clean target
clean::
	@echo "Cleaning Ghost Walker..."
	@rm -rf .theos packages
