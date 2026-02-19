#include "libdc_wrapper.h"
#include <stddef.h>
#include <stdlib.h>
#include <libdivecomputer/version.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>

const char *libdc_get_version(void) {
    return dc_version(NULL);
}

// Internal iterator state.
struct libdc_descriptor_iterator {
    dc_iterator_t *dc_iter;
    dc_descriptor_t *current;  // current descriptor (freed on next/free)
};

libdc_descriptor_iterator_t *libdc_descriptor_iterator_new(void) {
    dc_iterator_t *dc_iter = NULL;
    dc_status_t status = dc_descriptor_iterator(&dc_iter);
    if (status != DC_STATUS_SUCCESS || dc_iter == NULL) {
        return NULL;
    }

    libdc_descriptor_iterator_t *iter = malloc(sizeof(libdc_descriptor_iterator_t));
    if (iter == NULL) {
        dc_iterator_free(dc_iter);
        return NULL;
    }
    iter->dc_iter = dc_iter;
    iter->current = NULL;
    return iter;
}

int libdc_descriptor_iterator_next(libdc_descriptor_iterator_t *iter,
                                   libdc_descriptor_info_t *info) {
    if (iter == NULL || info == NULL) {
        return -1;
    }

    // Free the previous descriptor.
    if (iter->current != NULL) {
        dc_descriptor_free(iter->current);
        iter->current = NULL;
    }

    dc_descriptor_t *desc = NULL;
    dc_status_t status = dc_iterator_next(iter->dc_iter, &desc);
    if (status != DC_STATUS_SUCCESS) {
        return 1;  // done
    }

    iter->current = desc;
    info->vendor = dc_descriptor_get_vendor(desc);
    info->product = dc_descriptor_get_product(desc);
    info->model = dc_descriptor_get_model(desc);
    info->transports = dc_descriptor_get_transports(desc);
    return 0;
}

void libdc_descriptor_iterator_free(libdc_descriptor_iterator_t *iter) {
    if (iter == NULL) {
        return;
    }
    if (iter->current != NULL) {
        dc_descriptor_free(iter->current);
    }
    dc_iterator_free(iter->dc_iter);
    free(iter);
}
