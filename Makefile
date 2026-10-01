# Makefile — Build .dylib cho iOS ARM64

CC = clang++
ARCH = arm64
SYSROOT = $(shell xcrun --sdk iphoneos --show-sdk-path)
CFLAGS = -arch $(ARCH) -isysroot $(SYSROOT) -std=c++17 -fPIC -O3
LDFLAGS = -dynamiclib -arch $(ARCH) -isysroot $(SYSROOT)

# === TÊN FILE NGUỒN ===
# Nếu file nguồn của bạn có tên khác → sửa ở đây
SOURCES = Main.cpp A64Hook.cpp
HEADERS = Macros.h

OUTPUT = libmodmenu.dylib

all: $(OUTPUT)

$(OUTPUT): $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SOURCES)
	@echo "✅ Tạo xong: $(OUTPUT)"
	@lipo -info $(OUTPUT)

clean:
	rm -f $(OUTPUT) *.o
