#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "fishhook.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/mman.h>

// ==============================================
// BIẾN ĐIỀU KHIỂN
// ==============================================
static BOOL g_Enabled_Map        = NO;
static BOOL g_Enabled_CamXa      = NO;
static BOOL g_Enabled_Unti       = NO;
static BOOL g_Enabled_LichSu     = NO;
static BOOL g_Enabled_ElsuTia    = NO;

static UIWindow *g_menuWindow = nil;
static UIButton *g_toggleBtn = nil;
static BOOL g_menuMinimized = NO;

// ==============================================
// BYTE PATTERN
// ==============================================
static const uint8_t ANORT_FIX[]    = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t RET_INST[]     = {0xC0, 0x03, 0x5F, 0xD6};

static const uint8_t MAP_ON[]       = {0x36, 0x00, 0x80, 0xD2};
static const uint8_t MAP_OFF[]      = {0x00, 0x00, 0x80, 0xD2};

static const uint8_t CAM_ON[]       = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t CAM_OFF[]      = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};

static const uint8_t SHOW_ON[]      = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t SHOW_OFF[]     = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};

struct PatchEntry {
    const char *img;
    uintptr_t rva;
    const uint8_t *on;
    const uint8_t *off;
    size_t len;
    BOOL *flag;
};

// ==============================================
// DANH SÁCH PATCH — ĐÚNG FILE + ĐÚNG ĐỊA CHỈ
// ==============================================
static const struct PatchEntry g_patches[] = {
    // ========== FILE: anort (hình 1) ==========
    {"anort",           0x31C4C,    ANORT_FIX,      NULL,       8,      NULL},
    {"anort",           0x4591C,    ANORT_FIX,      NULL,       8,      NULL},

    // ========== FILE: UnityFramework (hình 2) ==========
    {"UnityFramework",  0x706D890,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706D914,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706D9CC,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706DAB0,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706DD14,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706E0A0,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706E21C,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706E304,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706E6BC,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x706E754,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x677FA8C,  RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x546B08,   RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x83B634,   RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x5B61A0,   RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x5B6380,   RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x5B65CC,   RET_INST,       NULL,       4,      NULL},
    {"UnityFramework",  0x5B6764,   RET_INST,       NULL,       4,      NULL},

    // 1. Hack Map
    {"UnityFramework",  0x4A38100,  MAP_ON,         MAP_OFF,    4,      &g_Enabled_Map},
    // 2. Cam Xa 3 Nất
    {"UnityFramework",  0x554B9EC,  CAM_ON,         CAM_OFF,    8,      &g_Enabled_CamXa},
    {"UnityFramework",  0x541142C,  CAM_ON,         CAM_OFF,    12,     &g_Enabled_CamXa},
    {"UnityFramework",  0x550E2BC,  CAM_ON,         CAM_OFF,    12,     &g_Enabled_CamXa},
    // 3. Show Unti Địch
    {"UnityFramework",  0x5F1C394,  SHOW_ON,        SHOW_OFF,   8,      &g_Enabled_Unti},
    {"UnityFramework",  0x6A6B798,  SHOW_ON,        SHOW_OFF,   8,      &g_Enabled_Unti},
    {"UnityFramework",  0x6A6B8FC,  SHOW_ON,        SHOW_OFF,   8,      &g_Enabled_Unti},
    // 4. Show Lịch Sử Đấu
    {"UnityFramework",  0x5ADF5A8,  SHOW_ON,        SHOW_OFF,   8,      &g_Enabled_LichSu},
    // 5. Ẩn Tia Elsu
    {"UnityFramework",  0x5FBEC8C,  SHOW_OFF,       SHOW_ON,    8,      &g_Enabled_ElsuTia},

    {NULL, 0, NULL, NULL, 0, NULL}
};

// ==============================================
// HÀM GHI BỘ NHỚ
// ==============================================
static BOOL patch_memory(void *addr, const void *data, size_t len) {
    if (!addr || !data || len == 0) return NO;
    vm_address_t page_start = (vm_address_t)addr & ~(vm_page_size - 1);
    vm_size_t page_end = ((vm_address_t)addr + len + vm_page_size - 1) & ~(vm_page_size - 1);
    vm_size_t page_len = page_end - page_start;

    kern_return_t kr = vm_protect(mach_task_self(), page_start, page_len, FALSE,
        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) return NO;
    memcpy(addr, data, len);
    kr = vm_protect(mach_task_self(), page_start, page_len, FALSE,
        VM_PROT_READ | VM_PROT_EXECUTE);
    return kr == KERN_SUCCESS;
}

static void apply_patch(const struct PatchEntry *entry, BOOL enabled) {
    const struct mach_header *mh = NULL;
    intptr_t slide = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, entry->img)) {
            mh = _dyld_get_image_header(i);
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    if (!mh) return;
    void *target_addr = (void *)((uintptr_t)mh + slide + entry->rva);
    const uint8_t *bytes = enabled ? entry->on : entry->off;
    if (!bytes) bytes = entry->on;
    patch_memory(target_addr, bytes, entry->len);
}

static void update_all_patches(void) {
    for (int i = 0; g_patches[i].img; i++) {
        if (g_patches[i].flag)
            apply_patch(&g_patches[i], *g_patches[i].flag);
        else
            apply_patch(&g_patches[i], YES);
    }
}

