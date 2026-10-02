#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "fishhook.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/mman.h>

// ==============================================
// KHAI BÁO CỤC BỘ
// ==============================================
static BOOL g_Enabled_Map      = NO;
static BOOL g_Enabled_CamXa    = NO;
static BOOL g_Enabled_Unti     = NO;
static BOOL g_Enabled_LSD      = NO;
static BOOL g_Enabled_HideRay  = NO;

// === Byte pattern — ĐÚNG Y XÌ BẠN ĐƯA ===
static const uint8_t ANORT_FIX[]    = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t RET_INST[]     = {0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t MAP_ON[]       = {0x36, 0x00, 0x80, 0xD2};
static const uint8_t CAM_ON[]       = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t CAM_ON2[]      = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};
static const uint8_t SHOW_ON[]      = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};

struct PatchEntry {
    const char *img;
    uintptr_t rva;
    const uint8_t *on;
    const uint8_t *off;
    size_t len;
    BOOL *flag;
};

// ==============================================
// DANH SÁCH PATCH — ĐÚNG Y XÌ TỪNG DÒNG
// ==============================================
static const struct PatchEntry g_patches[] = {
    // ========== lib anort ==========
    {"libanort.dylib",  0x31C4C,    ANORT_FIX,      NULL,   8,      NULL},
    {"libanort.dylib",  0x4591C,    ANORT_FIX,      NULL,   8,      NULL},

    // ========== Antiban — UnityFramework ==========
    {"UnityFramework",  0x706D890,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706D914,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706D9CC,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706DAB0,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706DD14,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706E0A0,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706E21C,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706E304,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706E6BC,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x706E754,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x677FA8C,  RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x546B08,   RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x83B634,   RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x5B61A0,   RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x5B6380,   RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x5B65CC,   RET_INST,       NULL,   4,      NULL},
    {"UnityFramework",  0x5B6764,   RET_INST,       NULL,   4,      NULL},

    // ========== Bản đồ toàn cảnh ==========
    {"UnityFramework",  0x4A38100,  MAP_ON,         NULL,   4,      &g_Enabled_Map},

    // ========== Tầm nhìn xa ==========
    {"UnityFramework",  0x554B9EC,  CAM_ON,         NULL,   8,      &g_Enabled_CamXa},
    {"UnityFramework",  0x541142C,  CAM_ON2,        NULL,   12,     &g_Enabled_CamXa},
    {"UnityFramework",  0x550E2BC,  CAM_ON2,        NULL,   12,     &g_Enabled_CamXa},

    // ========== Hiện kẻ địch ==========
    {"UnityFramework",  0x5F1C394,  SHOW_ON,        NULL,   8,      &g_Enabled_Unti},
    {"UnityFramework",  0x6A6B798,  SHOW_ON,        NULL,   8,      &g_Enabled_Unti},
    {"UnityFramework",  0x6A6B8FC,  SHOW_ON,        NULL,   8,      &g_Enabled_Unti},

    // ========== Hiện tầm bắn ==========
    {"UnityFramework",  0x5ADF5A8,  SHOW_ON,        NULL,   8,      &g_Enabled_LSD},

    // ========== Ẩn tia chỉ đường — KHÔNG ĐỔI GÌ ==========
    {"UnityFramework",  0x5FBEC8C,  SHOW_ON,        NULL,   8,      &g_Enabled_HideRay},

    {NULL, 0, NULL, NULL, 0, NULL}
};

// ==============================================
// HÀM GHI BYTE VÀO BỘ NHỚ
// ==============================================
static BOOL patch_memory(void *addr, const void *data, size_t len) {
    vm_address_t page_start = (vm_address_t)addr & ~(vm_page_size - 1);
    vm_size_t page_len = (vm_address_t)addr + len - page_start;
    page_len = (page_len + vm_page_size - 1) & ~(vm_page_size - 1);

    kern_return_t kr = vm_protect(mach_task_self(), page_start, page_len, FALSE,
        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) return NO;

    memcpy(addr, data, len);

    kr = vm_protect(mach_task_self(), page_start, page_len, FALSE,
        VM_PROT_READ | VM_PROT_EXECUTE);
    return kr == KERN_SUCCESS;
}

