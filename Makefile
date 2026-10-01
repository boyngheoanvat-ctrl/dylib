ARCHS = arm64
TARGET = iphone:clang:latest:14.0

INSTALL_PROGRAM = $(THEOS)/bin/install

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullBypass

FullBypass_FILES = FullBypass.mm
FullBypass_CFLAGS = -fobjc-arc
FullBypass_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
