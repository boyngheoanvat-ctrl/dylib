#import <Foundation/Foundation.h>
#import "fishhook.h"  // ✅ Đổi từ <...> thành "..."

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
// Hàm chặn
// ==============================================
static void NoOp_void(void* arg) {
}

static int NoOp_zero(void* arg) {
    return 0;
}

// ==============================================
// Khởi động
// ==============================================
__attribute__((constructor))
static void DylibMain(void) {
    @autoreleasepool {
        NSLog(@"[Bypass] 🚀 Đang nạp...");

        struct rebinding binds[] = {
            {"_Report_s",                   NoOp_void,        (void**)&orig_Report_s},
            {"_ReportToTdm_s",              NoOp_void,        (void**)&orig_ReportToTdm_s},
            {"_ReportEventByName",          NoOp_void,        (void**)&orig_ReportEventByName},
            {"_ReportEvent",                NoOp_void,        (void**)&orig_ReportEvent},
            {"_SecurityCheckReq",           NoOp_void,        (void**)&orig_SecurityCheckReq},
            {"_Event_CommonReport",         NoOp_void,        (void**)&orig_Event_CommonReport},
            {"_EventPhotoReport",           NoOp_void,        (void**)&orig_EventPhotoReport},
            
            {"_IsDebug_s",                  NoOp_zero,        (void**)&orig_IsDebug_s},
            {"_IsRootChanged",              NoOp_zero,        (void**)&orig_IsRootChanged},
            
            {"_RefreshPunishTime",          NoOp_void,        (void**)&orig_RefreshPunishTime},
            {"_OnReportConfirm",            NoOp_void,        (void**)&orig_OnReportConfirm},
            {"_On_InBattleMsg_ReportConfirm", NoOp_void,      (void**)&orig_On_InBattleMsg_ReportConfirm},
            {"_reportInfo",                 NoOp_void,        (void**)&orig_reportInfo},
            {"_handleReportInfoResult",     NoOp_void,        (void**)&orig_handleReportInfoResult},
        };

        int count = sizeof(binds) / sizeof(binds[0]);
        rebind_symbols(binds, count);
        
        NSLog(@"[Bypass] ✅ Đã hook %d hàm — SẴN SÀNG!", count);
    }
}
