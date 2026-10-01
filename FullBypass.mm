#import <Foundation/Foundation.h>
#import <substrate.h>
#import <mach-o/dyld.h>
#import <stdint.h>

// ==============================================
// Khai báo hàm gốc
// ==============================================
static void (*orig_Report_s)(void*);
static void (*orig_ReportToTdm_s)(void*);
static void (*orig_ReportEventByName)(void*);
static void (*orig_ReportEvent)(void*);
static void (*orig_SecurityCheckReq)(void*);
static void (*orig_Event_CommonReport)(void*);
static void (*orig_EventPhotoReport)(void*);

static int (*orig_IsDebug_s)(void*);
static int (*orig_IsRootChanged)(void*);

static void (*orig_RefreshPunishTime)(void*);
static void (*orig_OnReportConfirm)(void*);
static void (*orig_On_InBattleMsg_ReportConfirm)(void*);
static void (*orig_reportInfo)(void*);
static void (*orig_handleReportInfoResult)(void*);

// ==============================================
// Hàm trống — chặn tất cả = trả về ngay
// ==============================================
static void hook_NoOp(void* arg) {
    // Bỏ qua, không gọi hàm gốc
}

static int hook_NoOp_Return0(void* arg) {
    // Trả về 0 = không phát hiện, không phải debug
    return 0;
}

// ==============================================
// Hàm Hook thông minh
// ==============================================
static void HookIfFound(const char* symbolName, void* hookFn, void** origPtr) {
    void* sym = MSFindSymbol(NULL, symbolName);
    if (!sym) {
        NSLog(@"[Bypass] ⚠️ Không tìm thấy: %s", symbolName);
        return;
    }
    MSHookFunction(sym, hookFn, origPtr);
    NSLog(@"[Bypass] ✅ Đã hook: %s", symbolName);
}

// ==============================================
// Bắt đầu khi nạp .dylib
// ==============================================
__attribute__((constructor))
static void ModuleInit(void) {
    @autoreleasepool {
        NSLog(@"[Bypass] 🚀 Đang khởi động Bypass Anti-Cheat...");

        // === Chặn báo cáo an ninh ===
        HookIfFound("_Report_s",                  (void*)hook_NoOp,          (void**)&orig_Report_s);
        HookIfFound("_ReportToTdm_s",             (void*)hook_NoOp,          (void**)&orig_ReportToTdm_s);
        HookIfFound("_ReportEventByName",         (void*)hook_NoOp,          (void**)&orig_ReportEventByName);
        HookIfFound("_ReportEvent",               (void*)hook_NoOp,          (void**)&orig_ReportEvent);
        HookIfFound("_SecurityCheckReq",          (void*)hook_NoOp,          (void**)&orig_SecurityCheckReq);
        HookIfFound("_Event_CommonReport",        (void*)hook_NoOp,          (void**)&orig_Event_CommonReport);
        HookIfFound("_EventPhotoReport",          (void*)hook_NoOp,          (void**)&orig_EventPhotoReport);

        // === Nói dối: không debug, không root/jailbreak ===
        HookIfFound("_IsDebug_s",                 (void*)hook_NoOp_Return0,  (void**)&orig_IsDebug_s);
        HookIfFound("_IsRootChanged",             (void*)hook_NoOp_Return0,  (void**)&orig_IsRootChanged);

        // === Chặn chức năng phạt/xác nhận báo cáo ===
        HookIfFound("_RefreshPunishTime",         (void*)hook_NoOp,          (void**)&orig_RefreshPunishTime);
        HookIfFound("_OnReportConfirm",           (void*)hook_NoOp,          (void**)&orig_OnReportConfirm);
        HookIfFound("_On_InBattleMsg_ReportConfirm", (void*)hook_NoOp,       (void**)&orig_On_InBattleMsg_ReportConfirm);
        HookIfFound("_reportInfo",                (void*)hook_NoOp,          (void**)&orig_reportInfo);
        HookIfFound("_handleReportInfoResult",    (void*)hook_NoOp,          (void**)&orig_handleReportInfoResult);

        NSLog(@"[Bypass] ✅ Tất cả đã sẵn sàng!");
    }
}
