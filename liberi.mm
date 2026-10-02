#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>
#import <libkern/OSCacheControl.h>
#import "fishhook.h"

// === TẮT CẢNH BÁO ===
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-function"

// ==============================================
// BIẾN TOÀN CỤC
// ==============================================
static BOOL g_Enabled_Map        = NO;
static BOOL g_Enabled_CamXa      = NO;
static BOOL g_Enabled_Unti       = NO;
static BOOL g_Enabled_LSD        = NO;
static BOOL g_Enabled_HideRay    = NO;

static UIView *g_menuView = nil;
static UIButton *g_toggleBtn = nil;
static BOOL g_menuVisible = YES;
static CGPoint g_touchStartPos;

// ==============================================
// LẤY WINDOW — TƯƠNG THÍCH MỌI iOS
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
// MENU — HỖ TRỢ KÉO DI CHUYỂN + KHÔNG CHẶN GAME
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

// === Truyền sự kiện xuống vùng trống → không chặn bấm game ===
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in self.subviews) {
        if (CGRectContainsPoint(subview.frame, point)) {
            return YES;
        }
    }
    return NO;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    self.layer.cornerRadius = 14;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    
    // Tiêu đề
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 230, 32)];
    title.text = @"🔥 Liberi Control";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:19];
    title.textAlignment = NSTextAlignmentCenter;
    [self addSubview:title];
    
    // Nút ẩn/hiện tích hợp vào góc tiêu đề
    UIButton *hideBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hideBtn.frame = CGRectMake(225, 10, 30, 30);
    [hideBtn setTitle:@"−" forState:UIControlStateNormal];
    [hideBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    hideBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    hideBtn.tag = 99;
    [hideBtn addTarget:self action:@selector(onHideTap) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:hideBtn];
    
    // Nút hiện nhỏ (ẩn ban đầu)
    UIButton *showBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    showBtn.frame = CGRectMake(10, 100, 44, 44);
    [showBtn setTitle:@"🔥" forState:UIControlStateNormal];
    showBtn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    showBtn.layer.cornerRadius = 10;
    showBtn.tag = 98;
    showBtn.alpha = 0;
    showBtn.hidden = YES;
    [showBtn addTarget:self action:@selector(onShowTap) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:showBtn];
    
    // Khối công tắc
    self.stack = [[UIStackView alloc] initWithFrame:CGRectMake(15, 52, 230, 280)];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 14;
    [self addSubview:self.stack];
    
    [self addSwitchRow:@"Bản đồ toàn cảnh"   value:&g_Enabled_Map        sel:@selector(onMap:)];
    [self addSwitchRow:@"Tầm nhìn xa"        value:&g_Enabled_CamXa      sel:@selector(onCamXa:)];
    [self addSwitchRow:@"Hiện kẻ địch"       value:&g_Enabled_Unti       sel:@selector(onUnti:)];
    [self addSwitchRow:@"Hiện tầm bắn"       value:&g_Enabled_LSD        sel:@selector(onLSD:)];
    [self addSwitchRow:@"Ẩn tia chỉ đường"   value:&g_Enabled_HideRay    sel:@selector(onHideRay:)];
}

- (void)setupDragGesture {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.minimumNumberOfTouches = 1;
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
    lbl.font = [UIFont systemFontOfSize:15];
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

// === Nút ẩn/hiện ===
- (void)onHideTap {
    g_menuVisible = NO;
    UIButton *showBtn = [self viewWithTag:98];
    UIButton *hideBtn = [self viewWithTag:99];
    showBtn.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0;
        hideBtn.alpha = 0;
        showBtn.alpha = 1;
    }];
}

- (void)onShowTap {
    g_menuVisible = YES;
    UIButton *showBtn = [self viewWithTag:98];
    UIButton *hideBtn = [self viewWithTag:99];
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 1;
        hideBtn.alpha = 1;
        showBtn.alpha = 0;
    } completion:^(BOOL f) {
        showBtn.hidden = YES;
    }];
}

// === Xử lý bật/tắt ===
- (void)onMap:(UISwitch*)sender     { g_Enabled_Map     = sender.on; }
- (void)onCamXa:(UISwitch*)sender   { g_Enabled_CamXa   = sender.on; }
- (void)onUnti:(UISwitch*)sender    { g_Enabled_Unti    = sender.on; }
- (void)onLSD:(UISwitch*)sender     { g_Enabled_LSD     = sender.on; }
- (void)onHideRay:(UISwitch*)sender { g_Enabled_HideRay = sender.on; }

@end

// ==============================================
// HIỂN THỊ MENU
// ==============================================
static void ShowMenu(void) {
    if (g_menuView) return;
    UIWindow *w = GetKeyWindow();
    if (!w) return;
    
    g_menuView = [[LiberiMenuView alloc] initWithFrame:CGRectMake(10, 120, 260, 350)];
    g_menuView.alpha = 0;
    g_menuView.layer.zPosition = 999;
    [w addSubview:g_menuView];
    
    [UIView animateWithDuration:0.3 animations:^{
        g_menuView.alpha = 1;
    }];
}

#pragma clang diagnostic pop

// ==============================================
// PATCH BYTE
// ==============================================
#include <sys/mman.h>

