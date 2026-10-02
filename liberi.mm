#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <string.h>
#import <libkern/OSCacheControl.h>
#import "fishhook.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wunused-variable"

// ==============================================
// BIẾN TOÀN CỤC
// ==============================================
static BOOL g_Enabled_Map        = NO;
static BOOL g_Enabled_CamXa      = NO;
static BOOL g_Enabled_Unti       = NO;
static BOOL g_Enabled_LSD        = NO;
static BOOL g_Enabled_HideRay    = NO;

static UIView *g_menuView = nil;
static UIButton *g_showBtn = nil;
static CGPoint g_touchStartPos;

// ==============================================
// LẤY WINDOW — Tương thích mọi iOS
// ==============================================
static UIWindow* GetKeyWindow(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in app.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) return w;
                }
            }
        }
    }
    return app.keyWindow;
}

// ==============================================
// MENU — Kéo di chuyển + Ẩn/Hiện + Không chặn game
// ==============================================
@interface LiberiMenuView : UIView
@property (nonatomic, strong) UIStackView *stack;
@end

@implementation LiberiMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self setupDragGesture];
    }
    return self;
}

// Truyền sự kiện xuống vùng trống → không chặn bấm game
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in self.subviews) {
        if (CGRectContainsPoint(subview.frame, point)) return YES;
    }
    return NO;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    self.layer.cornerRadius = 14;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    self.frame = CGRectMake(10, 120, 260, 340);
    
    // Tiêu đề
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 200, 32)];
    title.text = @"🔥 Liberi Control";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:19];
    [self addSubview:title];
    
    // Nút Ẩn
    UIButton *hideBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hideBtn.frame = CGRectMake(220, 10, 30, 30);
    [hideBtn setTitle:@"−" forState:UIControlStateNormal];
    [hideBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    hideBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    hideBtn.tag = 99;
    [hideBtn addTarget:self action:@selector(onHideTap) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:hideBtn];
    
    // Khối công tắc
    self.stack = [[UIStackView alloc] initWithFrame:CGRectMake(15, 55, 230, 270)];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 20;
    self.stack.alignment = UIStackViewAlignmentFill;
    [self addSubview:self.stack];
    
    [self addSwitchRow:@"Bản đồ toàn cảnh"   value:&g_Enabled_Map        sel:@selector(onMap:)];
    [self addSwitchRow:@"Tầm nhìn xa"        value:&g_Enabled_CamXa      sel:@selector(onCamXa:)];
    [self addSwitchRow:@"Hiện kẻ địch"       value:&g_Enabled_Unti       sel:@selector(onUnti:)];
    [self addSwitchRow:@"Hiện tầm bắn"       value:&g_Enabled_LSD        sel:@selector(onLSD:)];
    [self addSwitchRow:@"Ẩn tia chỉ đường"   value:&g_Enabled_HideRay    sel:@selector(onHideRay:)];
}

- (void)setupDragGesture {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        g_touchStartPos = [gesture locationInView:self];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint now = [gesture locationInView:self];
        CGFloat dx = now.x - g_touchStartPos.x;
        CGFloat dy = now.y - g_touchStartPos.y;
        self.center = CGPointMake(self.center.x + dx, self.center.y + dy);
    }
}

