#include "fishhook.h"
#include <dlfcn.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <mach-o/dyld.h>
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

#ifndef INDIRECT_SYMBOL_ABS
#define INDIRECT_SYMBOL_ABS 0x40000000
#endif
#ifndef INDIRECT_SYMBOL_LOCAL
#define INDIRECT_SYMBOL_LOCAL 0x80000000
#endif

static bool rebind_symbols_for_image(const mach_header_t *header,
                                      intptr_t slide,
                                      struct rebinding rebindings[],
                                      size_t rebindings_nel) {
    const segment_command_t *linkedit_segment = NULL;
    const struct symtab_command *symtab_cmd = NULL;
    const struct dysymtab_command *dysymtab_cmd = NULL;
    const section_t *nl_symbol_ptr = NULL;
    const section_t *la_symbol_ptr = NULL;

    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *cmd = (const struct load_command *)cur;
        if (cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            const segment_command_t *seg = (const segment_command_t *)cmd;
            if (strcmp(seg->segname, "__LINKEDIT") == 0) {
                linkedit_segment = seg;
            } else if (strcmp(seg->segname, "__DATA") == 0 || strcmp(seg->segname, "__DATA_CONST") == 0) {
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

    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment ||
        !dysymtab_cmd->indirectsymoff || (!nl_symbol_ptr && !la_symbol_ptr)) {
        return false;
    }

    uintptr_t linkedit_base = (uintptr_t)header + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    const nlist_t *symtab = (const nlist_t *)(linkedit_base + symtab_cmd->symoff);
    const char *strtab = (const char *)(linkedit_base + symtab_cmd->stroff);
    const uint32_t *indirect_symtab = (const uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

    const uint32_t *indirect_syms = NULL;
    uint32_t num_indirect_syms = 0;
    if (la_symbol_ptr) {
        indirect_syms = (const uint32_t *)((uintptr_t)header + slide + la_symbol_ptr->addr);
        num_indirect_syms = la_symbol_ptr->size / sizeof(uint32_t);
    }
    if (!indirect_syms && nl_symbol_ptr) {
        indirect_syms = (const uint32_t *)((uintptr_t)header + slide + nl_symbol_ptr->addr);
        num_indirect_syms = nl_symbol_ptr->size / sizeof(uint32_t);
    }
    if (!indirect_syms) return false;

    bool did_rebind = false;
    for (uint32_t i = 0; i < num_indirect_syms; i++) {
        uint32_t sym_idx = indirect_symtab[indirect_syms[i] & 0xFFFFFF];
        if (sym_idx == INDIRECT_SYMBOL_ABS || sym_idx == INDIRECT_SYMBOL_LOCAL ||
            sym_idx == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        const nlist_t *sym = &symtab[sym_idx];
        if (sym->n_type & N_STAB) continue;
        if ((sym->n_type & N_TYPE) != N_UNDF || !(sym->n_desc & N_WEAK_REF)) continue;
        const char *sym_name = strtab + sym->n_un.n_strx;
        for (size_t j = 0; j < rebindings_nel; j++) {
            if (strcmp(sym_name, rebindings[j].name) == 0) {
                uintptr_t *fn_ptr = (uintptr_t *)((uintptr_t)header + slide +
                    (la_symbol_ptr ? la_symbol_ptr->addr : nl_symbol_ptr->addr) +
                    i * sizeof(uintptr_t));
                if (*fn_ptr != (uintptr_t)rebindings[j].replacement) {
                    if (rebindings[j].replaced)
                        *rebindings[j].replaced = (void *)*fn_ptr;
                    *fn_ptr = (uintptr_t)rebindings[j].replacement;
                    did_rebind = true;
                }
            }
        }
    }
    return did_rebind;
}

int rebind_symbols(struct rebinding rebindings[], size_t n) {
    int r = 0;
    uint32_t c = _dyld_image_count();
    for (uint32_t i = 0; i < c; i++) {
        const mach_header_t *h = (const mach_header_t *)_dyld_get_image_header(i);
        if (rebind_symbols_for_image(h, _dyld_get_image_vmaddr_slide(i), rebindings, n))
            r = 1;
    }
    return r;
}
