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
static CGSize g_startSize;
static BOOL g_isResizing = NO;

// ==============================================
// LẤY WINDOW
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
// MENU KIỂU IMGUI — KÉO GIÃN ĐƯỢC
// ==============================================
@interface ImGuiMenuView : UIView
@property (nonatomic, strong) UIView *titleBar;
@property (nonatomic, strong) UIView *resizeHandle;
@property (nonatomic, strong) NSMutableArray *switches;
@property (nonatomic, assign) CGFloat rowHeight;
@end

@implementation ImGuiMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.switches = [NSMutableArray new];
        self.rowHeight = 34.0;
        [self setupImGuiStyleUI];
        [self setupDrag];
        [self setupResize];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *sub in self.subviews) {
        if (CGRectContainsPoint(sub.frame, point)) return YES;
    }
    return NO;
}

- (void)setupImGuiStyleUI {
    self.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:0.92];
    self.layer.borderWidth = 1.5;
    self.layer.borderColor = [UIColor colorWithRed:0.18 green:0.8 blue:0.25 alpha:1].CGColor;
    self.layer.cornerRadius = 0;
    self.frame = CGRectMake(15, 100, 280, 360);
    
    // === Thanh tiêu đề — ĐỔI TÊN ===
    self.titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 34)];
    self.titleBar.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1];
    [self addSubview:self.titleBar];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 7, 220, 20)];
    title.text = @"Mod By Eri Nguyễn"; // ✅ Tên mới
    title.textColor = [UIColor colorWithRed:0.18 green:0.8 blue:0.25 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:13];
    [self.titleBar addSubview:title];
    
    // Nút thu gọn
    UIButton *hideBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hideBtn.frame = CGRectMake(250, 5, 24, 24);
    [hideBtn setTitle:@"−" forState:UIControlStateNormal];
    [hideBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    hideBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    hideBtn.tag = 99;
    [hideBtn addTarget:self action:@selector(onMinimize) forControlEvents:UIControlEventTouchUpInside];
    [self.titleBar addSubview:hideBtn];
    
    // === Các mục công tắc ===
    CGFloat y = 50;
    [self addToggle:@"Bản đồ toàn cảnh"   y:&y val:&g_Enabled_Map        sel:@selector(toggled:)];
    [self addToggle:@"Tầm nhìn xa"        y:&y val:&g_Enabled_CamXa      sel:@selector(toggled:)];
    [self addToggle:@"Hiện kẻ địch"       y:&y val:&g_Enabled_Unti       sel:@selector(toggled:)];
    [self addToggle:@"Hiện tầm bắn"       y:&y val:&g_Enabled_LSD        sel:@selector(toggled:)];
    [self addToggle:@"Ẩn tia chỉ đường"   y:&y val:&g_Enabled_HideRay    sel:@selector(toggled:)];
    
    // Cập nhật chiều cao
    CGRect f = self.frame;
    f.size.height = y + 20;
    self.frame = f;
}

- (void)addToggle:(NSString*)label y:(CGFloat*)y val:(BOOL*)val sel:(SEL)sel {
    const CGFloat padX = 15;
    const CGFloat h = self.rowHeight;
    
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(padX, *y, 280 - padX*2, h)];
    row.backgroundColor = [UIColor clearColor];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 6, 200, 22)];
    lbl.text = label;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13];
    [row addSubview:lbl];
    
    UIButton *toggle = [UIButton buttonWithType:UIButtonTypeCustom];
    toggle.frame = CGRectMake(280 - padX - 28, 4, 28, 26);
    toggle.backgroundColor = *val ? [UIColor colorWithRed:0.18 green:0.8 blue:0.25 alpha:1] : [UIColor colorWithWhite:0.2 alpha:1];
    toggle.layer.borderWidth = 1;
    toggle.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1].CGColor;
    toggle.layer.cornerRadius = 2;
    toggle.tag = (NSInteger)val;
    [toggle setTitle:*val ? @"✓" : @"" forState:UIControlStateNormal];
    [toggle setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    toggle.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [toggle addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:toggle];
    
    [self.switches addObject:@{@"val": [NSValue valueWithPointer:val], @"btn": toggle}];
    [self addSubview:row];
    
    *y += h + 8;
}

// === KÉO DI CHUYỂN ===
- (void)setupDrag {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.titleBar addGestureRecognizer:pan];
}

- (void)handleDrag:(UIPanGestureRecognizer*)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        g_touchStartPos = [g locationInView:self.titleBar];
    } else if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint p = [g locationInView:self.titleBar];
        CGFloat dx = p.x - g_touchStartPos.x;
        CGFloat dy = p.y - g_touchStartPos.y;
        self.center = CGPointMake(self.center.x + dx, self.center.y + dy);
    }
}

// === KÉO GIÃN TO/NHỎ GÓC DƯỚI PHẢI ===
- (void)setupResize {
    self.resizeHandle = [[UIView alloc] initWithFrame:CGRectMake(self.bounds.size.width - 24, self.bounds.size.height - 24, 24, 24)];
    self.resizeHandle.backgroundColor = [UIColor clearColor];
    UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResize:)];
    [self.resizeHandle addGestureRecognizer:resizePan];
    [self addSubview:self.resizeHandle];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.resizeHandle.frame = CGRectMake(self.bounds.size.width - 24, self.bounds.size.height - 24, 24, 24);
}

- (void)handleResize:(UIPanGestureRecognizer*)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        g_startSize = self.bounds.size;
        g_isResizing = YES;
    } else if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint p = [g locationInView:self];
        CGFloat newW = MAX(260, MIN(500, g_startSize.width + (p.x - g_startSize.width)));
        CGFloat newH = MAX(280, MIN(600, g_startSize.height + (p.y - g_startSize.height)));
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, newW, newH);
    } else if (g.state == UIGestureRecognizerStateEnded) {
        g_isResizing = NO;
    }
}

