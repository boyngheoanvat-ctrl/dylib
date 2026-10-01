// ==================================================
// BYPASS CHỈ HÀM CỐT LÕI — BÁO CÁO / BAN / BẢO MẬT
// ==================================================
#import <Foundation/Foundation.h>
#import <substrate.h>

// === NHÓM 1: Gửi báo cáo / phân tích ===
static int (*orig_Report_s)(void*) = NULL;
static int hook_Report_s(void* ctx) { return 0; }

static int (*orig_ReportError_s)(void*) = NULL;
static int hook_ReportError_s(void* ctx) { return 0; }

static int (*orig_ReportToTdm_s)(void*) = NULL;
static int hook_ReportToTdm_s(void* ctx) { return 0; }

static int (*orig_ReportToTdmEx_s)(void*) = NULL;
static int hook_ReportToTdmEx_s(void* ctx) { return 0; }

static int (*orig_FaaSBrokerReport_s)(void*) = NULL;
static int hook_FaaSBrokerReport_s(void* ctx) { return 0; }

static int (*orig_ReportEventByName)(void*) = NULL;
static int hook_ReportEventByName(void* ctx) { return 0; }

static int (*orig_ReportEvent)(void*) = NULL;
static int hook_ReportEvent(void* ctx) { return 0; }

static int (*orig_ReportPayEvent)(void*) = NULL;
static int hook_ReportPayEvent(void* ctx) { return 0; }

static int (*orig_ApolloReportEvent)(void*) = NULL;
static int hook_ApolloReportEvent(void* ctx) { return 0; }

static int (*orig_SecurityCheckReq)(void*) = NULL;
static int hook_SecurityCheckReq(void* ctx) { return 0; }

static int (*orig_ReportBindEvent)(void*) = NULL;
static int hook_ReportBindEvent(void* ctx) { return 0; }

static int (*orig_Event_CommonReport)(void*) = NULL;
static int hook_Event_CommonReport(void* ctx) { return 0; }

static int (*orig_EventPhotoReport)(void*) = NULL;
static int hook_EventPhotoReport(void* ctx) { return 0; }

// === NHÓM 2: Kiểm tra bảo mật / debug ===
static int (*orig_IsDebug_s)(void*) = NULL;
static int hook_IsDebug_s(void* ctx) { return 0; } // 0 = Không phải debug

static int (*orig_IsDebugByInternalPlatformConfig_s)(void*) = NULL;
static int hook_IsDebugByInternalPlatformConfig_s(void* ctx) { return 0; }

static int (*orig_IsRootChanged)(void*) = NULL;
static int hook_IsRootChanged(void* ctx) { return 0; } // 0 = Không bị root

// === NHÓM 3: Xử lý phạt / ban ===
static int (*orig_RefreshPunishTime)(void*) = NULL;
static int hook_RefreshPunishTime(void* ctx) { return 0; }

static int (*orig_GetPunishTextStr)(void*) = NULL;
static int hook_GetPunishTextStr(void* ctx) { return 0; }

static int (*orig_OnReportConfirm)(void*) = NULL;
static int hook_OnReportConfirm(void* ctx) { return 0; }

static int (*orig_On_InBattleMsg_ReportClick)(void*) = NULL;
static int hook_On_InBattleMsg_ReportClick(void* ctx) { return 0; }

static int (*orig_On_InBattleMsg_ReportConfirm)(void*) = NULL;
static int hook_On_InBattleMsg_ReportConfirm(void* ctx) { return 0; }

static int (*orig_On_InBattleMsg_CancleReport)(void*) = NULL;
static int hook_On_InBattleMsg_CancleReport(void* ctx) { return 0; }

static int (*orig_NGameChannelResult2ReportType)(void*) = NULL;
static int hook_NGameChannelResult2ReportType(void* ctx) { return 0; }

static int (*orig_reportInfo)(void*) = NULL;
static int hook_reportInfo(void* ctx) { return 0; }

static int (*orig_handleReportInfoResult)(void*) = NULL;
static int hook_handleReportInfoResult(void* ctx) { return 0; }

static int (*orig_reportToTLog)(void*) = NULL;
static int hook_reportToTLog(void* ctx) { return 0; }

// === KHỞI TẠO ===
__attribute__((constructor))
static void AntiBypassInit(void) {
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
