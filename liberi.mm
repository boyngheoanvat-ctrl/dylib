#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>

static UIWindow *menuWindow = nil;
static uintptr_t unity_base_addr = 0;

// Hàm lấy base address của UnityFramework
uintptr_t get_image_slide_address(const char* image_name) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, image_name)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

// Hàm ghi đè bộ nhớ an toàn
bool RawCodePatch(uintptr_t absolute_address, const void* patch_bytes, size_t length) {
    if (absolute_address == 0) return false;

    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t page_start = (absolute_address & ~(page_size - 1));

    if (mprotect((void*)page_start, page_size, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        return false;
    }

    memcpy((void*)absolute_address, patch_bytes, length);

    mprotect((void*)page_start, page_size, PROT_READ | PROT_EXEC);
    __builtin___clear_cache((char*)absolute_address, (char*)absolute_address + length);
    return true;
}

// Chuyển đổi Hex sang mảng Byte
void parseHexBytes(const char* hexStr, unsigned char* outBytes, size_t* outLen) {
    size_t len = strlen(hexStr);
    size_t count = 0;
    for (size_t i = 0; i < len; i++) {
        if (hexStr[i] == ' ' || hexStr[i] == '\t') continue;
        if (i + 1 < len) {
            unsigned int byteVal;
            if (sscanf(hexStr + i, "%2x", &byteVal) == 1) {
                outBytes[count++] = (unsigned char)byteVal;
                i++;
            }
        }
    }
    *outLen = count;
}

// Thực hiện patch theo offset
void PatchOffset(uintptr_t base_addr, uint64_t offset, const char* hex_bytes) {
    if (base_addr == 0) return;
    uintptr_t target_addr = base_addr + offset;
    
    unsigned char bytes[256];
    size_t len = 0;
    parseHexBytes(hex_bytes, bytes, &len);
    
    RawCodePatch(target_addr, bytes, len);
}

// Hàm kích hoạt Antiban mới gọn nhẹ
void apply_antiban() {
    if (unity_base_addr == 0) return;

    const char* ret4 = "C0 03 5F D6";
    uint64_t new_antiban_offsets[] = {
        0x706D890, 0x706D914, 0x706D9CC, 0x706DAB0,
        0x706DD14, 0x706E0A0, 0x706E21C, 0x706E304,
        0x706E6BC, 0x706E754, 0x677FA8C, 0x546B08,
        0x83B634,  0x5B61A0,  0x5B6380,  0x5B65CC,
        0x5B6764
    };
    
    for (size_t i = 0; i < sizeof(new_antiban_offsets) / sizeof(new_antiban_offsets[0]); i++) {
        PatchOffset(unity_base_addr, new_antiban_offsets[i], ret4);
    }
}

// Giao diện Menu nổi
@interface MenuViewController : UIViewController
@end

@implementation MenuViewController {
    UIView *mainBox;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    // Khung Menu chính
    mainBox = [[UIView alloc] initWithFrame:CGRectMake(40, 40, 270, 360)];
    mainBox.backgroundColor = [UIColor colorWithWhite:0.12f alpha:0.95f];
    mainBox.layer.cornerRadius = 12;
    mainBox.layer.borderWidth = 1.5f;
    mainBox.layer.borderColor = [UIColor cyanColor].CGColor;
    [self.view addSubview:mainBox];

    // Tiêu đề Menu
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 250, 30)];
    titleLabel.text = @"MOD BY ERI NGUYỄN";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [mainBox addSubview:titleLabel];

    // Danh sách tính năng kèm Antiban mới
    NSArray *features = @[@"Antiban (Bật sơm)", @"1. Hack Map", @"2. Cam Xa 3 Nấc", @"3. Show Unit Địch", @"4. Show Lịch Sử Đấu", @"5. Ẩn Tia"];
    for (int i = 0; i < features.count; i++) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 50 + (i * 45), 170, 30)];
        lbl.text = features[i];
        lbl.textColor = (i == 0) ? [UIColor greenColor] : [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:12];
        [mainBox addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(200, 50 + (i * 45), 0, 0)];
        sw.tag = i; 
        if (i == 0) [sw setOn:YES animated:NO]; // Mặc định bật Antiban
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [mainBox addSubview:sw];
    }

    // Nút đóng menu
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(220, 10, 35, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [mainBox addSubview:closeBtn];

    // Nút nổi mở menu
    UIButton *floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatBtn.frame = CGRectMake(15, 80, 45, 45);
    floatBtn.backgroundColor = [UIColor cyanColor];
    [floatBtn setTitle:@"MOD" forState:UIControlStateNormal];
    [floatBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    floatBtn.layer.cornerRadius = 22.5f;
    [floatBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:floatBtn];
}

- (void)switchChanged:(UISwitch *)sender {
    while (unity_base_addr == 0) {
        unity_base_addr = get_image_slide_address("UnityFramework");
        usleep(100000);
    }

    switch (sender.tag) {
        case 0: // Antiban mới
            if (sender.on) {
                apply_antiban();
            }
            break;
        case 1: // Hack Map -> Map
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x4A38100, "36 00 80 D2");
            } else {
                PatchOffset(unity_base_addr, 0x4A38100, "9F 03 03 D5");
            }
            break;
        case 2: // Cam Xa 3 Nấc -> Cam xa
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x554B9EC, "20 00 80 52 C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x541142C, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x550E2BC, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
            }
            break;
        case 3: // Show Unit Địch -> Show Unit
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x5F1C394, "20 00 80 52 C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x6A6B798, "20 00 80 52 C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x6A6B8FC, "20 00 80 52 C0 03 5F D6");
            }
            break;
        case 4: // Show Lịch Sử Đấu -> Show LSD
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x5ADF5A8, "20 00 80 52 C0 03 5F D6");
            }
            break;
        case 5: // Ẩn tia -> Ẩn tia
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x5FBEC8C, "20 00 80 52 C0 03 5F D6");
            }
            break;
        default:
            break;
    }
}

- (void)toggleMenu {
    mainBox.hidden = !mainBox.hidden;
}

@end

// Khởi tạo an toàn không bị Watchdog Kill
__attribute__((constructor)) void init_ay_mod() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unity_base_addr = get_image_slide_address("UnityFramework");
        if (unity_base_addr != 0) {
            apply_antiban();
        }
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        menuWindow.windowLevel = UIWindowLevelAlert + 100;
        menuWindow.rootViewController = [[MenuViewController alloc] init];
        menuWindow.hidden = NO;
    });
}
