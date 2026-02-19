#include "libdc_wrapper.h"
#include <stddef.h>
#include <libdivecomputer/version.h>

const char *libdc_get_version(void) {
    return dc_version(NULL);
}
