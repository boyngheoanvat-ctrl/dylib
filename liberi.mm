#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h> // Thêm header hỗ trợ clear cache chuẩn trên iOS

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
    
    // Sử dụng hàm chuẩn của iOS để clear cache instruction thay cho builtin cũ
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
    while (unity_base_addr == 0) {
        unity_base_addr = get_image_slide_address("UnityFramework");
        usleep(300000);
    }

    const char* ret8 = "00 00 80 D2 C0 03 5F D6";
    uint64_t p1_offsets[] = {
        0x5CD0C04, 0x6A60228, 0x6A69CAC, 0x6A69D9C, 0x6AEB808,
        0x6DBC0B0, 0x6DBC0B4, 0x6DBC294, 0x6DBC298, 0x6DC59DC,
        0x6DCB8E8, 0x6E01E60, 0x705DB3C, 0x705DB38, 0x706D94C,
        0x706E30C, 0x706D9CC, 0x706E938, 0x70985BC, 0x7098624,
        0x7182C4C, 0x7182C50, 0x7182C54, 0x718370C, 0x71837B4,
        0x71838D4, 0x7267A24, 0x72D0C2C, 0x72D0C30, 0x5221798,
        0x5221818, 0x5221918, 0x5221998, 0x5221A18, 0x556CBD8,
        0x556CEA8, 0x556CFD4, 0x5682E38, 0x6179804, 0x6179A6C,
        0x6179C04, 0x6179DCC, 0x6179FAC, 0x617A270, 0x617A430,
        0x6230268, 0x6238C30, 0x62643FC, 0x627B2FC, 0x627C97C,
        0x6339604, 0x6460F74, 0x646A470, 0x6469AF0, 0x68FDBA4,
        0x69E2C0C, 0x4096CB0, 0x4384A98, 0x4386594, 0x43F1C5C,
        0x440F8E4, 0x4410D50, 0x5162A4,  0x5162FC,  0x5295F4,
        0x52964C, 0xB86780,  0xB86808,  0x3D60BA0, 0x3D69418,
        0x3F74DBC, 0x3F76240, 0x3F82444, 0x3DBDAC4, 0x3DC47FC,
        0x3DD3BB8, 0x3DE7260, 0x3DE75A8, 0x3E03488, 0x3E098B4,
        0x3E567D4, 0x3E586F0, 0x3E587F8, 0x3E58CB4, 0x3E5CC8C,
        0xF02F68,  0xF02FC4,  0xF03108,  0xF031B8,  0xF032B8,
        0xF03614,  0xF037F0,  0xF03BA0,  0xF03E74,  0xF03B3C,
        0xEF453C,  0xF06610,  0xF29E98,  0xE88420,  0xE88508,
        0xE885C0,  0xE89224,  0x74F80D4, 0x74FA6D8, 0x74FD2D0,
        0x74FD3A8, 0x74FEEB0, 0x7502784, 0x74FF808, 0x7502AB0,
        0x7502EA4, 0x7503400, 0x74FA46C, 0x750975C, 0x750A1EC,
        0x7509CE4, 0x76BCC3C, 0x76587A8, 0x76572D4, 0x765CC78,
        0x7661474, 0x7657494, 0x76FA234, 0x76FBE18, 0x7707DC8,
        0x7709690, 0x7713634, 0x77137A4, 0x774852C, 0x7749650,
        0x77539A0, 0x77539B0, 0x774EEC8, 0x774ED98, 0x774F7E0,
        0x774F8B0, 0x7751788, 0x77523C8, 0x775F87C, 0x7760498,
        0x77604B8, 0x7790770, 0x78A1CC0, 0x78A1D00, 0x3D1851C,
        0x3D185A4, 0x3D185AC, 0x3D2EA34, 0x3D30D00, 0x3D31D40,
        0x3D33F4C, 0x3D33F54, 0x3D3E37C, 0x3D3E384, 0x3A03224,
        0x3A16458, 0x3A1A948, 0xFB3820,  0x7871F5C, 0x7871FB8,
        0x78721B0, 0x78723A8, 0x78727C8, 0x7872D38, 0x16EC2C0,
        0x7876684, 0x78768B0, 0x111DB70, 0x7947C84, 0x794A95C,
        0x79499AC, 0x794BB00, 0x794AC58
    };
    for (size_t i = 0; i < sizeof(p1_offsets) / sizeof(p1_offsets[0]); i++) {
        PatchOffset(unity_base_addr, p1_offsets[i], ret8);
    }

    const char* ret4 = "C0 03 5F D6";
    uint64_t p2_offsets[] = {
        0x6A975D8, 0x6262450, 0x4E2DBBC, 0x8D2830,  0x8D28B8,
        0x3DBDAC4, 0x378D94,  0x378D9C,  0x7D58360, 0x74FF808,
        0x7502AB0, 0x76572D4, 0x765CC78, 0x7661474, 0x774EEC8,
        0x775A310, 0x7790E40, 0x3D3E37C, 0x72AE46C, 0x735B4AC,
        0x5B4A54C, 0xB9AE00
    };
    for (size_t j = 0; j < sizeof(p2_offsets) / sizeof(p2_offsets[0]); j++) {
        PatchOffset(unity_base_addr, p2_offsets[j], ret4);
    }
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

__attribute__((constructor)) void init_ay_mod() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        apply_antiban();
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        menuWindow.windowLevel = UIWindowLevelAlert + 100;
        menuWindow.rootViewController = [[MenuViewController alloc] init];
        menuWindow.hidden = NO;
    });
}
