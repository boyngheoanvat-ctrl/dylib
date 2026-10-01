#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import "fishhook.h"

// ==============================================
// BIẾN TOÀN CỤC
// ==============================================
static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;
static int (*orig_access)(const char *, int) = NULL;

// ==============================================
// ẨN DẤU VẾT — KHÔNG CHO THẤY FILE BỊ SỬA
// ==============================================
static int fake_stat(const char *path, struct stat *st, int use_lstat) {
    int r = use_lstat ? orig_lstat(path, st) : orig_stat(path, st);
    if (r == 0) {
        // Giữ nguyên thông tin, không để dấu vết
        st->st_mtime = 1720000000;
        st->st_ctime = 1720000000;
    }
    return r;
}

static int hk_stat(const char *p, struct stat *s) {
    return fake_stat(p, s, 0);
}
static int hk_lstat(const char *p, struct stat *s) {
    return fake_stat(p, s, 1);
}
static int hk_access(const char *p, int m) {
    if (strstr(p, "Bypass") || strstr(p, "patch") || strstr(p, "hack")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(p, m);
}

// ==============================================
// CHẶN KIỂM TRA AN NINH
// ==============================================
static int  hk_Zero(void *)  { return 0; }
static void hk_Empty(void *) { }

// ==============================================
// NẠP — XÓA DẤU VẾT NGAY LẬP TỨC
// ==============================================
__attribute__((constructor(101)))
static void StartBypass(void) {
    @autoreleasepool {
        // Bước 1: Xóa biến môi trường — dấu vết số 1
        unsetenv("DYLD_INSERT_LIBRARIES");
        unsetenv("DYLD_LIBRARY_PATH");
        unsetenv("DYLD_FALLBACK_LIBRARY_PATH");

        // Bước 2: Hook hệ thống — ẩn dấu vết file
        struct rebinding sys_hooks[] = {
            {"stat",    (void*)hk_stat,   (void**)&orig_stat},
            {"lstat",   (void*)hk_lstat,  (void**)&orig_lstat},
            {"access",  (void*)hk_access, (void**)&orig_access},
        };
        rebind_symbols(sys_hooks, sizeof(sys_hooks)/sizeof(sys_hooks[0]));

        // Bước 3: Hook kiểm tra an ninh — chỉ khi TÌM THẤY
        struct rebinding game_hooks[32];
        int n = 0;

        #define HOOK_IF_FOUND(name, fn) do { \
            if (dlsym(RTLD_DEFAULT, name)) { \
                game_hooks[n++] = (struct rebinding){name, (void*)fn, NULL}; \
            } \
        } while(0)

        // === Các hàm thường gặp trong Garena/AOV ===
        HOOK_IF_FOUND("_IsDebug_s",         hk_Zero);
        HOOK_IF_FOUND("_IsRootChanged",     hk_Zero);
        HOOK_IF_FOUND("_Report_s",          hk_Empty);
        HOOK_IF_FOUND("_ReportEvent",       hk_Empty);
        HOOK_IF_FOUND("_ReportToTdm_s",     hk_Empty);
        HOOK_IF_FOUND("_SecurityCheckReq",  hk_Empty);
        HOOK_IF_FOUND("_CheckIntegrity",    hk_Empty);
        HOOK_IF_FOUND("_VerifySignature",   hk_Empty);
        HOOK_IF_FOUND("_CheckModified",     hk_Zero);
        HOOK_IF_FOUND("_GetDeviceStatus",   hk_Zero);

        // === Thêm hàm khác khi biết tên chính xác ===
        // HOOK_IF_FOUND("tên_hàm_chính_xác", hk_Empty);

        if (n > 0) rebind_symbols(game_hooks, n);

        // Bước 4: Xóa con trỏ — không để tham chiếu
        orig_stat = orig_lstat = orig_access = NULL;
    }
}
