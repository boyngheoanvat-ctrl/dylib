#include "fishhook.h"
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <mach/mach.h>

#ifdef __LP64__
#define MACH_HEADER mach_header_64
#define LC_SEGMENT_CMD LC_SEGMENT_64
#else
#define MACH_HEADER mach_header
#define LC_SEGMENT_CMD LC_SEGMENT
#endif

static const uint32_t DYLD_EXTRA_FLAGS_SLOT = 1;
static const uint32_t DYLD_BIND_AT_LAUNCH = 0x00000001;

struct segment {
    const struct segment_command *cmd;
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    const uint8_t *contents;
};

struct symtab {
    const struct symtab_command *cmd;
    const char *strtab;
    const struct nlist *symbols;
    uint32_t nsyms;
};

static bool find_segment(const struct MACH_HEADER *header, const char *segname, struct segment *seg) {
    const struct load_command *cmd = (const struct load_command *)((uintptr_t)header + sizeof(struct MACH_HEADER));
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_SEGMENT_CMD) {
            const struct segment_command_64 *segcmd = (const struct segment_command_64 *)cmd;
            if (strcmp(segcmd->segname, segname) == 0) {
                seg->cmd = cmd;
                seg->vmaddr = segcmd->vmaddr;
                seg->vmsize = segcmd->vmsize;
                seg->fileoff = segcmd->fileoff;
                return true;
            }
        }
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
    }
    return false;
}

static bool find_symtab(const struct MACH_HEADER *header, struct symtab *symtab) {
    const struct load_command *cmd = (const struct load_command *)((uintptr_t)header + sizeof(struct MACH_HEADER));
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_SYMTAB) {
            const struct symtab_command *st = (const struct symtab_command *)cmd;
            symtab->cmd = st;
            symtab->strtab = (const char *)((uintptr_t)header + st->stroff);
            symtab->symbols = (const struct nlist *)((uintptr_t)header + st->symoff);
            symtab->nsyms = st->nsyms;
            return true;
        }
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
    }
    return false;
}

static void *symbol_addr(const struct MACH_HEADER *header, const char *name) {
    struct symtab st;
    if (!find_symtab(header, &st)) return NULL;
    for (uint32_t i = 0; i < st.nsyms; i++) {
        if ((st.symbols[i].n_type & N_TYPE) == N_SECT && st.symbols[i].n_sect != NO_SECT) {
            const char *symname = st.strtab + st.symbols[i].n_un.n_strx;
            if (strcmp(symname, name) == 0) {
                return (void *)(uintptr_t)st.symbols[i].n_value;
            }
        }
    }
    return NULL;
}

int rebind_symbols_image(void *header, const char *image_name,
                          struct rebinding rebindings[], size_t nrebindings) {
    if (!header) return -1;
    
    for (size_t i = 0; i < nrebindings; i++) {
        void *addr = dlsym(RTLD_DEFAULT, rebindings[i].name);
        if (!addr) continue;
        
        if (rebindings[i].replaced) {
            *rebindings[i].replaced = addr;
        }
        
        vm_size_t page_size = vm_page_size;
        vm_address_t page_start = (vm_address_t)addr & ~(page_size - 1);
        vm_size_t region_size = sizeof(void *);
        
        kern_return_t kr = vm_protect(mach_task_self(), page_start,
            page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr != KERN_SUCCESS) continue;
        
        memcpy(addr, &rebindings[i].replacement, sizeof(void *));
        
        kr = vm_protect(mach_task_self(), page_start,
            page_size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    }
    return 0;
}

int rebind_symbols(struct rebinding rebindings[], size_t nrebindings) {
    uint32_t image_count = _dyld_image_count();
    for (uint32_t i = 0; i < image_count; i++) {
        const char *name = _dyld_get_image_name(i);
        const struct mach_header *hdr = _dyld_get_image_header(i);
        if (hdr) {
            rebind_symbols_image((void *)hdr, name, rebindings, nrebindings);
        }
    }
    return 0;
}
