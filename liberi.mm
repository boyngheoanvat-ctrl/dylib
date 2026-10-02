#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>
#import <libkern/OSCacheControl.h>  // === THÊM FILE ĐẦU ===
#import "fishhook.h"

// === TẮT CẢNH BÁO ===
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-function"

// ==============================================
// BIẾN ĐIỀU KHIỂN MENU
// ==============================================
static BOOL g_Enabled_Map        = NO;
static BOOL g_Enabled_CamXa      = NO;
static BOOL g_Enabled_Unti       = NO;
static BOOL g_Enabled_LSD        = NO;
static BOOL g_Enabled_HideRay    = NO;

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
// MENU OVERLAY
// ==============================================
@interface LiberiMenu : UIViewController
@property (nonatomic, strong) UIStackView *stack;
@end

@implementation LiberiMenu

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.view.layer.cornerRadius = 12;
    self.view.frame = CGRectMake(10, 100, 260, 340);
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 30)];
    title.text = @"🔥 Liberi Control";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:title];
    
    self.stack = [[UIStackView alloc] initWithFrame:CGRectMake(10, 50, 240, 280)];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 12;
    [self.view addSubview:self.stack];
    
    [self addSwitch:@"Map"           value:&g_Enabled_Map];
    [self addSwitch:@"Cam Xa"        value:&g_Enabled_CamXa];
    [self addSwitch:@"Show Unti"     value:&g_Enabled_Unti];
    [self addSwitch:@"Show LSD"      value:&g_Enabled_LSD];
    [self addSwitch:@"Ẩn Tia"        value:&g_Enabled_HideRay];
}

- (void)addSwitch:(NSString*)title value:(BOOL*)value {
    UIView *row = [[UIView alloc] init];
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:15];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = *value;
    [sw addAction:[UIAction actionWithHandler:^(UIAction *act){
        *value = ((UISwitch*)act.sender).isOn;
    }] forControlEvents:UIControlEventValueChanged];
    
    [row addSubview:lbl];
    [row addSubview:sw];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:0],
        [lbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:0],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:40]
    ]];
    [self.stack addArrangedSubview:row];
}

@end

static LiberiMenu *g_menu = nil;

static void ShowMenu(void) {
    if (g_menu) return;
    UIWindow *w = GetKeyWindow();
    if (!w) return;
    g_menu = [[LiberiMenu alloc] init];
    g_menu.view.alpha = 0;
    [w addSubview:g_menu.view];
    [UIView animateWithDuration:0.3 animations:^{ g_menu.view.alpha = 1; }];
}

#pragma clang diagnostic pop

// ==============================================
// PATCH BYTE — SỬA DỌNG XÓA BỘ NHỚ
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
        
        // === SỬA DÒNG NÀY ===
        // Thay __builtin___clear_cache bằng hàm chuẩn Apple
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
    // === anort.framework — Fix Crack LUÔN BẬT ===
    {"anort",   0x31C4C, PATCH_DISABLE, sizeof(PATCH_DISABLE), NULL},
    {"anort",   0x4591C, PATCH_DISABLE, sizeof(PATCH_DISABLE), NULL},
    
    // === UnityFramework — Antiban LUÔN BẬT ===
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
    
    // === Chức năng có Menu BẬT/TẮT ===
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
// QUÉT & ÁP DỤNG PATCH
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
// ẨN DẤU VẾT HỆ THỐNG
// ==============================================
static int (*orig_access)(const char *, int) = NULL;
static int hk_access(const char *p, int m) {
    if (strstr(p, "liberi") || strstr(p, "anort") || strstr(p, "UnityFramework")) {
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
