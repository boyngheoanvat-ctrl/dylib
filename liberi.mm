#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

#pragma mark - State

static BOOL g_mapEnabled      = NO;
static BOOL g_camXaEnabled    = NO;
static BOOL g_showUnitEnabled = NO;
static BOOL g_showLsdEnabled  = NO;
static BOOL g_hideTiaEnabled  = NO;

static UIWindow *g_overlayWindow = nil;
static UIView *g_menuView = nil;
static UIButton *g_floatingButton = nil;

#pragma mark - Memory Patching Helpers

void patch_rva_internal(const char *module, uintptr_t rva, const unsigned char *bytes, size_t len);

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

void patch_rva_internal(const char *module, uintptr_t rva, const unsigned char *bytes, size_t len) {
    intptr_t slide;
    uintptr_t base = get_module_base(module, &slide);
    if (!base) return;
    void *addr = (void*)(base + slide + rva);
    patch_memory(addr, bytes, len);
}

#pragma mark - Antiban / Bypass Patches
static void apply_antiban_patches(void) {
    const unsigned char RET_8[] = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6};
    const unsigned char RET_4[] = {0xC0, 0x03, 0x5F, 0xD6};

    #define P1(rva) patch_rva_internal("UnityFramework", rva, RET_8, sizeof(RET_8))
    #define P2(rva) patch_rva_internal("UnityFramework", rva, RET_4, sizeof(RET_4))

    // Danh sách các offset Antiban 8 bytes (RET_8)
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

    // Danh sách các offset Antiban 4 bytes (RET_4)
    P2(0x6A975D8); P2(0x6262450); P2(0x4E2DBBC); P2(0x8D2830);  P2(0x8D28B8);
    P2(0x3DBDAC4); P2(0x378D94);  P2(0x378D9C);  P2(0x7D58360); P2(0x74FF808);
    P2(0x7502AB0); P2(0x76572D4); P2(0x765CC78); P2(0x7661474); P2(0x774EEC8);
    P2(0x775A310); P2(0x7790E40); P2(0x3D3E37C); P2(0x72AE46C); P2(0x735B4AC);
    P2(0x5B4A54C); P2(0xB9AE00);
}

#pragma mark - Touch Window

@interface ERITouchWindow : UIWindow
@end

@implementation ERITouchWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.hidden || self.alpha <= 0.01)
        return nil;

    UIView *hit = [super hitTest:point withEvent:event];

    if (hit == self ||
        hit == self.rootViewController.view) {
        return nil;
    }

    return hit;
}

@end

#pragma mark - Manager

@interface ERIManager : NSObject

+ (instancetype)sharedInstance;

- (void)toggleMenuVisibility:(id)sender;
- (void)handleFloatingPan:(UIPanGestureRecognizer *)gesture;
- (void)handleWindowPan:(UIPanGestureRecognizer *)gesture;
- (void)toggleFeature:(UIButton *)sender;

@end

#pragma mark - Manager Implementation

@implementation ERIManager

+ (instancetype)sharedInstance
{
    static ERIManager *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[ERIManager alloc] init];
    });

    return instance;
}

#pragma mark Menu

- (void)toggleMenuVisibility:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{

        if (!g_menuView)
            return;

        g_menuView.hidden = !g_menuView.hidden;

        if (!g_menuView.hidden) {

            UIView *parent = g_menuView.superview;

            if (parent) {
                [parent bringSubviewToFront:g_menuView];
                [parent bringSubviewToFront:g_floatingButton];
            }
        }
    });
}

#pragma mark Floating Button Drag

- (void)handleFloatingPan:(UIPanGestureRecognizer *)gesture
{
    UIView *button = gesture.view;

    if (!button || !button.superview)
        return;

    UIView *parent = button.superview;

    CGPoint translation =
        [gesture translationInView:parent];

    CGPoint center = button.center;

    center.x += translation.x;
    center.y += translation.y;

    CGFloat halfW = button.bounds.size.width / 2.0;
    CGFloat halfH = button.bounds.size.height / 2.0;

    CGFloat minX = halfW;
    CGFloat maxX = parent.bounds.size.width - halfW;

    CGFloat minY = halfH;
    CGFloat maxY = parent.bounds.size.height - halfH;

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));

    button.center = center;

    [gesture setTranslation:CGPointZero
                    inView:parent];
}

