export ARCHS = arm64 arm64e
export TARGET := iphone:clang:16.5:14.0
export THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidifyCompanion
LiquidifyCompanion_FILES = Tweak.xm LYCMetalGlassView.mm
LiquidifyCompanion_CFLAGS = -fobjc-arc -Wall -Wextra
LiquidifyCompanion_CCFLAGS = -std=c++17
LiquidifyCompanion_FRAMEWORKS = Foundation UIKit QuartzCore Metal MetalKit

include $(THEOS_MAKE_PATH)/tweak.mk

# Normalize permissions at package time (Theos may restage after after-stage).
before-package::
	@find "$(THEOS_STAGING_DIR)" -type d -exec chmod 755 {} +
	@find "$(THEOS_STAGING_DIR)" -type f -exec chmod 644 {} +
	@find "$(THEOS_STAGING_DIR)" -type f -name '*.dylib' -exec chmod 755 {} +
