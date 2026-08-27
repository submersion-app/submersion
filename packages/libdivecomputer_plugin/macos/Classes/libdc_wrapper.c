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

// ============================================================
// Log Callback Storage
// ============================================================

libdc_log_callback_fn g_log_callback = NULL;
void *g_log_userdata = NULL;

void libdc_set_log_callback(libdc_log_callback_fn callback, void *userdata) {
    g_log_callback = callback;
    g_log_userdata = userdata;
}

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

// Case-insensitive, space-insensitive compare (ASCII ' ' only; tabs and
// newlines are not ignored — they don't appear in BLE advertised names or
// libdivecomputer product strings). BLE advertised names sometimes omit
// spaces that the libdivecomputer product name includes (e.g. "Puck4" vs
// "Puck 4", "Quad2" vs "Quad 2"), so a plain strcasecmp misses the
// exact-product tiebreaker and the matcher falls back to the first
// family-level descriptor (usually the wrong model).
static int strcasecmp_nospace(const char *a, const char *b) {
    while (*a || *b) {
        while (*a == ' ') a++;
        while (*b == ' ') b++;
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return 1;
        }
        if (*a) a++;
        if (*b) b++;
    }
    return 0;
}

// Number of NON-SPACE characters of `product` matched as a space/case-
// insensitive PREFIX of `name`, or 0 when `name` does not start with the
// whole product (or the match ends mid-word in `name`). Spaces are skipped
// in both strings and do not count, so the score compares like for like
// across spacing variants ("OSTC 4" and "OSTC4" both score 5) and stays
// usable as a longest-match tiebreaker. Some vendors append a serial to
// the advertised BLE name (e.g. an OSTC4 advertising "OSTC4 12345"):
// dc_filter_hw accepts any "OSTC*" name for EVERY hw_ostc3-family
// descriptor and the exact-name tiebreaker cannot bridge the suffix, so
// the first family row ("OSTC 2") used to win. Issue #590.
static size_t product_prefix_len(const char *name, const char *product) {
    const char *a = name;
    const char *b = product;
    size_t matched = 0;
    while (1) {
        while (*a == ' ') a++;
        while (*b == ' ') b++;
        if (*b == '\0') break;
        if (*a == '\0' ||
            tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return 0;
        }
        a++;
        b++;
        matched++;
    }
    // The name must not continue with a letter: "OSTC 2 TR..." is not a
    // prefix match for "OSTC 2" (the longer product row should win).
    while (*a == ' ') a++;
    if (isalpha((unsigned char)*a)) {
        return 0;
    }
    return matched;
}

// Some Scubapro/Uwatec dive computers advertise a short BLE name that differs
// from the libdivecomputer product string. dc_filter_uwatec matches each such
// alias against EVERY Uwatec/Scubapro descriptor, so the family-level fallback
// in libdc_descriptor_match reports the first one ("Aladin Sport Matrix",
// model 0x17) for all of them. strcasecmp_nospace can't bridge the gap because
// the alias is not just a spacing variant of the product (e.g. "HUD" vs
// "G2 HUD", "Galileo 3" vs "G3"). Map the known aliases to their specific
// model code so the exact-model preference in the matcher picks the right
// descriptor. The alias strings are exactly the BLE names from
// dc_filter_uwatec's match list; the model codes are from descriptor.c.
// Regression for issue #285 (G2 HUD advertised as "HUD"). Returns 0 (not a
// valid model in the table) when the name is not a known alias.
static unsigned int uwatec_ble_alias_model(const char *name) {
    static const struct {
        const char *alias;
        unsigned int model;
    } aliases[] = {
        {"HUD", 0x42},       // G2 HUD
        {"Galileo 3", 0x34}, // G3
        {"A1", 0x25},        // Aladin A1
        {"A2", 0x28},        // Aladin A2
    };
    if (name == NULL) {
        return 0;
    }
    for (size_t i = 0; i < sizeof(aliases) / sizeof(aliases[0]); i++) {
        if (strcasecmp_nospace(name, aliases[i].alias) == 0) {
            return aliases[i].model;
        }
    }
    return 0;
}

