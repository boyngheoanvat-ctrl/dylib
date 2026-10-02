#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>

static UIWindow *menuWindow = nil;
static uintptr_t unity_base_addr = 0;

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

bool RawCodePatch(uintptr_t absolute_address, const void* patch_bytes, size_t length) {
    if (absolute_address == 0 || patch_bytes == NULL) return false;

    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t page_start = (absolute_address & ~(page_size - 1));

    if (mprotect((void*)page_start, page_size, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        return false;
    }

    memcpy((void*)absolute_address, patch_bytes, length);

    mprotect((void*)page_start, page_size, PROT_READ | PROT_EXEC);
    sys_cache_control(kCacheFunctionPrepareForExecution, (void*)absolute_address, length);
    return true;
}

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

void PatchOffset(uintptr_t base_addr, uint64_t offset, const char* hex_bytes) {
    if (base_addr == 0) return;
    uintptr_t target_addr = base_addr + offset;
    
    unsigned char bytes[256];
    size_t len = 0;
    parseHexBytes(hex_bytes, bytes, &len);
    if (len == 0) return;
    
    RawCodePatch(target_addr, bytes, len);
}

void apply_antiban() {
    // Tạm thời để trống hàm này để kiểm tra xem game còn bị văng hay không
}

@interface MenuViewController : UIViewController
@end

@implementation MenuViewController {
    UIView *mainBox;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    mainBox = [[UIView alloc] initWithFrame:CGRectMake(50, 50, 260, 320)];
    mainBox.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.9f];
    mainBox.layer.cornerRadius = 12;
    mainBox.layer.borderWidth = 1.5f;
    mainBox.layer.borderColor = [UIColor cyanColor].CGColor;
    [self.view addSubview:mainBox];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 30)];
    titleLabel.text = @"MOD BY ERI NGUYỄN";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [mainBox addSubview:titleLabel];

    NSArray *features = @[@"1. Hack Map", @"2. Cam Xa 3 Nấc", @"3. Show Unit Địch", @"4. Show Lịch Sử Đấu", @"5. Ẩn Tia"];
    for (int i = 0; i < features.count; i++) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 55 + (i * 45), 160, 30)];
        lbl.text = features[i];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:13];
        [mainBox addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(190, 55 + (i * 45), 0, 0)];
        sw.tag = i + 1;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [mainBox addSubview:sw];
    }

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(210, 10, 40, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(toggleMenuMinimize) forControlEvents:UIControlEventTouchUpInside];
    [mainBox addSubview:closeBtn];

    UIButton *floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatBtn.frame = CGRectMake(20, 100, 50, 50);
    floatBtn.backgroundColor = [UIColor cyanColor];
    [floatBtn setTitle:@"MOD" forState:UIControlStateNormal];
    [floatBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    floatBtn.layer.cornerRadius = 25;
    [floatBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:floatBtn];
}

- (void)switchChanged:(UISwitch *)sender {
    if (unity_base_addr == 0) {
        unity_base_addr = get_image_slide_address("UnityFramework");
    }
    if (unity_base_addr == 0) return;

    switch (sender.tag) {
        case 1:
            if (sender.on) PatchOffset(unity_base_addr, 0x4A38100, "36 00 80 D2");
            break;
        case 2:
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x554B9EC, "20 00 80 52 C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x541142C, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x550E2BC, "00 00 A8 52 00 00 27 1E C0 03 5F D6");
            }
            break;
        case 3:
            if (sender.on) {
                PatchOffset(unity_base_addr, 0x5F1C394, "20 00 80 52 C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x6A6B798, "20 00 80 52 C0 03 5F D6");
                PatchOffset(unity_base_addr, 0x6A6B8FC, "20 00 80 52 C0 03 5F D6");
            }
            break;
        case 4:
            if (sender.on) PatchOffset(unity_base_addr, 0x5ADF5A8, "20 00 80 52 C0 03 5F D6");
            break;
        case 5:
            if (sender.on) PatchOffset(unity_base_addr, 0x5FBEC8C, "20 00 80 52 C0 03 5F D6");
            break;
        default:
            break;
    }
}

- (void)toggleMenu {
    mainBox.hidden = !mainBox.hidden;
}

- (void)toggleMenuMinimize {
    mainBox.hidden = YES;
}

@end

static void AppDidFinishLaunching(NSNotification *note) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!menuWindow) {
            menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            menuWindow.windowLevel = UIWindowLevelAlert + 100;
            menuWindow.rootViewController = [[MenuViewController alloc] init];
            menuWindow.hidden = NO;
        }
    });
}

__attribute__((constructor)) void init_ay_mod() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        AppDidFinishLaunching(note);
    }];
}
