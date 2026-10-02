ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = liberi

liberi_FILES = liberi.mm fishhook.c
liberi_CXXFLAGS = -fobjc-arc -std=c++17 -w

include $(THEOS_MAKE_PATH)/tweak.mk
