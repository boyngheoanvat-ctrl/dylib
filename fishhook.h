#ifndef FISHHOOK_H
#define FISHHOOK_H

#include <stddef.h>
#include <mach-o/loader.h>

#ifdef __cplusplus
extern "C" {
#endif

struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

int rebind_symbols(struct rebinding rebindings[], size_t nrebindings);
int rebind_symbols_image(void *header, const char *image_name,
                          struct rebinding rebindings[], size_t nrebindings);

#ifdef __cplusplus
}
#endif

#endif
