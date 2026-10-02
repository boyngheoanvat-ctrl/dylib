# ==============================================
# Mod By Eri Nguyễn
# Game: Liên Quân Mobile
# Phiên bản: 1.64.11768577
# Bundle ID: com.garena.game.kgvo
# Output: libsupport.dylib
# ==============================================

ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = com.garena.game.kgvo

LIBRARY_NAME = libsupport

# === Nguồn code (bao gồm fishhook) ===
libsupport_FILES = liberi.mm fishhook/fishhook.c

# === Cờ biên dịch ===
libsupport_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function

# === Framework & Thư viện ===
libsupport_FRAMEWORKS = UIKit Foundation
libsupport_LIBRARIES =

# === Cấu hình thiết bị ===
THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

# === Theos Rules ===
include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/library.mk
