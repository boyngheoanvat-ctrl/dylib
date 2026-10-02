#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <UIKit/UIKit.h>

// State variables for features
static BOOL g_mapEnabled = NO;
static BOOL g_camXaEnabled = NO;
static BOOL g_custom1_1Enabled = NO;
static BOOL g_custom1_2Enabled = NO;
static BOOL g_showUnitEnabled = NO;
static BOOL g_showLsdEnabled = NO;
static BOOL g_hideTiaEnabled = NO;

static void patch_memory(void *addr, const void *data, size_t len) {
    vm_address_t page_start = (vm_address_t)addr & ~(PAGE_SIZE - 1);
    size_t page_len = (uintptr_t)addr - page_start + len;
    
    if (vm_protect(mach_task_self(), page_start, page_len, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE) != KERN_SUCCESS)
        return;
    memcpy(addr, data, len);
    vm_protect(mach_task_self(), page_start, page_len, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
}

static uintptr_t get_module_base(const char *module_name, intptr_t *out_slide) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, module_name)) {
            *out_slide = _dyld_get_image_vmaddr_slide(i);
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    *out_slide = 0;
    return 0;
}

static void patch_rva(const char *module, uintptr_t rva, const unsigned char *bytes, size_t len) {
    intptr_t slide;
    uintptr_t base = get_module_base(module, &slide);
    if (!base) return;
    void *addr = (void*)(base + slide + rva);
    patch_memory(addr, bytes, len);
}

#pragma mark - Patches
static void apply_antiban_patches(void) {
    const unsigned char RET_8[]   = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char RET_4[]   = {0xC0, 0x03, 0x5F, 0xD6};

    // ===== LỚP 1 — TẤT CẢ chuyển sang UnityFramework (Antiban) =====
    #define P1(rva) patch_rva("UnityFramework", rva, RET_8, sizeof(RET_8))
    P1(0x5CD0C04); P1(0x6A60228); P1(0x6A69CAC); P1(0x6A69D9C); P1(0x6AEB808);
    P1(0x6DBC0B0); P1(0x6DBC0B4); P1(0x6DBC294); P1(0x6DBC298); P1(0x6DC59DC);
    P1(0x6DCB8E8); P1(0x6E01E60); P1(0x705DB3C); P1(0x705DB38); P1(0x706D94C);
    P1(0x706E30C); P1(0x706D9CC); P1(0x706E938); P1(0x70985BC); P1(0x7098624);
    P1(0x7182C4C); P1(0x7182C50); P1(0x7182C54); P1(0x718370C); P1(0x71837B4);
    P1(0x71838D4); P1(0x7267A24); P1(0x72D0C2C); P1(0x72D0C30); P1(0x5221798);
    P1(0x5221818); P1(0x5221918); P1(0x5221998); P1(0x5221A18); P1(0x556CBD8);
    P1(0x556CEA8); P1(0x556CFD4); P1(0x5682E38); P1(0x6179804); P1(0x6179A6C);
    P1(0x6179C04); P1(0x6179DCC); P1(0x6179FAC); P1(0x617A270); P1(0x617A430);
    P1(0x6230268); P1(0x6238C30); P1(0x62643FC); P1(0x627B2FC); P1(0x627C97C);
    P1(0x6339604); P1(0x6460F74); P1(0x646A470); P1(0x6469AF0); P1(0x68FDBA4);
    P1(0x69E2C0C); P1(0x4096CB0); P1(0x4384A98); P1(0x4386594); P1(0x43F1C5C);
    P1(0x440F8E4); P1(0x4410D50); P1(0x5162A4);  P1(0x5162FC);  P1(0x5295F4);
    P1(0x52964C); P1(0xB86780);  P1(0xB86808);  P1(0x3D60BA0); P1(0x3D69418);
    P1(0x3F74DBC); P1(0x3F76240); P1(0x3F82444); P1(0x3DBDAC4); P1(0x3DC47FC);
    P1(0x3DD3BB8); P1(0x3DE7260); P1(0x3DE75A8); P1(0x3E03488); P1(0x3E098B4);
    P1(0x3E567D4); P1(0x3E586F0); P1(0x3E587F8); P1(0x3E58CB4); P1(0x3E5CC8C);
    P1(0xF02F68);  P1(0xF02FC4);  P1(0xF03108);  P1(0xF031B8);  P1(0xF032B8);
    P1(0xF03614);  P1(0xF037F0);  P1(0xF03BA0);  P1(0xF03E74);  P1(0xF03B3C);
    P1(0xEF453C);  P1(0xF06610);  P1(0xF29E98);  P1(0xE88420);  P1(0xE88508);
    P1(0xE885C0);  P1(0xE89224);  P1(0x74F80D4); P1(0x74FA6D8); P1(0x74FD2D0);
    P1(0x74FD3A8); P1(0x74FEEB0); P1(0x7502784); P1(0x74FF808); P1(0x7502AB0);
    P1(0x7502EA4); P1(0x7503400); P1(0x74FA46C); P1(0x750975C); P1(0x750A1EC);
    P1(0x7509CE4); P1(0x76BCC3C); P1(0x76587A8); P1(0x76572D4); P1(0x765CC78);
    P1(0x7661474); P1(0x7657494); P1(0x76FA234); P1(0x76FBE18); P1(0x7707DC8);
    P1(0x7709690); P1(0x7713634); P1(0x77137A4); P1(0x774852C); P1(0x7749650);
    P1(0x77539A0); P1(0x77539B0); P1(0x774EEC8); P1(0x774ED98); P1(0x774F7E0);
    P1(0x774F8B0); P1(0x7751788); P1(0x77523C8); P1(0x775F87C); P1(0x7760498);
    P1(0x77604B8); P1(0x7790770); P1(0x78A1CC0); P1(0x78A1D00); P1(0x3D1851C);
    P1(0x3D185A4); P1(0x3D185AC); P1(0x3D2EA34); P1(0x3D30D00); P1(0x3D31D40);
    P1(0x3D33F4C); P1(0x3D33F54); P1(0x3D3E37C); P1(0x3D3E384); P1(0x3A03224);
    P1(0x3A16458); P1(0x3A1A948); P1(0xFB3820);  P1(0x7871F5C); P1(0x7871FB8);
    P1(0x78721B0); P1(0x78723A8); P1(0x78727C8); P1(0x7872D38); P1(0x16EC2C0);
    P1(0x7876684); P1(0x78768B0); P1(0x111DB70); P1(0x7947C84); P1(0x794A95C);
    P1(0x79499AC); P1(0x794BB00); P1(0x794AC58);

    // ===== LỚP 2 — Tencent (Antiban) =====
    #define P2(rva) patch_rva("UnityFramework", rva, RET_4, sizeof(RET_4))
    P2(0x6A975D8); P2(0x6262450); P2(0x4E2DBBC); P2(0x8D2830);  P2(0x8D28B8);
    P2(0x3DBDAC4); P2(0x378D94);  P2(0x378D9C);  P2(0x7D58360); P2(0x74FF808);
    P2(0x7502AB0); P2(0x76572D4); P2(0x765CC78); P2(0x7661474); P2(0x774EEC8);
    P2(0x775A310); P2(0x7790E40); P2(0x3D3E37C);

    // ===== LỚP 3 — Singapore (Antiban) =====
    P2(0x72AE46C); P2(0x735B4AC); P2(0x5B4A54C); P2(0xB9AE00);
}

