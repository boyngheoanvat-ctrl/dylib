#import "fishhook.h"
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <mach/mach.h>
#import <mach-o/nlist.h>
#import <mach-o/reloc.h>

/*
 * Copyright (c) 2013, Facebook, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   * Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *   * Neither the name Facebook nor the names of its contributors may be
 *     used to endorse or promote products derived from this software without
 *     specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if defined(__arm64__) || defined(__aarch64__)
#define __LP64__ 1
#endif

#ifdef __LP64__
#define MACH_HEADER mach_header_64
#define LC_SEGMENT_CMD LC_SEGMENT_64
#else
#define MACH_HEADER mach_header
#define LC_SEGMENT_CMD LC_SEGMENT
#endif

struct rebinding_private {
    const char *name;
    void *replacement;
    void **replaced;
    struct nlist *nl;
};

static const uint32_t INDIRECT_SYMBOL_ABS = 0x40000000;
static const uint32_t INDIRECT_SYMBOL_LOCAL = 0x80000000;

static bool perform_rebinding_with_section(struct rebinding_private *rebindings,
                                           size_t nrebindings,
                                           const struct MACH_HEADER *header,
                                           intptr_t slide,
                                           const struct section_64 *section,
                                           const struct section_64 *section_reloc) {
    if (!section || !section->size) {
        return false;
    }
    
    uint32_t *indirect_symbols = NULL;
    if (section->reserved1 != 0) {
        indirect_symbols = (uint32_t *)((uintptr_t)header + slide + section->reserved1);
    }
    
    struct nlist *symbols = NULL;
    const char *strtab = NULL;
    const struct symtab_command *symtab_cmd = NULL;
    
    const struct load_command *cmd = (const struct load_command *)((uintptr_t)header + sizeof(struct MACH_HEADER));
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (const struct symtab_command *)cmd;
            symbols = (struct nlist *)((uintptr_t)header + slide + symtab_cmd->symoff);
            strtab = (const char *)((uintptr_t)header + slide + symtab_cmd->stroff);
            break;
        }
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
    }
    
    if (!symtab_cmd) {
        return false;
    }
    
    bool success = false;
    if (section->flags & S_NON_LAZY_SYMBOL_POINTERS ||
        section->flags & S_LAZY_SYMBOL_POINTERS ||
        section->flags & S_LAZY_DYLIB_SYMBOL_POINTERS) {
        
        uint32_t symbol_count = (uint32_t)(section->size / sizeof(void *));
        for (uint32_t i = 0; i < symbol_count; i++) {
            uint32_t symbol_index = INDIRECT_SYMBOL_ABS;
            if (indirect_symbols) {
                symbol_index = indirect_symbols[i];
            } else {
                uint32_t *slot = (uint32_t *)((uintptr_t)header + slide + section->reserved1);
                symbol_index = slot[i];
            }
            
            if (symbol_index == INDIRECT_SYMBOL_ABS || symbol_index == INDIRECT_SYMBOL_LOCAL) {
                continue;
            }
            
            const char *symbol_name = strtab + symbols[symbol_index].n_un.n_strx;
            for (size_t j = 0; j < nrebindings; j++) {
                if (rebindings[j].nl && rebindings[j].nl - symbols == symbol_index) {
                    void **symbol_ptr = (void **)((uintptr_t)header + slide + section->addr + i * sizeof(void *));
                    
                    vm_address_t page_start = (vm_address_t)symbol_ptr & ~(vm_page_size - 1);
                    vm_size_t region_size = sizeof(void *);
                    
                    kern_return_t kr = vm_protect(mach_task_self(), page_start,
                        vm_page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
                    if (kr == KERN_SUCCESS) {
                        if (rebindings[j].replaced && !*rebindings[j].replaced) {
                            *rebindings[j].replaced = *symbol_ptr;
                        }
                        *symbol_ptr = rebindings[j].replacement;
                        success = true;
                    }
                    
                    kr = vm_protect(mach_task_self(), page_start,
                        vm_page_size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
                    break;
                }
            }
        }
    }
    return success;
}

int rebind_symbols_image(void *header, const char *image_name,
                          struct rebinding rebindings[], size_t nrebindings) {
    if (!header) {
        return -1;
    }
    
    struct rebinding_private *rebindings_private = calloc(nrebindings, sizeof(struct rebinding_private));
    if (!rebindings_private) {
        return -1;
    }
    
    for (size_t i = 0; i < nrebindings; i++) {
        rebindings_private[i].name = rebindings[i].name;
        rebindings_private[i].replacement = rebindings[i].replacement;
        rebindings_private[i].replaced = rebindings[i].replaced;
        rebindings_private[i].nl = NULL;
    }
    
    const struct MACH_HEADER *mh = (const struct MACH_HEADER *)header;
    intptr_t slide = 0;
    if (image_name) {
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            if (strcmp(_dyld_get_image_name(i), image_name) == 0) {
                mh = (const struct MACH_HEADER *)_dyld_get_image_header(i);
                slide = _dyld_get_image_vmaddr_slide(i);
                break;
            }
        }
    }
    
    const struct symtab_command *symtab_cmd = NULL;
    struct nlist *symbols = NULL;
    const char *strtab = NULL;
    
    const struct load_command *cmd = (const struct load_command *)((uintptr_t)mh + sizeof(struct MACH_HEADER));
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (const struct symtab_command *)cmd;
            symbols = (struct nlist *)((uintptr_t)mh + slide + symtab_cmd->symoff);
            strtab = (const char *)((uintptr_t)mh + slide + symtab_cmd->stroff);
            break;
        }
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
    }
    
    if (!symtab_cmd) {
        free(rebindings_private);
        return -1;
    }
    
    for (uint32_t i = 0; i < symtab_cmd->nsyms; i++) {
        if ((symbols[i].n_type & N_TYPE) == N_SECT && symbols[i].n_sect != NO_SECT) {
            const char *sym_name = strtab + symbols[i].n_un.n_strx;
            for (size_t j = 0; j < nrebindings; j++) {
                if (!rebindings_private[j].nl && strcmp(sym_name, rebindings_private[j].name) == 0) {
                    rebindings_private[j].nl = &symbols[i];
                }
            }
        }
    }
    
    bool success = false;
    cmd = (const struct load_command *)((uintptr_t)mh + sizeof(struct MACH_HEADER));
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (cmd->cmd == LC_SEGMENT_CMD) {
            const struct segment_command_64 *seg_cmd = (const struct segment_command_64 *)cmd;
            const struct section_64 *sect = (const struct section_64 *)((uintptr_t)seg_cmd + sizeof(struct segment_command_64));
            for (uint32_t j = 0; j < seg_cmd->nsects; j++) {
                if (perform_rebinding_with_section(rebindings_private, nrebindings, mh, slide, sect, NULL)) {
                    success = true;
                }
                sect = (const struct section_64 *)((uintptr_t)sect + sizeof(struct section_64));
            }
        }
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
    }
    
    free(rebindings_private);
    return success ? 0 : -1;
}

int rebind_symbols(struct rebinding rebindings[], size_t nrebindings) {
    return rebind_symbols_image(NULL, NULL, rebindings, nrebindings);
}
