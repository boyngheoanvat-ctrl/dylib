#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>
#import "fishhook.h"

// ==============================================
// KHAI BÁO
// ==============================================
typedef void (*VoidFn)(void*);
typedef int  (*IntFn)(void*);

static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;
static int (*orig_access)(const char *, int) = NULL;

// ==============================================
// HÀM ĐỂ TRẢ VỀ
// ==============================================
static int  hk_Zero(void *)  { return 0; }
static void hk_Empty(void *) { }

// ==============================================
// ẨN DẤU VẾT FILE
// ==============================================
static int fake_stat(const char *p, struct stat *s, int is_lstat) {
    int r = is_lstat ? orig_lstat(p, s) : orig_stat(p, s);
    if (r == 0) {
        s->st_mtime = 1720000000;
        s->st_ctime = 1720000000;
    }
    return r;
}
static int hk_stat(const char *p, struct stat *s)  { return fake_stat(p, s, 0); }
static int hk_lstat(const char *p, struct stat *s) { return fake_stat(p, s, 1); }
static int hk_access(const char *p, int m) {
    if (strstr(p, "Bypass") || strstr(p, "patch") || strstr(p, "hack")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(p, m);
}

// ==============================================
// QUÉT TỰ ĐỘNG — TÌM HÀM THEO MẪU
// ==============================================
static void scan_and_hook(void) {
    struct rebinding hooks[128];
    int count = 0;

    // ===== MẪU TÌM KIẾM — TỰ ĐỘNG BẮT TẤT CẢ =====
    const char *patterns[] = {
        "IsDebug", "IsRoot", "CheckDebug", "CheckRoot",
        "Report", "SecurityCheck", "Verify", "Integrity",
        "CheckModified", "GetDeviceStatus", "AntiCheat",
        "BanCheck", "Detect", "Tamper", NULL
    };

    // Duyệt TẤT CẢ ảnh đã nạp
    uint32_t img_count = _dyld_image_count();
    for (uint32_t img_idx = 0; img_idx < img_count; img_idx++) {
        const struct mach_header *hdr = _dyld_get_image_header(img_idx);
        if (!hdr) continue;
        
        // Chỉ quét ảnh chính của game
        const char *img_name = _dyld_get_image_name(img_idx);
        if (!img_name || !strstr(img_name, ".app")) continue;

        uintptr_t slide = _dyld_get_image_vmaddr_slide(img_idx);
        uintptr_t cur = (uintptr_t)hdr + sizeof(struct mach_header);
        
        // Duyệt tất cả load command để tìm bảng ký hiệu
        uint32_t ncmds = hdr->ncmds;
        for (uint32_t i = 0; i < ncmds; i++) {
            const struct load_command *cmd = (const struct load_command *)cur;
            
            if (cmd->cmd == LC_SYMTAB) {
                const struct symtab_command *symtab = (const struct symtab_command *)cmd;
                const struct nlist_64 *nl = (const struct nlist_64 *)
                    ((uintptr_t)hdr + slide + symtab->symoff);
                const char *strtab = (const char *)
                    ((uintptr_t)hdr + slide + symtab->stroff);
                
                // Duyệt tất cả ký hiệu
                for (uint32_t j = 0; j < symtab->nsyms; j++) {
                    if ((nl[j].n_type & N_TYPE) == N_UNDF && nl[j].n_value) {
                        const char *name = strtab + nl[j].n_un.n_strx;
                        
                        // Bỏ qua nếu không phải hàm C
                        if (name[0] != '_') continue;
                        
                        // Kiểm tra có khớp mẫu nào không
                        for (int p = 0; patterns[p]; p++) {
                            if (strcasestr(name, patterns[p])) {
                                void *addr = (void *)(nl[j].n_value + slide);
                                
                                // Xác định kiểu hàm theo tên
                                int isIntReturn = 0;
                                if (strstr(name, "Is") || strstr(name, "Check") || 
                                    strstr(name, "Verify") || strstr(name, "Detect")) {
                                    isIntReturn = 1;
                                }
                                
                                // Thêm vào danh sách hook
                                hooks[count].name = name;
                                hooks[count].replacement = isIntReturn ? (void*)hk_Zero : (void*)hk_Empty;
                                hooks[count].replaced = NULL;
                                count++;
                                
                                if (count >= 120) goto done; // Đủ rồi
                                break;
                            }
                        }
                    }
                }
            }
            cur += cmd->cmdsize;
        }
    }
done:
    // Thực hiện hook tất cả cùng lúc
    if (count > 0) {
        rebind_symbols(hooks, count);
    }
}

// ==============================================
// KHỞI ĐỘNG
// ==============================================
__attribute__((constructor(101)))
static void AutoStart(void) {
    @autoreleasepool {
        // Xóa dấu vết môi trường
        unsetenv("DYLD_INSERT_LIBRARIES");
        unsetenv("DYLD_LIBRARY_PATH");
        unsetenv("DYLD_FALLBACK_LIBRARY_PATH");

        // Hook hệ thống ẩn dấu vết
        struct rebinding sys[] = {
            {"stat",   (void*)hk_stat,   (void**)&orig_stat},
            {"lstat",  (void*)hk_lstat,  (void**)&orig_lstat},
            {"access", (void*)hk_access, (void**)&orig_access},
        };
        rebind_symbols(sys, sizeof(sys)/sizeof(sys[0]));

        // Tự quét & hook tự động
        scan_and_hook();
    }
}
