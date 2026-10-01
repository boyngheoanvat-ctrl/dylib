ARCHS = arm64 arm64e
TARGET = iphone:clang:15.0:14.0
INSTALL_TARGET_PROCESSES = THAY_TÊN_APP_CỦA_BẰNG_Ở_DÂY

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullBypass
FullBypass_FILES = FullBypass.x
FullBypass_CFLAGS = -fobjc-arc -w
FullBypass_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
