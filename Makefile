# Cấu hình SDK và Compiler
SDK = iphoneos
CC = xcrun -sdk $(SDK) clang
CFLAGS = -fobjc-arc -shared -undefined dynamic_lookup
LDFLAGS = -framework Foundation -framework UIKit

# Tên file nguồn (đổi thành eri.mm nếu file của bạn là eri.mm)
SRC = eri.m
TARGET = eri.dylib

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)
