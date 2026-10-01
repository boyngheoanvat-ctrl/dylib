CC = clang++
ARCH = arm64
SYSROOT = $(shell xcrun --sdk iphoneos --show-sdk-path)
CFLAGS = -arch $(ARCH) -isysroot $(SYSROOT) -std=c++17 -fPIC -O3
LDFLAGS = -dynamiclib -arch $(ARCH) -isysroot $(SYSROOT)

# === Đổi đuôi .mm ===
SOURCES = FullBypass.mm
OUTPUT = libmodmenu.dylib

all: $(OUTPUT)

$(OUTPUT): $(SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "✅ Tạo xong: $(OUTPUT)"
	@lipo -info $(OUTPUT)

clean:
	rm -f $(OUTPUT) *.o
