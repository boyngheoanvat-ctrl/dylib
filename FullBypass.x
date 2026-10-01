// ==================================================
// BYPASS CHỈ HÀM CỐT LÕI — BÁO CÁO / BAN / BẢO MẬT
// ==================================================
#import <Foundation/Foundation.h>
#import <substrate.h>

// === KHAI BÁO HÀM ĐỂ BIÊN DỊCH HIỂU ===
extern int Report_s(void*);
extern int ReportError_s(void*);
extern int ReportToTdm_s(void*);
extern int ReportToTdmEx_s(void*);
extern int FaaSBrokerReport_s(void*);
extern int ReportEventByName(void*);
extern int ReportEvent(void*);
extern int ReportPayEvent(void*);
extern int ApolloReportEvent(void*);
extern int SecurityCheckReq(void*);
extern int ReportBindEvent(void*);
extern int Event_CommonReport(void*);
extern int EventPhotoReport(void*);

extern int IsDebug_s(void*);
extern int IsDebugByInternalPlatformConfig_s(void*);
extern int IsRootChanged(void*);

extern int RefreshPunishTime(void*);
extern int GetPunishTextStr(void*);
extern int OnReportConfirm(void*);
extern int On_InBattleMsg_ReportClick(void*);
extern int On_InBattleMsg_ReportConfirm(void*);
extern int On_InBattleMsg_CancleReport(void*);
extern int NGameChannelResult2ReportType(void*);
extern int reportInfo(void*);
extern int handleReportInfoResult(void*);
extern int reportToTLog(void*);

// === NHÓM 1: Gửi báo cáo / phân tích ===
static int (*orig_Report_s)(void*) = NULL;
static int hook_Report_s(void* ctx) { return 0; }

static int (*orig_ReportToTdm_s)(void*) = NULL;
static int hook_ReportToTdm_s(void* ctx) { return 0; }

static int (*orig_ReportEventByName)(void*) = NULL;
static int hook_ReportEventByName(void* ctx) { return 0; }

static int (*orig_ReportEvent)(void*) = NULL;
static int hook_ReportEvent(void* ctx) { return 0; }

static int (*orig_SecurityCheckReq)(void*) = NULL;
static int hook_SecurityCheckReq(void* ctx) { return 0; }

static int (*orig_Event_CommonReport)(void*) = NULL;
static int hook_Event_CommonReport(void* ctx) { return 0; }

static int (*orig_EventPhotoReport)(void*) = NULL;
static int hook_EventPhotoReport(void* ctx) { return 0; }

// === NHÓM 2: Kiểm tra bảo mật / debug ===
static int (*orig_IsDebug_s)(void*) = NULL;
static int hook_IsDebug_s(void* ctx) { return 0; }

static int (*orig_IsRootChanged)(void*) = NULL;
static int hook_IsRootChanged(void* ctx) { return 0; }

// === NHÓM 3: Xử lý phạt / ban ===
static int (*orig_RefreshPunishTime)(void*) = NULL;
static int hook_RefreshPunishTime(void* ctx) { return 0; }

static int (*orig_OnReportConfirm)(void*) = NULL;
static int hook_OnReportConfirm(void* ctx) { return 0; }

static int (*orig_On_InBattleMsg_ReportConfirm)(void*) = NULL;
static int hook_On_InBattleMsg_ReportConfirm(void* ctx) { return 0; }

static int (*orig_reportInfo)(void*) = NULL;
static int hook_reportInfo(void* ctx) { return 0; }

static int (*orig_handleReportInfoResult)(void*) = NULL;
static int hook_handleReportInfoResult(void* ctx) { return 0; }

// === KHỞI TẠO ===
__attribute__((constructor))
static void AntiBypassInit(void) {
    @autoreleasepool {
        NSLog(@"[AntiBypass] ✅ Đang kích hoạt...");
        
        // Gửi báo cáo → Bỏ qua
        MSHookFunction((void*)&Report_s, (void*)hook_Report_s, (void**)&orig_Report_s);
        MSHookFunction((void*)&ReportToTdm_s, (void*)hook_ReportToTdm_s, (void**)&orig_ReportToTdm_s);
        MSHookFunction((void*)&ReportEventByName, (void*)hook_ReportEventByName, (void**)&orig_ReportEventByName);
        MSHookFunction((void*)&ReportEvent, (void*)hook_ReportEvent, (void**)&orig_ReportEvent);
        MSHookFunction((void*)&SecurityCheckReq, (void*)hook_SecurityCheckReq, (void**)&orig_SecurityCheckReq);
        MSHookFunction((void*)&Event_CommonReport, (void*)hook_Event_CommonReport, (void**)&orig_Event_CommonReport);
        MSHookFunction((void*)&EventPhotoReport, (void*)hook_EventPhotoReport, (void**)&orig_EventPhotoReport);
        
        // Kiểm tra bảo mật → Luôn trả về không phát hiện
        MSHookFunction((void*)&IsDebug_s, (void*)hook_IsDebug_s, (void**)&orig_IsDebug_s);
        MSHookFunction((void*)&IsRootChanged, (void*)hook_IsRootChanged, (void**)&orig_IsRootChanged);
        
        // Xử lý phạt/báo cáo → Không thực thi
        MSHookFunction((void*)&RefreshPunishTime, (void*)hook_RefreshPunishTime, (void**)&orig_RefreshPunishTime);
        MSHookFunction((void*)&OnReportConfirm, (void*)hook_OnReportConfirm, (void**)&orig_OnReportConfirm);
        MSHookFunction((void*)&On_InBattleMsg_ReportConfirm, (void*)hook_On_InBattleMsg_ReportConfirm, (void**)&orig_On_InBattleMsg_ReportConfirm);
        MSHookFunction((void*)&reportInfo, (void*)hook_reportInfo, (void**)&orig_reportInfo);
        MSHookFunction((void*)&handleReportInfoResult, (void*)hook_handleReportInfoResult, (void**)&orig_handleReportInfoResult);
        
        NSLog(@"[AntiBypass] ✅ HOÀN TẤT — Báo cáo & Bảo mật đã bị vô hiệu hóa!");
    }
}
