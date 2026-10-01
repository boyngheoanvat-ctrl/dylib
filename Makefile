ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullBypass

FullBypass_FILES = FullBypass.mm fishhook.c
FullBypass_CFLAGS = -fobjc-arc -std=c++17

include $(THEOS_MAKE_PATH)/tweak.mk