#pragma mark Menu Drag

- (void)handleWindowPan:(UIPanGestureRecognizer *)gesture
{
    UIView *menu = g_menuView;

    if (!menu || menu.hidden || !menu.superview)
        return;

    UIView *parent = menu.superview;

    CGPoint translation =
        [gesture translationInView:parent];

    CGPoint center = menu.center;

    center.x += translation.x;
    center.y += translation.y;

    CGFloat halfW = menu.bounds.size.width / 2.0;
    CGFloat halfH = menu.bounds.size.height / 2.0;

    CGFloat minX = halfW;
    CGFloat maxX = parent.bounds.size.width - halfW;

    CGFloat minY = halfH;
    CGFloat maxY = parent.bounds.size.height - halfH;

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));

    menu.center = center;

    [gesture setTranslation:CGPointZero
                    inView:parent];
}

#pragma mark Button UI

- (void)updateButton:(UIButton *)button
               title:(NSString *)title
             enabled:(BOOL)enabled
{
    NSString *text =
        [NSString stringWithFormat:@"[%@] %@",
         enabled ? @"x" : @" ",
         title];

    [button setTitle:text
            forState:UIControlStateNormal];

    if (enabled) {

        button.backgroundColor =
            [UIColor colorWithRed:0.20
                            green:0.45
                             blue:0.25
                            alpha:1.0];

    } else {

        button.backgroundColor =
            [UIColor colorWithRed:0.20
                            green:0.20
                             blue:0.22
                            alpha:1.0];
    }
}

#pragma mark Feature Toggle (With Provided Offsets)

- (void)toggleFeature:(UIButton *)sender
{
    if (!sender)
        return;

    switch (sender.tag) {

        case 1:
        {
            g_mapEnabled = !g_mapEnabled;
            [self updateButton:sender title:@"MAP" enabled:g_mapEnabled];

            // Map: 0x4A38100
            const unsigned char MAP_ON[]  = {0x36, 0x00, 0x80, 0xD2};
            const unsigned char MAP_OFF[] = {0x00, 0x00, 0x80, 0xD2}; // Giá trị gốc thông thường hoặc thay đổi phù hợp
            patch_rva_internal("UnityFramework", 0x4A38100, g_mapEnabled ? MAP_ON : MAP_OFF, 4);
        }
        break;

        case 2:
        {
            g_camXaEnabled = !g_camXaEnabled;
            [self updateButton:sender title:@"CAM XA" enabled:g_camXaEnabled];

            // Cam xa offsets
            const unsigned char CAM1_ON[]  = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
            const unsigned char CAM1_OFF[] = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};

            const unsigned char CAM2_ON[]  = {0x00, 0x00, 0xA8, 0x52, 0x00, 0x00, 0x27, 0x1E, 0xC0, 0x03, 0x5F, 0xD6};
            const unsigned char CAM2_OFF[] = {0x00, 0x00, 0x80, 0xD2, 0xC0, 0x03, 0x5F, 0xD6, 0xC0, 0x03, 0x5F, 0xD6}; // hoặc gốc tương ứng

            if (g_camXaEnabled) {
                patch_rva_internal("UnityFramework", 0x554B9EC, CAM1_ON, 8);
                patch_rva_internal("UnityFramework", 0x541142C, CAM2_ON, 12);
                patch_rva_internal("UnityFramework", 0x550E2BC, CAM2_ON, 12);
            } else {
                patch_rva_internal("UnityFramework", 0x554B9EC, CAM1_OFF, 8);
                patch_rva_internal("UnityFramework", 0x541142C, CAM2_OFF, 12);
                patch_rva_internal("UnityFramework", 0x550E2BC, CAM2_OFF, 12);
            }
        }
        break;

        case 3:
        {
            g_showUnitEnabled = !g_showUnitEnabled;
            [self updateButton:sender title:@"SHOW UNIT" enabled:g_showUnitEnabled];

            // Show Unit offsets
            const unsigned char UNIT_ON[]  = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
            const unsigned char UNIT_OFF[] = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};

            if (g_showUnitEnabled) {
                patch_rva_internal("UnityFramework", 0x5F1C394, UNIT_ON, 8);
                patch_rva_internal("UnityFramework", 0x6A6B798, UNIT_ON, 8);
                patch_rva_internal("UnityFramework", 0x6A6B8FC, UNIT_ON, 8);
            } else {
                patch_rva_internal("UnityFramework", 0x5F1C394, UNIT_OFF, 8);
                patch_rva_internal("UnityFramework", 0x6A6B798, UNIT_OFF, 8);
                patch_rva_internal("UnityFramework", 0x6A6B8FC, UNIT_OFF, 8);
            }
        }
        break;

        case 4:
        {
            g_showLsdEnabled = !g_showLsdEnabled;
            [self updateButton:sender title:@"SHOW LSD" enabled:g_showLsdEnabled];

            // Show LSD: 0x5ADF5A8
            const unsigned char LSD_ON[]  = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
            const unsigned char LSD_OFF[] = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
            patch_rva_internal("UnityFramework", 0x5ADF5A8, g_showLsdEnabled ? LSD_ON : LSD_OFF, 8);
        }
        break;

        case 5:
        {
            g_hideTiaEnabled = !g_hideTiaEnabled;
            [self updateButton:sender title:@"ẨN TIA" enabled:g_hideTiaEnabled];

            // Ẩn tia: 0x5FBEC8C
            const unsigned char TIA_ON[]  = {0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
            const unsigned char TIA_OFF[] = {0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6};
            patch_rva_internal("UnityFramework", 0x5FBEC8C, g_hideTiaEnabled ? TIA_ON : TIA_OFF, 8);
        }
        break;

        default:
            break;
    }
}

