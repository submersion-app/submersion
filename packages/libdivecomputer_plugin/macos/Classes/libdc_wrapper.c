#include "libdc_wrapper.h"
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <libdivecomputer/version.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>

#ifdef _WIN32
#define strcasecmp _stricmp
#endif

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

int libdc_descriptor_match(const char *name, unsigned int transport,
                           libdc_descriptor_info_t *info) {
    if (name == NULL || info == NULL) {
        return 0;
    }

    dc_iterator_t *iter = NULL;
    dc_status_t status = dc_descriptor_iterator(&iter);
    if (status != DC_STATUS_SUCCESS || iter == NULL) {
        return 0;
    }

    // Pelagic BLE names are usually 2 letters + serial digits (e.g. FH025918),
    // where the first two letters encode the model id.
    unsigned int name_model = 0;
    int has_name_model = 0;
    if ((transport & LIBDC_TRANSPORT_BLE) && strlen(name) >= 8) {
        unsigned char c0 = (unsigned char)name[0];
        unsigned char c1 = (unsigned char)name[1];
        if (isalpha(c0) && isalpha(c1)) {
            int digits = 0;
            int valid = 1;
            for (size_t i = 2; name[i] != '\0'; i++) {
                unsigned char c = (unsigned char)name[i];
                if (isdigit(c)) {
                    digits++;
                } else if (c == ' ' || c == '-' || c == '_') {
                    continue;
                } else {
                    valid = 0;
                    break;
                }
            }
            if (valid && digits >= 6) {
                c0 = (unsigned char)toupper(c0);
                c1 = (unsigned char)toupper(c1);
                name_model = ((unsigned int)c0 << 8) | (unsigned int)c1;
                has_name_model = 1;
            }
        }
    }

    dc_descriptor_t *desc = NULL;
    int found = 0;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        if (dc_descriptor_filter(desc, (dc_transport_t)transport, name)) {
            // Keep first family-level match as fallback.
            if (!found) {
                info->vendor = dc_descriptor_get_vendor(desc);
                info->product = dc_descriptor_get_product(desc);
                info->model = dc_descriptor_get_model(desc);
                info->transports = dc_descriptor_get_transports(desc);
                found = 1;
            }

            // If model code is present in the BLE name, prefer exact model match.
            if (has_name_model && dc_descriptor_get_model(desc) == name_model) {
                info->vendor = dc_descriptor_get_vendor(desc);
                info->product = dc_descriptor_get_product(desc);
                info->model = dc_descriptor_get_model(desc);
                info->transports = dc_descriptor_get_transports(desc);
                dc_descriptor_free(desc);
                break;
            }

            // For non-Pelagic names (e.g. "Teric", "Perdix 2"), prefer the
            // descriptor whose product name exactly matches the BLE name.
            // Without this, the first family-level match wins (often wrong).
            if (!has_name_model) {
                const char *product = dc_descriptor_get_product(desc);
                if (product && strcasecmp(name, product) == 0) {
                    info->vendor = dc_descriptor_get_vendor(desc);
                    info->product = product;
                    info->model = dc_descriptor_get_model(desc);
                    info->transports = dc_descriptor_get_transports(desc);
                    dc_descriptor_free(desc);
                    break;
                }
            }
        }
        dc_descriptor_free(desc);
    }

    dc_iterator_free(iter);
    return found;
}

int libdc_descriptor_lookup_model(unsigned int transport, unsigned int model,
                                  libdc_descriptor_info_t *info) {
    if (info == NULL) {
        return 0;
    }

    dc_iterator_t *iter = NULL;
    dc_status_t status = dc_descriptor_iterator(&iter);
    if (status != DC_STATUS_SUCCESS || iter == NULL) {
        return 0;
    }

    dc_descriptor_t *desc = NULL;
    int found = 0;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        if ((dc_descriptor_get_transports(desc) & transport) != 0 &&
            dc_descriptor_get_model(desc) == model) {
            info->vendor = dc_descriptor_get_vendor(desc);
            info->product = dc_descriptor_get_product(desc);
            info->model = dc_descriptor_get_model(desc);
            info->transports = dc_descriptor_get_transports(desc);
            found = 1;
            dc_descriptor_free(desc);
            break;
        }

        dc_descriptor_free(desc);
    }

    dc_iterator_free(iter);
    return found;
}

void libdc_parsed_dive_free(libdc_parsed_dive_t *dive) {
    if (dive == NULL) {
        return;
    }
    free(dive->samples);
    free(dive);
}