#pragma mark - Feature Actions & UI Toggles
static void toggle_map(UIButton *sender) {
    g_mapEnabled = !g_mapEnabled;
    sender.backgroundColor = g_mapEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_mapEnabled ? @"MAP: ON" : @"MAP: OFF" forState:UIControlStateNormal];
    
    if (g_mapEnabled) {
        patch_rva("UnityFramework", 0x4A38100, (const unsigned char*)"\x36\x00\x80\xD2", 4);
    } else {
        patch_rva("UnityFramework", 0x4A38100, (const unsigned char*)"\x00\x00\x80\xD2", 4);
    }
}

static void toggle_camxa1(UIButton *sender) {
    g_camXaEnabled = !g_camXaEnabled;
    sender.backgroundColor = g_camXaEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_camXaEnabled ? @"CAM XA: ON" : @"CAM XA: OFF" forState:UIControlStateNormal];
    
    const unsigned char RET_20[] = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]   = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x554B9EC, g_camXaEnabled ? RET_20 : ORIG, 8);
}

static void toggle_camxa2(UIButton *sender) {
    g_custom1_1Enabled = !g_custom1_1Enabled;
    sender.backgroundColor = g_custom1_1Enabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_custom1_1Enabled ? @"CUSTOM 1: ON" : @"CUSTOM 1: OFF" forState:UIControlStateNormal];
    
    const unsigned char CUSTOM1[] = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]    = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x541142C, g_custom1_1Enabled ? CUSTOM1 : ORIG, sizeof(CUSTOM1));
}

