# Tự động tìm đường dẫn Theos tùy theo môi trường bạn đang build
ifeq ($(THEOS),)
    ifneq ($(wildcard /var/mobile/theos/.),)
        THEOS := /var/mobile/theos
    else ifneq ($(wildcard $(HOME)/theos/.),)
        THEOS := $(HOME)/theos
    else ifneq ($(wildcard /theos/.),)
        THEOS := /theos
    else
        THEOS := /opt/theos
    endif
endif

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
