#import <Foundation/Foundation.h>
#import "fishhook.h"

// ==============================================
// KHAI BÁO ĐÚNG KIỂU
// ==============================================
typedef void (*FuncVoid_t)(void*);
typedef int  (*FuncInt_t)(void*);

static FuncVoid_t orig_Report_s;
static FuncVoid_t orig_ReportToTdm_s;
static FuncVoid_t orig_ReportEventByName;
static FuncVoid_t orig_ReportEvent;
static FuncVoid_t orig_SecurityCheckReq;
static FuncVoid_t orig_Event_CommonReport;
static FuncVoid_t orig_EventPhotoReport;

static FuncInt_t orig_IsDebug_s;
static FuncInt_t orig_IsRootChanged;

static FuncVoid_t orig_RefreshPunishTime;
static FuncVoid_t orig_OnReportConfirm;
static FuncVoid_t orig_On_InBattleMsg_ReportConfirm;
static FuncVoid_t orig_reportInfo;
static FuncVoid_t orig_handleReportInfoResult;

// ==============================================
// HÀM CHẶN — KHỚP KIỂU
// ==============================================
static void NoOp_void(void* arg) {
    // Bỏ qua hoàn toàn
}

static int NoOp_zero(void* arg) {
    return 0; // Không phát hiện gì
}

// ==============================================
// NẠP DYLIB
// ==============================================
__attribute__((constructor))
static void DylibMain(void) {
    @autoreleasepool {
        NSLog(@"[Bypass] 🚀 Đang khởi động...");

        // Ép kiểu void* cho khớp struct rebinding
        struct rebinding binds[] = {
            {"_Report_s",                   (void*)NoOp_void,        (void**)&orig_Report_s},
            {"_ReportToTdm_s",              (void*)NoOp_void,        (void**)&orig_ReportToTdm_s},
            {"_ReportEventByName",          (void*)NoOp_void,        (void**)&orig_ReportEventByName},
            {"_ReportEvent",                (void*)NoOp_void,        (void**)&orig_ReportEvent},
            {"_SecurityCheckReq",           (void*)NoOp_void,        (void**)&orig_SecurityCheckReq},
            {"_Event_CommonReport",         (void*)NoOp_void,        (void**)&orig_Event_CommonReport},
            {"_EventPhotoReport",           (void*)NoOp_void,        (void**)&orig_EventPhotoReport},
            
            {"_IsDebug_s",                  (void*)NoOp_zero,        (void**)&orig_IsDebug_s},
            {"_IsRootChanged",              (void*)NoOp_zero,        (void**)&orig_IsRootChanged},
            
            {"_RefreshPunishTime",          (void*)NoOp_void,        (void**)&orig_RefreshPunishTime},
            {"_OnReportConfirm",            (void*)NoOp_void,        (void**)&orig_OnReportConfirm},
            {"_On_InBattleMsg_ReportConfirm", (void*)NoOp_void,      (void**)&orig_On_InBattleMsg_ReportConfirm},
            {"_reportInfo",                 (void*)NoOp_void,        (void**)&orig_reportInfo},
            {"_handleReportInfoResult",     (void*)NoOp_void,        (void**)&orig_handleReportInfoResult},
        };

        int count = sizeof(binds) / sizeof(binds[0]);
        rebind_symbols(binds, count);
        
        NSLog(@"[Bypass] ✅ Đã xử lý %d hàm — SẴN SÀNG!", count);
    }
}
