#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

__attribute__((constructor))
static void DylibMain(void) {
    // In ra ngay khi nạp — KHÔNG CẦN GÌ KHÁC
    NSLog(@"[Bypass] ===================================");
    NSLog(@"[Bypass] ✅ DYLIB ĐƯỢC NẠP THÀNH CÔNG!");
    NSLog(@"[Bypass] ===================================");
    
    // In thông tin app
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[Bypass] 📦 App ID: %@", appId);
    
    // Liệt kê vài hàm hệ thống để kiểm tra
    void *p = dlsym(RTLD_DEFAULT, "_dyld_image_count");
    NSLog(@"[Bypass] 🔧 _dyld_image_count: %p", p);
    
    // Tìm vài hàm thực tế có trong app
    const char *syms[] = {
        "gsMain",
        "UnityRuntimeSendMessage",
        "_ZN3bq11NetworkMgr13InstanceDataE",
        NULL
    };
    
    for (int i = 0; syms[i]; i++) {
        void *addr = dlsym(RTLD_DEFAULT, syms[i]);
        NSLog(@"[Bypass] 🔍 %s: %p", syms[i], addr);
    }
    
    NSLog(@"[Bypass] ✅ Kết thúc khởi tạo");
}
