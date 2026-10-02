# ==============================
# Mod By Eri Nguyễn
# Liên Quân Mobile 1.64.11768577
# Bundle ID: com.garena.game.kgvo
# Output: libsupport.dylib
# ==============================

ARCHS = arm64 arm64e
TARGET = iphone:clang:15.0:14.0

INSTALL_TARGET_PROCESSES = com.garena.game.kgvo

# Tên thư viện đầu ra
LIBRARY_NAME = libsupport

# File nguồn
libsupport_FILES = liberi.mm

# Cờ biên dịch
libsupport_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function

# Thư viện & Framework
libsupport_FRAMEWORKS = UIKit Foundation
libsupport_LIBRARIES = objc fishhook

# Đường dẫn Theos
THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/library.mk
