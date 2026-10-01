CC = clang++
ARCH = arm64
SYSROOT = $(shell xcrun --sdk iphoneos --show-sdk-path)
CFLAGS = -arch $(ARCH) -isysroot $(SYSROOT) -std=c++17 -fPIC -O3
LDFLAGS = -dynamiclib -arch $(ARCH) -isysroot $(SYSROOT)

# === SỬA DÒNG NÀY ===
SOURCES = FullBypass.x
OUTPUT = libmodmenu.dylib

all: $(OUTPUT)

$(OUTPUT): $(SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "✅ Tạo xong: $(OUTPUT)"
	@lipo -info $(OUTPUT)

clean:
	rm -f $(OUTPUT) *.o
