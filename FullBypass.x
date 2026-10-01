// ==================================================
// BYPASS BÁO CÁO / BẢO MẬT — DÙNG KÝ HIỆU ĐỘNG
// ==================================================
#import <Foundation/Foundation.h>
#import <substrate.h>
#import <substrate/dynamic.h>

// === KHAI BÁO KIỂU HÀM ===
typedef int (*Fn_void)(void*);
typedef int (*Fn_Report)(void*);

// === CON TRỎ HÀM GỐC ===
static Fn_void orig_Report_s = NULL;
static Fn_void orig_ReportToTdm_s = NULL;
static Fn_void orig_ReportEventByName = NULL;
static Fn_void orig_ReportEvent = NULL;
static Fn_void orig_SecurityCheckReq = NULL;
static Fn_void orig_Event_CommonReport = NULL;
static Fn_void orig_EventPhotoReport = NULL;
static Fn_void orig_IsDebug_s = NULL;
static Fn_void orig_IsRootChanged = NULL;
static Fn_void orig_RefreshPunishTime = NULL;
static Fn_void orig_OnReportConfirm = NULL;
static Fn_void orig_On_InBattleMsg_ReportConfirm = NULL;
static Fn_void orig_reportInfo = NULL;
static Fn_void orig_handleReportInfoResult = NULL;

// === HÀM GHI ĐÈ — TRẢ VỀ KHÔNG GÌ ===
static int hook_NoOp(void* ctx) { return 0; }

// === KHỞI TẠO ĐỘNG ===
__attribute__((constructor))
static void AntiBypassInit(void) {
    @autoreleasepool {
        NSLog(@"[AntiBypass] ✅ Đang tải ký hiệu động...");

        // === Nhóm: Báo cáo ===
        MSDynamicHookSymbol("_Report_s",
            (void*)hook_NoOp, (void**)&orig_Report_s);
        MSDynamicHookSymbol("_ReportToTdm_s",
            (void*)hook_NoOp, (void**)&orig_ReportToTdm_s);
        MSDynamicHookSymbol("_ReportEventByName",
            (void*)hook_NoOp, (void**)&orig_ReportEventByName);
        MSDynamicHookSymbol("_ReportEvent",
            (void*)hook_NoOp, (void**)&orig_ReportEvent);
        MSDynamicHookSymbol("_SecurityCheckReq",
            (void*)hook_NoOp, (void**)&orig_SecurityCheckReq);
        MSDynamicHookSymbol("_Event_CommonReport",
            (void*)hook_NoOp, (void**)&orig_Event_CommonReport);
        MSDynamicHookSymbol("_EventPhotoReport",
            (void*)hook_NoOp, (void**)&orig_EventPhotoReport);

        // === Nhóm: Kiểm tra bảo mật ===
        MSDynamicHookSymbol("_IsDebug_s",
            (void*)hook_NoOp, (void**)&orig_IsDebug_s);
        MSDynamicHookSymbol("_IsRootChanged",
            (void*)hook_NoOp, (void**)&orig_IsRootChanged);

        // === Nhóm: Xử lý phạt / thông báo ===
        MSDynamicHookSymbol("_RefreshPunishTime",
            (void*)hook_NoOp, (void**)&orig_RefreshPunishTime);
        MSDynamicHookSymbol("_OnReportConfirm",
            (void*)hook_NoOp, (void**)&orig_OnReportConfirm);
        MSDynamicHookSymbol("_On_InBattleMsg_ReportConfirm",
            (void*)hook_NoOp, (void**)&orig_On_InBattleMsg_ReportConfirm);
        MSDynamicHookSymbol("_reportInfo",
            (void*)hook_NoOp, (void**)&orig_reportInfo);
        MSDynamicHookSymbol("_handleReportInfoResult",
            (void*)hook_NoOp, (void**)&orig_handleReportInfoResult);

        NSLog(@"[AntiBypass] ✅ HOÀN TẤT — Tất cả hàm đã được bỏ qua!");
    }
}
