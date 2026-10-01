ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullBypass

# Nguồn file
FullBypass_FILES = FullBypass.mm fishhook.c

# Chỉ áp dụng cho file .mm (C++)
FullBypass_CXXFLAGS = -fobjc-arc -std=c++17

# Không đặt CFLAGS chung vì nó áp dụng cho cả file .c
# fishhook.c sẽ biên dịch với chuẩn C mặc định

include $(THEOS_MAKE_PATH)/tweak.mk
