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
static int  retZero(void *)  { return 0; }
static void retEmpty(void *) { }

// ==============================================
// ẨN DẤU VẾT HỆ THỐNG
// ==============================================
static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;
static int (*orig_access)(const char *, int) = NULL;

static int fakeFile(const char *p, struct stat *s, int isLstat) {
    int r = isLstat ? orig_lstat(p, s) : orig_stat(p, s);
    if (r == 0) {
        s->st_mtime = 1720000000;
        s->st_ctime = 1720000000;
    }
    return r;
}
static int hk_stat(const char *p, struct stat *s)   { return fakeFile(p, s, 0); }
static int hk_lstat(const char *p, struct stat *s)  { return fakeFile(p, s, 1); }
static int hk_access(const char *p, int m) {
    if (strstr(p, "liberi") || strstr(p, "Bypass") || strstr(p, "patch") ||
        strstr(p, "hack") || strstr(p, "cheat") || strstr(p, "mod")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(p, m);
}

// ==============================================
// TỰ QUÉT TẤT CẢ HÀM BẢO MẬT
// ==============================================
static void scanAndHook(void) {
    struct rebinding hooks[128];
    int count = 0;

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
        "wukong", "CheckIPA", "SignatureCheck", "CertCheck",
        NULL
    };

    uint32_t imgCount = _dyld_image_count();
    for (uint32_t i = 0; i < imgCount; i++) {
        const struct mach_header *hdr = _dyld_get_image_header(i);
        if (!hdr) continue;
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName || !strstr(imgName, ".app")) continue;

        uintptr_t slide = _dyld_get_image_vmaddr_slide(i);
        uintptr_t cur = (uintptr_t)hdr + sizeof(struct mach_header);
        uint32_t ncmds = hdr->ncmds;

        for (uint32_t j = 0; j < ncmds; j++) {
            const struct load_command *cmd = (const struct load_command *)cur;
            if (cmd->cmd == LC_SYMTAB) {
                const struct symtab_command *st = (const struct symtab_command *)cmd;
                const struct nlist_64 *nl = (const struct nlist_64 *)
                    ((uintptr_t)hdr + slide + st->symoff);
                const char *strtab = (const char *)
                    ((uintptr_t)hdr + slide + st->stroff);

                for (uint32_t k = 0; k < st->nsyms; k++) {
                    if ((nl[k].n_type & N_TYPE) == N_UNDF && nl[k].n_value) {
                        const char *sym = strtab + nl[k].n_un.n_strx;
                        if (!sym || sym[0] != '_') continue;

                        for (int p = 0; patterns[p]; p++) {
                            if (strcasestr(sym, patterns[p])) {
                                int retZero = strstr(sym, "Is") || strstr(sym, "Check") ||
                                              strstr(sym, "Verify") || strstr(sym, "Detect") ||
                                              strstr(sym, "Has") || strstr(sym, "Get");
                                hooks[count++] = (struct rebinding){
                                    sym,
                                    retZero ? (void*)retZero : (void*)retEmpty,
                                    NULL
                                };
                                if (count >= 120) goto scanDone;
                                break;
                            }
                        }
                    }
                }
            }
            cur += cmd->cmdsize;
        }
    }
scanDone:
    if (count > 0) rebind_symbols(hooks, count);
}

// ==============================================
// KHỞI ĐỘNG NGAY KHI NẠP
// ==============================================
__attribute__((constructor(101)))
static void AutoStart(void) {
    @autoreleasepool {
        // Xóa dấu vết môi trường NGAY LẬP TỨC
        unsetenv("DYLD_INSERT_LIBRARIES");
        unsetenv("DYLD_LIBRARY_PATH");
        unsetenv("DYLD_FALLBACK_LIBRARY_PATH");

        // Hook hệ thống ẩn dấu vết file
        struct rebinding sysHooks[] = {
            {"stat",   (void*)hk_stat,   (void**)&orig_stat},
            {"lstat",  (void*)hk_lstat,  (void**)&orig_lstat},
            {"access", (void*)hk_access, (void**)&orig_access},
        };
        rebind_symbols(sysHooks, sizeof(sysHooks)/sizeof(sysHooks[0]));

        // Tự quét & hook toàn bộ hàm bảo mật
        scanAndHook();
    }
}