@end

#pragma mark - Menu Creation

static UIButton *ERI_CreateButton(
    NSString *title,
    NSInteger tag,
    CGRect frame,
    ERIManager *manager)
{
    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeCustom];

    button.frame = frame;
    button.tag = tag;

    button.backgroundColor =
        [UIColor colorWithRed:0.20
                        green:0.20
                         blue:0.22
                        alpha:1.0];

    button.layer.cornerRadius = 3.0;
    button.layer.borderWidth = 0.5;

    button.layer.borderColor =
        [UIColor colorWithRed:0.35
                        green:0.35
                         blue:0.38
                        alpha:1.0].CGColor;

    [button setTitle:
        [NSString stringWithFormat:@"[ ] %@", title]
          forState:UIControlStateNormal];

    [button setTitleColor:
        [UIColor colorWithRed:0.90
                        green:0.90
                         blue:0.90
                        alpha:1.0]
      forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont boldSystemFontOfSize:11.0];

    button.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentLeft;

    button.titleEdgeInsets =
        UIEdgeInsetsMake(0, 8, 0, 0);

    [button addTarget:manager
               action:@selector(toggleFeature:)
     forControlEvents:UIControlEventTouchUpInside];

    return button;
}

#pragma mark - Setup

static void setup_eri_menu(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        if (g_overlayWindow) {
            g_overlayWindow.hidden = NO;
            return;
        }

        CGRect screenBounds =
            [UIScreen mainScreen].bounds;

        g_overlayWindow =
            [[ERITouchWindow alloc]
             initWithFrame:screenBounds];

        g_overlayWindow.backgroundColor =
            UIColor.clearColor;

        g_overlayWindow.opaque = NO;

        g_overlayWindow.windowLevel =
            UIWindowLevelAlert + 1;

        UIViewController *rootVC =
            [[UIViewController alloc] init];

        rootVC.view.backgroundColor =
            UIColor.clearColor;

        g_overlayWindow.rootViewController =
            rootVC;

        g_overlayWindow.hidden = NO;

        ERIManager *manager =
            [ERIManager sharedInstance];

        UIView *container = rootVC.view;

        #pragma mark Menu

        g_menuView =
            [[UIView alloc]
             initWithFrame:
                CGRectMake(100, 100, 220, 260)];

        g_menuView.backgroundColor =
            [UIColor colorWithRed:0.06
                            green:0.06
                             blue:0.07
                            alpha:0.96];

        g_menuView.layer.cornerRadius = 5.0;

        g_menuView.layer.borderWidth = 1.0;

        g_menuView.layer.borderColor =
            [UIColor colorWithRed:0.25
                            green:0.25
                             blue:0.28
                            alpha:1.0].CGColor;

        g_menuView.clipsToBounds = YES;

        g_menuView.hidden = YES;

        [container addSubview:g_menuView];

        #pragma mark Title Bar

        UIView *titleBar =
            [[UIView alloc]
             initWithFrame:
                CGRectMake(0, 0, 220, 28)];

        titleBar.backgroundColor =
            [UIColor colorWithRed:0.16
                            green:0.16
                             blue:0.18
                            alpha:1.0];

        titleBar.userInteractionEnabled = YES;

        UILabel *title =
            [[UILabel alloc]
             initWithFrame:
                CGRectMake(8, 0, 204, 28)];

        title.text =
            @"ERI MOD MENU v1.0";

        title.textColor =
            [UIColor colorWithRed:0.88
                            green:0.88
                             blue:0.90
                            alpha:1.0];

        title.font =
            [UIFont boldSystemFontOfSize:11.0];

        title.userInteractionEnabled = NO;

        [titleBar addSubview:title];

        [g_menuView addSubview:titleBar];

        UIPanGestureRecognizer *menuPan =
            [[UIPanGestureRecognizer alloc]
             initWithTarget:manager
             action:@selector(handleWindowPan:)];

        [titleBar addGestureRecognizer:menuPan];

        #pragma mark Buttons

        CGFloat x = 10.0;
        CGFloat y = 36.0;

        CGFloat w = 200.0;
        CGFloat h = 30.0;

        NSArray *names = @[
            @"MAP",
            @"CAM XA",
            @"SHOW UNIT",
            @"SHOW LSD",
            @"ẨN TIA"
        ];

        for (NSInteger i = 0;
             i < names.count;
             i++) {

            UIButton *button =
                ERI_CreateButton(
                    names[i],
                    i + 1,
                    CGRectMake(x, y, w, h),
                    manager
                );

            [g_menuView addSubview:button];

            y += 36.0;
        }

        #pragma mark Floating Button

        g_floatingButton =
            [UIButton buttonWithType:
                UIButtonTypeCustom];

        g_floatingButton.frame =
            CGRectMake(30, 100, 44, 44);

        g_floatingButton.backgroundColor =
            [UIColor colorWithRed:0.10
                            green:0.10
                             blue:0.12
                            alpha:0.92];

        [g_floatingButton setTitle:
            @"ERI"
            forState:UIControlStateNormal];

        [g_floatingButton setTitleColor:
            [UIColor colorWithRed:0.20
                            green:0.75
                             blue:1.0
                            alpha:1.0]
            forState:UIControlStateNormal];

        g_floatingButton.titleLabel.font =
            [UIFont boldSystemFontOfSize:11.0];

        g_floatingButton.layer.cornerRadius = 22.0;

        g_floatingButton.layer.borderWidth = 1.0;

        g_floatingButton.layer.borderColor =
            [UIColor colorWithRed:0.30
                            green:0.30
                             blue:0.35
                            alpha:1.0].CGColor;

        [container addSubview:g_floatingButton];

        [g_floatingButton
            addTarget:manager
            action:@selector(toggleMenuVisibility:)
            forControlEvents:
                UIControlEventTouchUpInside];

        UIPanGestureRecognizer *floatingPan =
            [[UIPanGestureRecognizer alloc]
             initWithTarget:manager
             action:@selector(handleFloatingPan:)];

        [g_floatingButton
            addGestureRecognizer:floatingPan];

        [container bringSubviewToFront:g_floatingButton];

        NSLog(@"[ERI] Menu UI loaded with all offsets.");
    });
}

#pragma mark - Entry

__attribute__((constructor))
static void eri_init(void)
{
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(1.5 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            apply_antiban_patches();
            setup_eri_menu();
        }
    );
}
