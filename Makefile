# ==============================================
# MOD BY ERI NGUYỄN — Makefile Hoàn Chỉnh
# ==============================================

# Kiến trúc — iPhone 6s trở lên đều dùng arm64/arm64e
ARCHS = arm64 arm64e

# Mục tiêu biên dịch: SDK mới nhất, hỗ trợ iOS 13.0 trở lên
TARGET = iphone:clang:latest:13.0

# Bỏ qua thông báo build chậm
THEOS_IGNORE_PARALLEL_BUILDING_NOTICE = yes

# Đường dẫn Theos — tự động lấy
THEOS ?= $(HOME)/theos

include $(THEOS)/makefiles/common.mk

# Tên thư viện đầu ra: libsupport.dylib
LIBRARY_NAME = libsupport

# File nguồn cần biên dịch
libsupport_FILES = liberi.mm

# Cờ biên dịch
libsupport_CFLAGS = -fobjc-arc -std=c++17 -fvisibility=hidden

# Framework cần liên kết
libsupport_FRAMEWORKS = UIKit Foundation

# Thư viện cần liên kết
libsupport_LIBRARIES = fishhook

# Loại liên kết: thư viện động
libsupport_LINKAGE_TYPE = dynamic

include $(THEOS_MAKE_PATH)/library.mk
