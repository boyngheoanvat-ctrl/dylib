ARCHS = arm64
TARGET = iphone:clang:15.0:14.0
INSTALL_TARGET_PROCESSES = TÊN_APP_CỦA_BẠN

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullBypass
FullBypass_FILES = FullBypass.x
FullBypass_CFLAGS = -fobjc-arc -w
FullBypass_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