static BOOL PatchRVA(const char *imageName, uintptr_t rva, const void *bytes, size_t len) {
    uint32_t c = _dyld_image_count();
    for (uint32_t i = 0; i < c; i++) {
        const struct mach_header_64 *hdr = (const struct mach_header_64*)_dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        if (!hdr || !name || strstr(name, imageName) == NULL) continue;
        
        uintptr_t base = (uintptr_t)hdr + _dyld_get_image_vmaddr_slide(i);
        uintptr_t addr = base + rva;
        
        uintptr_t page = addr & ~(PAGE_SIZE - 1);
        size_t plen = (addr + len - page + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
        if (mprotect((void*)page, plen, PROT_READ | PROT_WRITE | PROT_EXEC) != 0)
            return NO;
        
        memcpy((void*)addr, bytes, len);
        sys_dcache_flush((void*)addr, len);
        sys_icache_invalidate((void*)addr, len);
        mprotect((void*)page, plen, PROT_READ | PROT_EXEC);
        return YES;
    }
    return NO;
}

// ==============================================
// DỮ LIỆU PATCH
// ==============================================
static const uint8_t PATCH_RET[]       = {0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t PATCH_DISABLE[]   = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t PATCH_MAP[]       = {0x36, 0x00, 0x80, 0xD2};
static const uint8_t PATCH_BOOL_RET[]  = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t PATCH_CAM1[]      = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t PATCH_CAM2[]      = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};

struct AutoPatch {
    const char *img;
    uintptr_t rva;
    const uint8_t *data;
    size_t len;
    BOOL *toggle;
};

static const struct AutoPatch g_patches[] = {
    // === anort.framework — Luôn bật ===
    {"anort",   0x31C4C, PATCH_DISABLE, sizeof(PATCH_DISABLE), NULL},
    {"anort",   0x4591C, PATCH_DISABLE, sizeof(PATCH_DISABLE), NULL},
    
    // === UnityFramework — Antiban ===
    {"UnityFramework", 0x706D890, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706D914, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706D9CC, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706DAB0, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706DD14, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706E0A0, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706E21C, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706E304, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706E6BC, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x706E754, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x677FA8C, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x0546B08, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x083B634, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x05B61A0, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x05B6380, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x05B65CC, PATCH_RET, sizeof(PATCH_RET), NULL},
    {"UnityFramework", 0x05B6764, PATCH_RET, sizeof(PATCH_RET), NULL},
    
    // === Chức năng có bật/tắt ===
    {"UnityFramework", 0x4A38100, PATCH_MAP,       sizeof(PATCH_MAP),       &g_Enabled_Map},
    {"UnityFramework", 0x554B9EC, PATCH_CAM1,      sizeof(PATCH_CAM1),      &g_Enabled_CamXa},
    {"UnityFramework", 0x541142C, PATCH_CAM2,      sizeof(PATCH_CAM2),      &g_Enabled_CamXa},
    {"UnityFramework", 0x550E2BC, PATCH_CAM2,      sizeof(PATCH_CAM2),      &g_Enabled_CamXa},
    {"UnityFramework", 0x5F1C394, PATCH_BOOL_RET,  sizeof(PATCH_BOOL_RET),  &g_Enabled_Unti},
    {"UnityFramework", 0x6A6B798, PATCH_BOOL_RET,  sizeof(PATCH_BOOL_RET),  &g_Enabled_Unti},
    {"UnityFramework", 0x6A6B8FC, PATCH_BOOL_RET,  sizeof(PATCH_BOOL_RET),  &g_Enabled_Unti},
    {"UnityFramework", 0x5ADF5A8, PATCH_BOOL_RET,  sizeof(PATCH_BOOL_RET),  &g_Enabled_LSD},
    {"UnityFramework", 0x5FBEC8C, PATCH_BOOL_RET,  sizeof(PATCH_BOOL_RET),  &g_Enabled_HideRay},
    
    {NULL, 0, NULL, 0, NULL}
};

// ==============================================
// ÁP DỤNG PATCH THEO TRẠNG THÁI
// ==============================================
static void ApplyPatches(void) {
    for (int i = 0; g_patches[i].img; i++) {
        if (!g_patches[i].toggle) {
            PatchRVA(g_patches[i].img, g_patches[i].rva,
                     g_patches[i].data, g_patches[i].len);
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *t){
            for (int i = 0; g_patches[i].img; i++) {
                if (!g_patches[i].toggle) continue;
                if (*g_patches[i].toggle) {
                    PatchRVA(g_patches[i].img, g_patches[i].rva,
                             g_patches[i].data, g_patches[i].len);
                }
            }
        }];
    });
}

// ==============================================
// ẨN DẤU VẾT
// ==============================================
static int (*orig_access)(const char *, int) = NULL;
static int hk_access(const char *p, int m) {
    if (!p) return -1;
    if (strstr(p, "liberi") || strstr(p, ".dylib") || 
        strstr(p, "fishhook") || strstr(p, "wukong.framework/libsupport")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(p, m);
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
        
        struct rebinding sysHooks[] = {
            {"access", (void*)hk_access, (void**)&orig_access},
        };
        rebind_symbols(sysHooks, 1);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ApplyPatches();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                ShowMenu();
            });
        });
    }
}
