# ==============================================
# Mod By Eri Nguyễn
# Game: Liên Quân Mobile
# Ver: 1.64.11768577
# Bundle ID: com.garena.game.kgvo
# Output: libsupport.dylib
# ==============================================

ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = com.garena.game.kgvo

LIBRARY_NAME = libsupport
libsupport_FILES = liberi.mm fishhook.c
libsupport_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
libsupport_FRAMEWORKS = UIKit Foundation
libsupport_LIBRARIES =

THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/library.mk
