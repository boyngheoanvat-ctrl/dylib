#include "fishhook.h"
#include <dlfcn.h>
#include <string.h>
#include <stdint.h>
#include <mach-o/dyld_images.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

static bool fishhook_rebind_symbols_for_image(const struct mach_header_t *header,
                                              intptr_t slide,
                                              struct rebinding rebindings[],
                                              size_t n) {
    const uint64_t text_base = 0;
    const segment_command_t *linkedit_segment = NULL;
    const struct symtab_command *symtab_cmd = NULL;
    const struct dysymtab_command *dysymtab_cmd = NULL;
    const segment_command_t *data_segment = NULL;
    const section_t *nl_symbol_ptr = NULL;
    const section_t *la_symbol_ptr = NULL;

    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *cmd = (const struct load_command *)cur;
        if (cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            const segment_command_t *seg = (const segment_command_t *)cmd;
            if (strcmp(seg->segname, "__LINKEDIT") == 0) {
                linkedit_segment = seg;
            } else if (strcmp(seg->segname, "__DATA") == 0) {
                data_segment = seg;
                const uint8_t *sect_ptr = (const uint8_t *)(seg + 1);
                for (uint32_t j = 0; j < seg->nsects; j++) {
                    const section_t *sect = (const section_t *)sect_ptr;
                    if (strcmp(sect->sectname, "__nl_symbol_ptr") == 0) {
                        nl_symbol_ptr = sect;
                    } else if (strcmp(sect->sectname, "__la_symbol_ptr") == 0) {
                        la_symbol_ptr = sect;
                    }
                    sect_ptr += sizeof(section_t);
                }
            }
        } else if (cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (const struct symtab_command *)cmd;
        } else if (cmd->cmd == LC_DYSYMTAB) {
            dysymtab_cmd = (const struct dysymtab_command *)cmd;
        }
        cur += cmd->cmdsize;
    }

    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment || !data_segment ||
        (!nl_symbol_ptr && !la_symbol_ptr)) {
        return false;
    }

    uintptr_t linkedit_base = (uintptr_t)linkedit_segment->vmaddr - linkedit_segment->fileoff;
    const nlist_t *symtab = (const nlist_t *)((uintptr_t)header + linkedit_base + symtab_cmd->symoff);
    const char *strtab = (const char *)((uintptr_t)header + linkedit_base + symtab_cmd->stroff);

    const uint32_t *indirect_syms = NULL;
    uint32_t indirect_syms_count = 0;
    if (la_symbol_ptr) {
        indirect_syms_count = la_symbol_ptr->size / sizeof(uint32_t);
        indirect_syms = (const uint32_t *)((uintptr_t)header + slide + la_symbol_ptr->address);
    }
    if (!indirect_syms && nl_symbol_ptr) {
        indirect_syms_count = nl_symbol_ptr->size / sizeof(uint32_t);
        indirect_syms = (const uint32_t *)((uintptr_t)header + slide + nl_symbol_ptr->address);
    }
    if (!indirect_syms) return false;

    bool found = false;
    for (uint32_t i = 0; i < indirect_syms_count; i++) {
        uint32_t sym_idx = indirect_syms[i];
        if (sym_idx == INDIRECT_SYMBOL_ABS || sym_idx == INDIRECT_SYMBOL_LOCAL ||
            sym_idx == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        const nlist_t *sym = &symtab[sym_idx];
        if (sym->n_type & N_STAB) continue;
        if ((sym->n_type & N_TYPE) != N_UNDF || !(sym->n_desc & N_WEAK_REF)) continue;
        const char *name = strtab + sym->n_un.n_strx;
        for (size_t j = 0; j < n; j++) {
            if (strcmp(name, rebindings[j].name) == 0) {
                uintptr_t *addr = (uintptr_t *)((uintptr_t)header + slide +
                    (la_symbol_ptr ? la_symbol_ptr->address : nl_symbol_ptr->address) +
                    i * sizeof(uintptr_t));
                if (*addr != (uintptr_t)rebindings[j].replacement) {
                    if (rebindings[j].replaced) {
                        *rebindings[j].replaced = (void *)*addr;
                    }
                    *addr = (uintptr_t)rebindings[j].replacement;
                    found = true;
                }
            }
        }
    }
    return found;
}

int rebind_symbols(struct rebinding rebindings[], size_t n) {
    uint32_t img_count = _dyld_image_count();
    int success = 0;
    for (uint32_t i = 0; i < img_count; i++) {
        const mach_header_t *hdr = (const mach_header_t *)_dyld_get_image_header(i);
        if (fishhook_rebind_symbols_for_image(hdr, _dyld_get_image_vmaddr_slide(i), rebindings, n)) {
            success = 1;
        }
    }
    return success;
}