- (void)addSwitchRow:(NSString*)title value:(BOOL*)value sel:(SEL)sel {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 230, 44)];
    
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = *value;
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    [sw addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    
    [row addSubview:lbl];
    [row addSubview:sw];
    
    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [lbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    
    [self.stack addArrangedSubview:row];
}

// Nút Ẩn
- (void)onHideTap {
    self.alpha = 0;
    self.hidden = YES;
    if (g_showBtn) { g_showBtn.hidden = NO; g_showBtn.alpha = 1; }
}

// Bật/Tắt công tắc
- (void)onMap:(UISwitch*)sender     { g_Enabled_Map     = sender.on; NSLog(@"[Liberi] Bản đồ: %@", sender.on ? @"BẬT" : @"TẮT"); }
- (void)onCamXa:(UISwitch*)sender   { g_Enabled_CamXa   = sender.on; NSLog(@"[Liberi] Tầm xa: %@", sender.on ? @"BẬT" : @"TẮT"); }
- (void)onUnti:(UISwitch*)sender    { g_Enabled_Unti    = sender.on; NSLog(@"[Liberi] Hiện địch: %@", sender.on ? @"BẬT" : @"TẮT"); }
- (void)onLSD:(UISwitch*)sender     { g_Enabled_LSD     = sender.on; NSLog(@"[Liberi] Tầm bắn: %@", sender.on ? @"BẬT" : @"TẮT"); }
- (void)onHideRay:(UISwitch*)sender { g_Enabled_HideRay = sender.on; NSLog(@"[Liberi] Ẩn tia: %@", sender.on ? @"BẬT" : @"TẮT"); }

@end

// ==============================================
// NÚT HIỆN LẠI — Ở riêng, không bị ẩn theo menu
// ==============================================
static void SetupShowButton(void) {
    if (g_showBtn) return;
    UIWindow *w = GetKeyWindow();
    if (!w) return;
    
    g_showBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    g_showBtn.frame = CGRectMake(10, 100, 50, 50);
    [g_showBtn setTitle:@"🔥" forState:UIControlStateNormal];
    g_showBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    g_showBtn.layer.cornerRadius = 12;
    g_showBtn.alpha = 0;
    g_showBtn.hidden = YES;
    
    [g_showBtn addAction:[UIAction actionWithHandler:^(UIAction *_) {
        if (g_menuView) {
            g_menuView.hidden = NO;
            g_menuView.alpha = 1;
            g_showBtn.hidden = YES;
        }
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [w addSubview:g_showBtn];
}

// ==============================================
// HIỂN THỊ MENU
// ==============================================
static void ShowMenu(void) {
    if (g_menuView) return;
    UIWindow *w = GetKeyWindow();
    if (!w) return;
    
    g_menuView = [[LiberiMenuView alloc] initWithFrame:CGRectMake(10, 120, 260, 340)];
    g_menuView.alpha = 0;
    g_menuView.layer.zPosition = 999;
    [w addSubview:g_menuView];
    
    [UIView animateWithDuration:0.3 animations:^{ g_menuView.alpha = 1; }];
}

#pragma clang diagnostic pop

// ==============================================
// PATCH BYTE — Ghi trực tiếp vào bộ nhớ
// ==============================================
#include <sys/mman.h>

static BOOL PatchRVA(const char *imageName, uintptr_t rva, const void *bytes, size_t len) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header_64 *hdr = (const struct mach_header_64*)_dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        if (!hdr || !name || strstr(name, imageName) == NULL) continue;
        
        uintptr_t slide = _dyld_get_image_vmaddr_slide(i);
        uintptr_t addr = (uintptr_t)hdr + slide + rva;
        
        uintptr_t page_start = addr & ~(PAGE_SIZE - 1);
        size_t page_len = (addr + len - page_start + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
        
        if (mprotect((void*)page_start, page_len, PROT_READ | PROT_WRITE | PROT_EXEC) != 0)
            return NO;
        
        memcpy((void*)addr, bytes, len);
        sys_dcache_flush((void*)addr, len);
        sys_icache_invalidate((void*)addr, len);
        mprotect((void*)page_start, page_len, PROT_READ | PROT_EXEC);
        return YES;
    }
    return NO;
}

// ==============================================
// MÃ MÁY — PATCH
// ==============================================
static const uint8_t RET[]           = {0xC0, 0x03, 0x5F, 0xD6};  // ret
static const uint8_t RET_TRUE[]      = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};  // mov w0, #1; ret
static const uint8_t RET_FALSE[]     = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};  // mov w0, #0; ret
static const uint8_t MAP_ON[]        = {0x36, 0x00, 0x80, 0xD2};  // mov x6, #...
static const uint8_t MAP_OFF[]       = {0x00, 0x00, 0x80, 0xD2};  // mov x0, #0
static const uint8_t CAM_DIST_ON[]   = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t CAM_DIST_OFF[]  = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};

struct PatchEntry {
    const char *img;
    uintptr_t rva;
    const uint8_t *on;
    const uint8_t *off;
    size_t len;
    BOOL *flag;
};

