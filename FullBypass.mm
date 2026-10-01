#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>
#import "fishhook.h"

// ==============================================
// HÀM TRẢ VỀ
// ==============================================
static int  hk_ReturnZero(void *)  { return 0; }
static void hk_ReturnEmpty(void *) { }

// ==============================================
// BIẾN TOÀN CỤC HỆ THỐNG
// ==============================================
static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;
static int (*orig_access)(const char *, int) = NULL;

// ==============================================
// ẨN DẤU VẾT FILE
// ==============================================
static int fake_file_info(const char *path, struct stat *st, int use_lstat) {
    int r = use_lstat ? orig_lstat(path, st) : orig_stat(path, st);
    if (r == 0) {
        st->st_mtime = 1720000000;
        st->st_ctime = 1720000000;
    }
    return r;
}

static int hk_stat(const char *p, struct stat *s) {
    return fake_file_info(p, s, 0);
}
static int hk_lstat(const char *p, struct stat *s) {
    return fake_file_info(p, s, 1);
}
static int hk_access(const char *p, int m) {
    if (strstr(p, "Bypass") || strstr(p, "patch") || strstr(p, "hack") ||
        strstr(p, "cheat") || strstr(p, "mod")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(p, m);
}

// ==============================================
// TỰ QUÉT & HOOK TẤT CẢ HÀM PHÙ HỢP
// ==============================================
static void auto_scan_and_hook(void) {
    struct rebinding hooks[128];
    int count = 0;

    // Từ khóa bao phủ toàn bộ hệ thống chống gian lận
    const char *patterns[] = {
        "IsDebug", "IsRoot", "CheckDebug", "CheckRoot",
        "Report", "SecurityCheck", "Verify", "Integrity",
        "CheckModified", "GetDeviceStatus", "AntiCheat",
        "BanCheck", "Detect", "Tamper", "Signature",
        "HashCheck", "FileCheck", "BuildCheck", "ClientCheck",
        "Patch", "Modified", "Alter", "Unauth", "Spoof",
        "DyldCheck", "LibCheck", "DylibCheck", "Inspect",
        "EnvironmentCheck", "ProcCheck", "MemoryCheck",
        "Telemetry", "StatReport", "UploadLog", "Audit",
        NULL
    };

    uint32_t img_count = _dyld_image_count();
    for (uint32_t img_idx = 0; img_idx < img_count; img_idx++) {
        const struct mach_header *hdr = _dyld_get_image_header(img_idx);
        if (!hdr) continue;

        const char *img_name = _dyld_get_image_name(img_idx);
        if (!img_name || !strstr(img_name, ".app")) continue;

        uintptr_t slide = _dyld_get_image_vmaddr_slide(img_idx);
        uintptr_t cur = (uintptr_t)hdr + sizeof(struct mach_header);
        uint32_t ncmds = hdr->ncmds;

        for (uint32_t i = 0; i < ncmds; i++) {
            const struct load_command *cmd = (const struct load_command *)cur;

            if (cmd->cmd == LC_SYMTAB) {
                const struct symtab_command *symtab = (const struct symtab_command *)cmd;
                const struct nlist_64 *nl = (const struct nlist_64 *)
                    ((uintptr_t)hdr + slide + symtab->symoff);
                const char *strtab = (const char *)
                    ((uintptr_t)hdr + slide + symtab->stroff);

                for (uint32_t j = 0; j < symtab->nsyms; j++) {
                    if ((nl[j].n_type & N_TYPE) == N_UNDF && nl[j].n_value) {
                        const char *name = strtab + nl[j].n_un.n_strx;
                        if (!name || name[0] != '_') continue;

                        for (int p = 0; patterns[p]; p++) {
                            if (strcasestr(name, patterns[p])) {
                                int returnZero = strstr(name, "Is") || strstr(name, "Check") ||
                                                strstr(name, "Verify") || strstr(name, "Detect") ||
                                                strstr(name, "Has") || strstr(name, "Get");

                                hooks[count++] = (struct rebinding){
                                    name,
                                    returnZero ? (void*)hk_ReturnZero : (void*)hk_ReturnEmpty,
                                    NULL
                                };
                                if (count >= 120) goto scan_done;
                                break;
                            }
                        }
                    }
                }
            }
            cur += cmd->cmdsize;
        }
    }
scan_done:
    if (count > 0) {
        rebind_symbols(hooks, count);
    }
}

// ==============================================
// KHỞI ĐỘNG — CHẠY NGAY KHI NẠP
// ==============================================
__attribute__((constructor(101)))
static void AutoStartBypass(void) {
    @autoreleasepool {
        // Bước 1: Xóa ngay dấu vết môi trường
        unsetenv("DYLD_INSERT_LIBRARIES");
        unsetenv("DYLD_LIBRARY_PATH");
        unsetenv("DYLD_FALLBACK_LIBRARY_PATH");

        // Bước 2: Hook hệ thống — ẩn dấu vết file
        struct rebinding sys_hooks[] = {
            {"stat",   (void*)hk_stat,   (void**)&orig_stat},
            {"lstat",  (void*)hk_lstat,  (void**)&orig_lstat},
            {"access", (void*)hk_access, (void**)&orig_access},
        };
        rebind_symbols(sys_hooks, sizeof(sys_hooks)/sizeof(sys_hooks[0]));

        // Bước 3: Tự động quét & hook toàn bộ hàm bảo mật
        auto_scan_and_hook();
    }
}
