ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_IGNORE_PARALLEL_BUILDING_NOTICE = yes

THEOS = /Users/runner/theos

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libsupport
libsupport_FILES = liberi.mm
libsupport_CFLAGS = -fobjc-arc -std=c++17 -fvisibility=hidden
libsupport_FRAMEWORKS = UIKit Foundation
libsupport_LIBRARIES = fishhook
libsupport_LINKAGE_TYPE = dynamic

include $(THEOS)/makefiles/library.mk
