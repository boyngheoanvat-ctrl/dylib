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

// Controller quản lý các nút tròn nổi
@interface FloatingMenuController : UIViewController
@end

@implementation FloatingMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    // Danh sách các tính năng hiển thị dạng nút tròn giống ảnh mẫu
    NSArray *titles = @[@"AntiBan", @"Bản đồ", @"Cam Xa", @"Show Unti", @"Show LSD", @"An Tia"];
    
    CGFloat startX = 100;
    CGFloat startY = 50;
    CGFloat spacingX = 75;
    CGFloat spacingY = 75;
    
    for (int i = 0; i < titles.count; i++) {
        int row = i / 3;
        int col = i % 3;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(startX + (col * spacingX), startY + (row * spacingY), 60, 60);
        
        // Màu nền xanh dương mặc định, bo tròn hoàn toàn
        btn.backgroundColor = [UIColor colorWithRed:0.0f/255.0f green:122.0f/255.0f blue:255.0f/255.0f alpha:0.85f];
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        btn.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        btn.layer.cornerRadius = 30;
        btn.layer.borderWidth = 1.5f;
        btn.layer.borderColor = [UIColor cyanColor].CGColor;
        btn.tag = i + 1;
        
        // Thêm sự kiện bấm nút
        [btn addTarget:self action:@selector(featureButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        // Thêm cử chỉ kéo thả (Pan Gesture) để tùy ý di chuyển nút trên màn hình
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [btn addGestureRecognizer:pan];
        
        [self.view addSubview:btn];
    }
}

// Hàm hỗ trợ kéo thả từng nút đi bất cứ đâu trên màn hình
- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    UIView *btn = recognizer.view;
    CGPoint translation = [recognizer translationInView:self.view];
    btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:self.view];
}

- (void)featureButtonTapped:(UIButton *)sender {
    if (unity_base_addr == 0) {
        unity_base_addr = get_image_slide_address("UnityFramework");
    }
    
    // Đổi màu trạng thái: Bật = Đỏ, Tắt = Xanh dương
    BOOL isOn = sender.selected = !sender.selected;
    if (isOn) {
        sender.backgroundColor = [UIColor colorWithRed:255.0f/255.0f green:59.0f/255.0f blue:48.0f/255.0f alpha:0.85f];
    } else {
        sender.backgroundColor = [UIColor colorWithRed:0.0f/255.0f green:122.0f/255.0f blue:255.0f/255.0f alpha:0.85f];
    }
    
    if (unity_base_addr == 0) return;
    
    // Thực thi patch theo từng tính năng
    switch (sender.tag) {
        case 1: // AntiBan
            break;
        case 2: // Bản đồ
            if (isOn) PatchOffset(unity_base_addr, 0x4A38100, "36 00 80 D2");
            break;
        case 3: // Cam Xa
            if (isOn) PatchOffset(unity_base_addr, 0x554B9EC, "20 00 80 52 C0 03 5F D6");
            break;
        case 4: // Show Unti
            if (isOn) PatchOffset(unity_base_addr, 0x5F1C394, "20 00 80 52 C0 03 5F D6");
            break;
        case 5: // Show LSD
            if (isOn) PatchOffset(unity_base_addr, 0x5ADF5A8, "20 00 80 52 C0 03 5F D6");
            break;
        case 6: // An Tia
            if (isOn) PatchOffset(unity_base_addr, 0x5FBEC8C, "20 00 80 52 C0 03 5F D6");
            break;
        default:
            break;
    }
}

@end

// Cửa sổ thông minh cho phép chạm xuyên qua khoảng trống để chơi game bình thường
@interface PassthroughWindow : UIWindow
@end

@implementation PassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil; // Cho phép chạm xuyên qua game ở vùng trống
    }
    return hitView; // Chỉ nhận chạm khi bấm trực tiếp vào các nút tròn
}
@end

static void AppDidFinishLaunching(NSNotification *note) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!menuWindow) {
            menuWindow = [[PassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            menuWindow.windowLevel = UIWindowLevelAlert + 100;
            menuWindow.rootViewController = [[FloatingMenuController alloc] init];
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
