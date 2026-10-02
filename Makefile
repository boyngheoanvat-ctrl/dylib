# Định nghĩa đường dẫn Theos (thường là /var/mobile/theos hoặc /var/root/theos)
THEOS ?= /var/mobile/theos

TARGET := iphone:clang:latest:14.0
ARCHS := arm64

LIBRARY_NAME = eri

eri_FILES = liberi.mm
eri_CFLAGS = -fobjc-arc -std=c++11
eri_LDFLAGS += -lc++ \
               -framework Foundation \
               -framework UIKit \
               -framework CoreFoundation \
               -framework Security \
               -framework QuartzCore \
               -framework CoreGraphics \
               -framework CoreText \
               -framework AVFoundation \
               -framework Accelerate \
               -framework Metal \
               -framework MetalKit

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