// ==============================================
// MENU — ĐÚNG 5 TÊN + NÚT GÓC DƯỚI PHẢI + ĐÃ SỬA LỖI
// ==============================================
@interface EriMenuController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@end

@implementation EriMenuController {
    NSArray *_titles;
    UIView *_dragBar;
    CGPoint _startOffset;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.view.layer.cornerRadius = 12;
    self.view.frame = CGRectMake(20, 80, 320, 460);

    // Thanh kéo di chuyển
    _dragBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _dragBar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    _dragBar.layer.cornerRadius = 12;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_dragBar addGestureRecognizer:pan];
    [self.view addSubview:_dragBar];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 320, 25)];
    title.text = @"Mod By Eri Nguyễn";
    title.textColor = [UIColor greenColor];
    title.font = [UIFont boldSystemFontOfSize:17];
    title.textAlignment = NSTextAlignmentCenter;
    [_dragBar addSubview:title];

    // Nút thu nhỏ
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minBtn.frame = CGRectMake(280, 8, 32, 32);
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [minBtn addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [_dragBar addSubview:minBtn];

    // 5 Tên chức năng
    _titles = @[
        @"Hack Map",
        @"Cam Xa 3 Nất",
        @"Show Unti Địch",
        @"Show Lịch Sử Đấu",
        @"Ẩn Tia Elsu"
    ];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(10, 50, 300, 400) style:UITableViewStylePlain];
    table.delegate = self;
    table.dataSource = self;
    table.backgroundColor = [UIColor clearColor];
    table.separatorColor = [UIColor darkGrayColor];
    table.scrollEnabled = NO;
    [self.view addSubview:table];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        CGPoint loc = [g locationInView:_dragBar];
        _startOffset = CGPointMake(loc.x - 160, loc.y - 22);
    } else if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint loc = [g locationInView:nil];
        self.view.center = CGPointMake(loc.x - _startOffset.x, loc.y - _startOffset.y);
    }
}

- (void)toggleMinimize {
    g_menuMinimized = !g_menuMinimized;
    if (g_menuMinimized) {
        self.view.hidden = YES;
        if (!g_toggleBtn) {
            CGFloat w = [UIScreen mainScreen].bounds.size.width;
            CGFloat h = [UIScreen mainScreen].bounds.size.height;
            // Nút ☰ góc dưới bên phải
            g_toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            g_toggleBtn.frame = CGRectMake(w - 60, h - 120, 50, 50);
            [g_toggleBtn setTitle:@"☰" forState:UIControlStateNormal];
            [g_toggleBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
            g_toggleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
            g_toggleBtn.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
            g_toggleBtn.layer.cornerRadius = 10;
            [g_toggleBtn addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
            [[UIApplication sharedApplication].keyWindow addSubview:g_toggleBtn];
            [[UIApplication sharedApplication].keyWindow bringSubviewToFront:g_toggleBtn];
        } else {
            g_toggleBtn.hidden = NO;
        }
    } else {
        if (g_toggleBtn) g_toggleBtn.hidden = YES;
        self.view.hidden = NO;
    }
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    return _titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"EriCell";
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:cid];
    if (!c) {
        // ✅ ĐÃ SỬA LỖI — DÙNG KIỂU ĐÚNG
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        c.backgroundColor = [UIColor clearColor];
        c.textLabel.textColor = [UIColor whiteColor];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(240, 6, 50, 30)];
        sw.tag = ip.row;
        [sw addTarget:self action:@selector(toggleSwitch:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
    }
    c.textLabel.text = _titles[ip.row];
    UISwitch *sw = (UISwitch *)c.accessoryView;
    switch (ip.row) {
        case 0: sw.on = g_Enabled_Map;        break;
        case 1: sw.on = g_Enabled_CamXa;      break;
        case 2: sw.on = g_Enabled_Unti;       break;
        case 3: sw.on = g_Enabled_LichSu;     break;
        case 4: sw.on = g_Enabled_ElsuTia;    break;
    }
    return c;
}

- (void)toggleSwitch:(UISwitch *)sw {
    switch (sw.tag) {
        case 0: g_Enabled_Map        = sw.on; break;
        case 1: g_Enabled_CamXa      = sw.on; break;
        case 2: g_Enabled_Unti       = sw.on; break;
        case 3: g_Enabled_LichSu     = sw.on; break;
        case 4: g_Enabled_ElsuTia    = sw.on; break;
    }
    update_all_patches();
}

@end

// ==============================================
// HIỂN THỊ MENU
// ==============================================
static void show_menu(void) {
    if (g_menuWindow) return;
    g_menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_menuWindow.windowLevel = UIWindowLevelAlert + 1000;
    g_menuWindow.backgroundColor = [UIColor clearColor];
    g_menuWindow.rootViewController = [[EriMenuController alloc] init];
    [g_menuWindow makeKeyAndVisible];
}

// ==============================================
// KHỞI TẠO
// ==============================================
__attribute__((constructor))
static void eri_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // Áp dụng antiban + anort ngay
        for (int i = 0; g_patches[i].img; i++) {
            if (!g_patches[i].flag)
                apply_patch(&g_patches[i], YES);
        }
        NSLog(@"[Eri] Mod By Eri Nguyễn — Loaded OK");

        // Hiện menu
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            show_menu();
        });
    });
}
