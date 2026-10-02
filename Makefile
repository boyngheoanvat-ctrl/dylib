SDK = iphoneos
CC = xcrun -sdk $(SDK) clang
CFLAGS = -fobjc-arc -shared -undefined dynamic_lookup
LDFLAGS = -framework Foundation -framework UIKit

SRC = liberi.mm
TARGET = eri.dylib

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)