static void toggle_camxa3(UIButton *sender) {
    g_custom1_2Enabled = !g_custom1_2Enabled;
    sender.backgroundColor = g_custom1_2Enabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_custom1_2Enabled ? @"CUSTOM 2: ON" : @"CUSTOM 2: OFF" forState:UIControlStateNormal];
    
    const unsigned char CUSTOM1[] = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]    = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x550E2BC, g_custom1_2Enabled ? CUSTOM1 : ORIG, sizeof(CUSTOM1));
}

static void toggle_showunit1(UIButton *sender) {
    g_showUnitEnabled = !g_showUnitEnabled;
    sender.backgroundColor = g_showUnitEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_showUnitEnabled ? @"SHOW UNIT 1: ON" : @"SHOW UNIT 1: OFF" forState:UIControlStateNormal];
    
    const unsigned char RET_20[] = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]   = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x5F1C394, g_showUnitEnabled ? RET_20 : ORIG, 8);
}

static void toggle_showunit2(UIButton *sender) {
    g_showUnitEnabled = !g_showUnitEnabled;
    sender.backgroundColor = g_showUnitEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_showUnitEnabled ? @"SHOW UNIT 2: ON" : @"SHOW UNIT 2: OFF" forState:UIControlStateNormal];
    
    const unsigned char RET_20[] = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]   = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x6A6B798, g_showUnitEnabled ? RET_20 : ORIG, 8);
}

static void toggle_showunit3(UIButton *sender) {
    g_showUnitEnabled = !g_showUnitEnabled;
    sender.backgroundColor = g_showUnitEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_showUnitEnabled ? @"SHOW UNIT 3: ON" : @"SHOW UNIT 3: OFF" forState:UIControlStateNormal];
    
    const unsigned char RET_20[] = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]   = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x6A6B8FC, g_showUnitEnabled ? RET_20 : ORIG, 8);
}

static void toggle_showlsd(UIButton *sender) {
    g_showLsdEnabled = !g_showLsdEnabled;
    sender.backgroundColor = g_showLsdEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_showLsdEnabled ? @"SHOW LSD: ON" : @"SHOW LSD: OFF" forState:UIControlStateNormal];
    
    const unsigned char RET_20[] = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]   = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x5ADF5A8, g_showLsdEnabled ? RET_20 : ORIG, 8);
}

static void toggle_hidetia(UIButton *sender) {
    g_hideTiaEnabled = !g_hideTiaEnabled;
    sender.backgroundColor = g_hideTiaEnabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
    [sender setTitle:g_hideTiaEnabled ? @"ẨN TIA: ON" : @"ẨN TIA: OFF" forState:UIControlStateNormal];
    
    const unsigned char RET_20[] = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char ORIG[]   = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
    patch_rva("UnityFramework", 0x5FBEC8C, g_hideTiaEnabled ? RET_20 : ORIG, 8);
}

static UIButton* create_button(CGRect frame, NSString *title, SEL action) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.layer.cornerRadius = 6;
    btn.backgroundColor = [UIColor systemRedColor];
    [btn setTitle:[NSString stringWithFormat:@"%@: OFF", title] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [btn addTarget:nil action:action forControlEvents:UIControlEventTouchUpInside];
    btn.layer.zPosition = 1000;
    return btn;
}

static void show_all_toggle_buttons(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [[UIApplication sharedApplication] keyWindow];
        CGFloat w = 140, h = 32, startY = 50, spacing = 36;
        
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 0), w, h), @"MAP", @selector(toggle_map:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 1), w, h), @"CAM XA", @selector(toggle_camxa1:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 2), w, h), @"CUST 1", @selector(toggle_camxa2:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 3), w, h), @"CUST 2", @selector(toggle_camxa3:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 4), w, h), @"SHOW UNIT 1", @selector(toggle_showunit1:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 5), w, h), @"SHOW UNIT 2", @selector(toggle_showunit2:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 6), w, h), @"SHOW UNIT 3", @selector(toggle_showunit3:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 7), w, h), @"SHOW LSD", @selector(toggle_showlsd:))];
        [win addSubview:create_button(CGRectMake(20, startY + (spacing * 8), w, h), @"ẨN TIA", @selector(toggle_hidetia:))];
    });
}

#pragma mark - Entry
__attribute__((constructor))
static void eri_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[ERI] 🔥 Đang kích hoạt Antiban vĩnh viễn (3 lớp)...");
        apply_antiban_patches();
        show_all_toggle_buttons();
        NSLog(@"[ERI] ✅ Đã khởi tạo giao diện bật/tắt các chức năng mod.");
    });
}