// ==============================================
// ÁP DỤNG PATCH THEO TRẠNG THÁI
// ==============================================
static void apply_patch(const struct PatchEntry *entry, BOOL enabled) {
    const struct mach_header *mh = NULL;
    intptr_t slide = 0;

    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strcmp(_dyld_get_image_name(i), entry->img) == 0) {
            mh = _dyld_get_image_header(i);
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    if (!mh) return;

    void *target_addr = (void *)((uintptr_t)mh + slide + entry->rva);
    const uint8_t *bytes = enabled ? entry->on : entry->off;
    if (!bytes) return;

    patch_memory(target_addr, bytes, entry->len);
}

static void update_all_patches(void) {
    for (int i = 0; g_patches[i].img; i++) {
        if (g_patches[i].flag) {
            apply_patch(&g_patches[i], *g_patches[i].flag);
        } else {
            apply_patch(&g_patches[i], YES);
        }
    }
}

// ==============================================
// GIAO DIỆN MENU
// ==============================================
static UIWindow *g_menuWindow = nil;

@interface EriMenuController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@end

@implementation EriMenuController {
    NSArray *_titles;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.view.layer.cornerRadius = 12;
    self.view.frame = CGRectMake(20, 80, 320, 420);

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 12, 320, 30)];
    title.text = @"Mod By Eri Nguyễn";
    title.textColor = [UIColor greenColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:title];

    _titles = @[
        @"Hack Map",
        @"Cam Xa 3 Nất",
        @"Hiện Unti Địch",
        @"Hiện Lịch Sử Đấu",
        @"Ẩn Tia Elsu"
    ];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(10, 50, 300, 350) style:UITableViewStylePlain];
    table.delegate = self;
    table.dataSource = self;
    table.backgroundColor = [UIColor clearColor];
    table.separatorColor = [UIColor darkGrayColor];
    [self.view addSubview:table];

    // Nút đóng
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(280, 10, 30, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"EriCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(240, 6, 50, 30)];
        sw.tag = indexPath.row;
        [sw addTarget:self action:@selector(toggleSwitch:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    cell.textLabel.text = _titles[indexPath.row];

    UISwitch *sw = (UISwitch *)cell.accessoryView;
    switch (indexPath.row) {
        case 0: sw.on = g_Enabled_Map; break;
        case 1: sw.on = g_Enabled_CamXa; break;
        case 2: sw.on = g_Enabled_Unti; break;
        case 3: sw.on = g_Enabled_LSD; break;
        case 4: sw.on = g_Enabled_HideRay; break;
    }
    return cell;
}

- (void)toggleSwitch:(UISwitch *)sw {
    switch (sw.tag) {
        case 0: g_Enabled_Map      = sw.on; break;
        case 1: g_Enabled_CamXa    = sw.on; break;
        case 2: g_Enabled_Unti     = sw.on; break;
        case 3: g_Enabled_LSD      = sw.on; break;
        case 4: g_Enabled_HideRay  = sw.on; break;
    }
    update_all_patches();
}

- (void)closeMenu {
    g_menuWindow.hidden = YES;
    g_menuWindow = nil;
}

@end

// ==============================================
// HIỂN THỊ MENU
// ==============================================
static void show_menu(void) {
    if (g_menuWindow) return;

    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    g_menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_menuWindow.windowLevel = UIWindowLevelAlert + 1000;
    g_menuWindow.backgroundColor = [UIColor clearColor];
    g_menuWindow.rootViewController = [[EriMenuController alloc] init];
    [g_menuWindow makeKeyAndVisible];
}

// ==============================================
// KHỞI TẠO — TỰ ÁN ÁP DỤNG ANTIBAN
// ==============================================
__attribute__((constructor))
static void eri_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Antiban luôn bật ngay khi load
        for (int i = 0; g_patches[i].img; i++) {
            if (!g_patches[i].flag) {
                apply_patch(&g_patches[i], YES);
            }
        }
        NSLog(@"[Eri] Mod loaded — Antiban applied");

        // Hiển thị menu sau 2 giây
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            show_menu();
        });
    });
}
