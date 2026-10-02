TARGET = eri
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = YourGame

CC = clang
CXX = clang++
CFLAGS = -arch arm64 -arch arm64e -fPIC -shared -O2 -Wall
LDFLAGS = -framework Foundation -framework UIKit -dynamiclib

all: $(TARGET).dylib

$(TARGET).dylib: eri.mm
	$(CXX) $(CFLAGS) eri.mm -o $(TARGET).dylib $(LDFLAGS)
	@echo "✅ Xong: $(TARGET).dylib"

clean:
	rm -f $(TARGET).dylib
