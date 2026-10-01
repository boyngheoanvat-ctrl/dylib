// ==================================================
// BYPASS BÁO CÁO / BẢO MẬT — DÙNG API CHUẨN SUBSTRATE
// ==================================================
#import <Foundation/Foundation.h>
#import <substrate.h>

// === KHAI BÁO KIỂU ===
typedef int (*Fn_General)(void*);

// === CON TRỎ HÀM GỐC ===
static Fn_General orig_Report_s = NULL;
static Fn_General orig_ReportToTdm_s = NULL;
static Fn_General orig_ReportEventByName = NULL;
static Fn_General orig_ReportEvent = NULL;
static Fn_General orig_SecurityCheckReq = NULL;
static Fn_General orig_Event_CommonReport = NULL;
static Fn_General orig_EventPhotoReport = NULL;
static Fn_General orig_IsDebug_s = NULL;
static Fn_General orig_IsRootChanged = NULL;
static Fn_General orig_RefreshPunishTime = NULL;
static Fn_General orig_OnReportConfirm = NULL;
static Fn_General orig_On_InBattleMsg_ReportConfirm = NULL;
static Fn_General orig_reportInfo = NULL;
static Fn_General orig_handleReportInfoResult = NULL;

// === HÀM THAY THẾ — TRẢ VỀ THÀNH CÔNG ===
static int hook_NoOp(void* ctx) { return 0; }

// === HÀM HỖ TRỢ: TÌM & HOOK 1 HÀM ===
static void HookIfFound(const char* symbolName, void* hookFn, void** origPtr) {
    @autoreleasepool {
        MSImageRef image = MSGetImageByName(NULL); // Tìm trong ảnh chính của app
        if (!image) image = MSGetImageByName("/usr/libexec/backboardd"); // Phụ nếu cần
        if (!image) return;
        
        void* symAddr = MSFindSymbol(image, symbolName);
        if (symAddr) {
            MSHookFunction(symAddr, hookFn, origPtr);
            NSLog(@"[AntiBypass] ✅ Hook: %s", symbolName);
        } else {
            NSLog(@"[AntiBypass] ⚠️ Không tìm thấy: %s", symbolName);
        }
    }
}

// === KHỞI TẠO ===
__attribute__((constructor))
static void AntiBypassInit(void) {
    @autoreleasepool {
        NSLog(@"[AntiBypass] ✅ Đang khởi tạo...");

        // Báo cáo
        HookIfFound("_Report_s", hook_NoOp, (void**)&orig_Report_s);
        HookIfFound("_ReportToTdm_s", hook_NoOp, (void**)&orig_ReportToTdm_s);
        HookIfFound("_ReportEventByName", hook_NoOp, (void**)&orig_ReportEventByName);
        HookIfFound("_ReportEvent", hook_NoOp, (void**)&orig_ReportEvent);
        HookIfFound("_SecurityCheckReq", hook_NoOp, (void**)&orig_SecurityCheckReq);
        HookIfFound("_Event_CommonReport", hook_NoOp, (void**)&orig_Event_CommonReport);
        HookIfFound("_EventPhotoReport", hook_NoOp, (void**)&orig_EventPhotoReport);

        // Kiểm tra bảo mật
        HookIfFound("_IsDebug_s", hook_NoOp, (void**)&orig_IsDebug_s);
        HookIfFound("_IsRootChanged", hook_NoOp, (void**)&orig_IsRootChanged);

        // Xử lý phạt / thông báo
        HookIfFound("_RefreshPunishTime", hook_NoOp, (void**)&orig_RefreshPunishTime);
        HookIfFound("_OnReportConfirm", hook_NoOp, (void**)&orig_OnReportConfirm);
        HookIfFound("_On_InBattleMsg_ReportConfirm", hook_NoOp, (void**)&orig_On_InBattleMsg_ReportConfirm);
        HookIfFound("_reportInfo", hook_NoOp, (void**)&orig_reportInfo);
        HookIfFound("_handleReportInfoResult", hook_NoOp, (void**)&orig_handleReportInfoResult);

        NSLog(@"[AntiBypass] ✅ Hoàn tất!");
    }
}