// Some dive computers advertise an ABBREVIATED BLE name that is neither the
// libdivecomputer product string nor a prefix of it, so neither the exact-name
// nor the longest-prefix tiebreaker below can reach the right descriptor. The
// Uwatec aliases above solve the same problem by model code, but that only
// works where the models differ: every hw_ostc3 descriptor except OSTC 4 and
// OSTC 5 carries model 0, so a Heinrichs Weikamp alias has to name its PRODUCT
// instead.
//
// Issue #1246: an OSTC Sport advertises "OSTCs" followed by its serial
// ("OSTCs 21211"). dc_filter_hw accepts any "OSTC*" name for every hw_ostc3
// row, and "OSTCs" is not a prefix of "OSTC Sport", so the matcher fell back
// to the first family row and reported the device as an "OSTC 2". The model is
// the same either way, so this is a labelling fix, not a download fix.
//
// Aliases are compared with product_prefix_len, so an entry also covers the
// serial-suffixed form and will not match a longer word ("OSTCsomething").
// Only add an alias with a real advertised name behind it: a wrong guess here
// silently mislabels hardware. Returns NULL when the name is not a known
// alias.
static const char *ble_alias_product(const char *name) {
    static const struct {
        const char *alias;
        const char *product;
    } aliases[] = {
        {"OSTCs", "OSTC Sport"}, // issue #1246
    };
    if (name == NULL) {
        return NULL;
    }
    for (size_t i = 0; i < sizeof(aliases) / sizeof(aliases[0]); i++) {
        if (product_prefix_len(name, aliases[i].alias) > 0) {
            return aliases[i].product;
        }
    }
    return NULL;
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

    // Scubapro/Uwatec short BLE aliases (e.g. "HUD" for "G2 HUD") that differ
    // from the libdivecomputer product name. Resolving them to a specific model
    // lets the exact-model preference in the loop below pick the right
    // descriptor instead of the first family-level fallback. See issue #285.
    if (!has_name_model && (transport & LIBDC_TRANSPORT_BLE)) {
        unsigned int alias_model = uwatec_ble_alias_model(name);
        if (alias_model != 0) {
            name_model = alias_model;
            has_name_model = 1;
        }
    }

    // Advertised names that abbreviate their product rather than prefixing it
    // (see ble_alias_product). Resolved to a product string because the
    // hw_ostc3 family shares one model code, which the exact-model preference
    // above cannot tell apart. Issue #1246.
    const char *alias_product = NULL;
    if (!has_name_model && (transport & LIBDC_TRANSPORT_BLE)) {
        alias_product = ble_alias_product(name);
    }

    dc_descriptor_t *desc = NULL;
    int found = 0;
    size_t best_prefix_len = 0;
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
                if (product && strcasecmp_nospace(name, product) == 0) {
                    info->vendor = dc_descriptor_get_vendor(desc);
                    info->product = product;
                    info->model = dc_descriptor_get_model(desc);
                    info->transports = dc_descriptor_get_transports(desc);
                    dc_descriptor_free(desc);
                    break;
                }

                // An abbreviated advertised name reaches its product through
                // the alias table; that beats the prefix tiebreaker below,
                // which by definition cannot match an abbreviation.
                if (alias_product && product &&
                    strcasecmp_nospace(alias_product, product) == 0) {
                    info->vendor = dc_descriptor_get_vendor(desc);
                    info->product = product;
                    info->model = dc_descriptor_get_model(desc);
                    info->transports = dc_descriptor_get_transports(desc);
                    dc_descriptor_free(desc);
                    break;
                }

                // No exact match: prefer the descriptor whose product is
                // the LONGEST prefix of the advertised name, so a
                // serial-suffixed name resolves to its own model instead
                // of the first family row (issue #590). The descriptor
                // table's strings are static, so the pointers stay valid
                // after dc_descriptor_free.
                if (product) {
                    size_t plen = product_prefix_len(name, product);
                    if (plen > best_prefix_len) {
                        best_prefix_len = plen;
                        info->vendor = dc_descriptor_get_vendor(desc);
                        info->product = product;
                        info->model = dc_descriptor_get_model(desc);
                        info->transports = dc_descriptor_get_transports(desc);
                    }
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
    free(dive->events);
    free(dive);
}