- (void)updateToggleUI:(BOOL*)val {
    for (NSDictionary *item in self.switches) {
        BOOL *ptr = (BOOL*)[item[@"val"] pointerValue];
        if (ptr == val) {
            UIButton *btn = item[@"btn"];
            btn.backgroundColor = *val ? [UIColor colorWithRed:0.18 green:0.8 blue:0.25 alpha:1] : [UIColor colorWithWhite:0.2 alpha:1];
            [btn setTitle:*val ? @"✓" : @"" forState:UIControlStateNormal];
        }
    }
}

- (void)toggled:(UIButton*)sender {
    BOOL *val = (BOOL*)sender.tag;
    *val = !*val;
    [self updateToggleUI:val];
    
    NSLog(@"[ModByEri] Bản đồ: %@", g_Enabled_Map ? @"ON" : @"OFF");
    NSLog(@"[ModByEri] Cam xa: %@", g_Enabled_CamXa ? @"ON" : @"OFF");
    NSLog(@"[ModByEri] Hiện địch: %@", g_Enabled_Unti ? @"ON" : @"OFF");
    NSLog(@"[ModByEri] Tầm bắn: %@", g_Enabled_LSD ? @"ON" : @"OFF");
    NSLog(@"[ModByEri] Ẩn tia: %@", g_Enabled_HideRay ? @"ON" : @"OFF");
}

- (void)onMinimize {
    self.alpha = 0;
    self.hidden = YES;
    if (g_showBtn) { g_showBtn.hidden = NO; g_showBtn.alpha = 1; }
}

@end

// ==============================================
// NÚT HIỆN LẠI
// ==============================================
static void SetupShowButton(void) {
    if (g_showBtn) return;
    UIWindow *w = GetKeyWindow();
    if (!w) return;
    
    g_showBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    g_showBtn.frame = CGRectMake(10, 100, 44, 44);
    g_showBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.8 blue:0.25 alpha:0.8];
    g_showBtn.layer.borderWidth = 1.5;
    g_showBtn.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:1].CGColor;
    g_showBtn.layer.cornerRadius = 2;
    g_showBtn.alpha = 0;
    g_showBtn.hidden = YES;
    [g_showBtn setTitle:@"E" forState:UIControlStateNormal];
    [g_showBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    g_showBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    
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
    
    g_menuView = [[ImGuiMenuView alloc] initWithFrame:CGRectMake(15, 100, 280, 360)];
    g_menuView.alpha = 0;
    g_menuView.layer.zPosition = 999;
    [w addSubview:g_menuView];
    
    [UIView animateWithDuration:0.2 animations:^{ g_menuView.alpha = 1; }];
}

#pragma clang diagnostic pop

// ==============================================
// PATCH BYTE — KIỂM TRA LỖI GHI
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
        
        uintptr_t page = addr & ~(PAGE_SIZE - 1);
        size_t plen = (addr + len - page + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
        
        if (mprotect((void*)page, plen, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
            NSLog(@"[ERROR] mprotect thất bại tại %s 0x%lx -> %d", imageName, rva, errno);
            return NO;
        }
        
        memcpy((void*)addr, bytes, len);
        sys_dcache_flush((void*)addr, len);
        sys_icache_invalidate((void*)addr, len);
        mprotect((void*)page, plen, PROT_READ | PROT_EXEC);
        
        NSLog(@"[PATCH] %s 0x%lx → OK", imageName, rva);
        return YES;
    }
    NSLog(@"[ERROR] Không tìm thấy %s", imageName);
    return NO;
}

// ==============================================
// MÃ MÁY
// ==============================================
static const uint8_t RET[]           = {0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t RET_TRUE[]      = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t RET_FALSE[]     = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t MAP_ON[]        = {0x36, 0x00, 0x80, 0xD2};
static const uint8_t MAP_OFF[]       = {0x00, 0x00, 0x80, 0xD2};
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
    // anort — Tắt bảo vệ
    {"anort",         0x31C4C,  NULL, RET,          4, NULL},
    {"anort",         0x4591C,  NULL, RET,          4, NULL},
    {"anort",         0x2F8B0,  NULL, RET,          4, NULL},
    {"anort",         0x30A84,  NULL, RET,          4, NULL},
    {"anort",         0x32018,  NULL, RET,          4, NULL},
    {"anort",         0x2A6E8,  NULL, RET,          4, NULL},
    {"anort",         0x2B15C,  NULL, RET,          4, NULL},
    
    // UnityFramework — Antiban
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
    
    // Chức năng BẬT/TẮT
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
// CẬP NHẬT PATCH + IN LOG CHI TIẾT
// ==============================================
static void ApplyPatches(void) {
    NSLog(@"[ModByEri] === Bắt đầu Patch ===");
    
    // Patch cố định
    for (int i = 0; g_patches[i].img; i++) {
        if (!g_patches[i].flag && g_patches[i].off) {
            PatchRVA(g_patches[i].img, g_patches[i].rva, g_patches[i].off, g_patches[i].len);
        }
    }
    
    // Patch động mỗi 0.3s
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
// ẨN DẤU VẾT — SỬA TÊN DYLIB → libsupport.dylib
// ==============================================
static int (*orig_access)(const char *, int) = NULL;
static int hk_access(const char *path, int mode) {
    if (!path) return -1;
    if (strstr(path, "libsupport") || strstr(path, ".dylib") ||
        strstr(path, "fishhook") || strstr(path, "theos")) {
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
        
        struct rebinding hooks[] = {{"access", (void*)hk_access, (void**)&orig_access}};
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