static const struct PatchEntry g_patches[] = {
    // ==============================================
    // anort.framework/anort — Tắt bảo vệ, chống phát hiện
    // ==============================================
    {"anort",         0x31C4C,  NULL, RET,          4, NULL},  // Tắt kiểm tra debug
    {"anort",         0x4591C,  NULL, RET,          4, NULL},  // Tắt kiểm tra chữ ký
    {"anort",         0x2F8B0,  NULL, RET,          4, NULL},  // Tắt bảo vệ mã
    {"anort",         0x30A84,  NULL, RET,          4, NULL},  // Tắt tích hợp
    {"anort",         0x32018,  NULL, RET,          4, NULL},  // Tắt chống sửa đổi
    {"anort",         0x2A6E8,  NULL, RET,          4, NULL},  // Tắt kiểm tra kết nối
    {"anort",         0x2B15C,  NULL, RET,          4, NULL},  // Tắt heartbeat
    
    // ==============================================
    // UnityFramework.framework/UnityFramework — Antiban luôn áp dụng
    // ==============================================
    {"UnityFramework", 0x706D890, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706D914, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706D9CC, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706DAB0, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706DD14, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706E0A0, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706E21C, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706E304, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706E6BC, NULL, RET,         4, NULL},
    {"UnityFramework", 0x706E754, NULL, RET,         4, NULL},
    {"UnityFramework", 0x677FA8C, NULL, RET,         4, NULL},
    {"UnityFramework", 0x0546B08, NULL, RET,         4, NULL},
    {"UnityFramework", 0x083B634, NULL, RET,         4, NULL},
    {"UnityFramework", 0x05B61A0, NULL, RET,         4, NULL},
    {"UnityFramework", 0x05B6380, NULL, RET,         4, NULL},
    {"UnityFramework", 0x05B65CC, NULL, RET,         4, NULL},
    {"UnityFramework", 0x05B6764, NULL, RET,         4, NULL},
    
    // ==============================================
    // Chức năng BẬT/TẮT ĐỘNG
    // ==============================================
    {"UnityFramework", 0x4A38100, MAP_ON,       MAP_OFF,       4,  &g_Enabled_Map},
    {"UnityFramework", 0x554B9EC, CAM_DIST_ON,  CAM_DIST_OFF,  8,  &g_Enabled_CamXa},
    {"UnityFramework", 0x541142C, CAM_DIST_ON,  CAM_DIST_OFF, 12,  &g_Enabled_CamXa},
    {"UnityFramework", 0x550E2BC, CAM_DIST_ON,  CAM_DIST_OFF, 12,  &g_Enabled_CamXa},
    {"UnityFramework", 0x5F1C394, RET_TRUE,     RET_FALSE,     8,  &g_Enabled_Unti},
    {"UnityFramework", 0x6A6B798, RET_TRUE,     RET_FALSE,     8,  &g_Enabled_Unti},
    {"UnityFramework", 0x6A6B8FC, RET_TRUE,     RET_FALSE,     8,  &g_Enabled_Unti},
    {"UnityFramework", 0x5ADF5A8, RET_TRUE,     RET_FALSE,     8,  &g_Enabled_LSD},
    {"UnityFramework", 0x5FBEC8C, RET_TRUE,     RET_FALSE,     8,  &g_Enabled_HideRay},
    
    {NULL, 0, NULL, NULL, 0, NULL}
};

// ==============================================
// CẬP NHẬT PATCH MỖI 0.3 GIÂY
// ==============================================
static void ApplyPatches(void) {
    // Patch cố định — chạy 1 lần
    for (int i = 0; g_patches[i].img; i++) {
        if (!g_patches[i].flag && g_patches[i].off) {
            PatchRVA(g_patches[i].img, g_patches[i].rva, g_patches[i].off, g_patches[i].len);
        }
    }
    
    // Patch động — kiểm tra và cập nhật liên tục
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *t){
            for (int i = 0; g_patches[i].img; i++) {
                if (!g_patches[i].flag || !g_patches[i].on) continue;
                
                if (*g_patches[i].flag) {
                    PatchRVA(g_patches[i].img, g_patches[i].rva, g_patches[i].on, g_patches[i].len);
                } else {
                    PatchRVA(g_patches[i].img, g_patches[i].rva, g_patches[i].off, g_patches[i].len);
                }
            }
        }];
    });
}

// ==============================================
// ẨN DẤU VẾT — Ngăn game phát hiện dylib
// ==============================================
static int (*orig_access)(const char *, int) = NULL;
static int hk_access(const char *path, int mode) {
    if (!path) return -1;
    if (strstr(path, "liberi") || strstr(path, ".dylib") ||
        strstr(path, "fishhook") || strstr(path, "libsupport") ||
        strstr(path, "wukong.framework")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(path, mode);
}

// ==============================================
// KHỞI ĐỘNG
// ==============================================
__attribute__((constructor(101)))
static void AutoStart(void) {
    @autoreleasepool {
        unsetenv("DYLD_INSERT_LIBRARIES");
        unsetenv("DYLD_LIBRARY_PATH");
        unsetenv("DYLD_FALLBACK_LIBRARY_PATH");
        
        struct rebinding hooks[] = {
            {"access", (void*)hk_access, (void**)&orig_access},
        };
        rebind_symbols(hooks, 1);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SetupShowButton();
            ApplyPatches();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                ShowMenu();
            });
        });
    }
}
