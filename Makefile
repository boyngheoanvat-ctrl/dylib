ARCHS = arm64
TARGET = iphone:clang:15.0:14.0
THEOS_DEVICE_IP = 127.0.0.1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullBypass

FullBypass_FILES = FullBypass.mm
FullBypass_CFLAGS = -fobjc-arc -std=c++17
FullBypass_LDFLAGS = -dynamiclib
FullBypass_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
