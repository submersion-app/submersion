#include "libdc_wrapper.h"
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <libdivecomputer/version.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/usbhid.h>

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

// Some BLE names belong to a device libdivecomputer does not support, yet are
// still claimed by a descriptor whose filter is too loose. Claiming one is
// worse than ignoring it: the download wizard announces a "Recognized Device"
// and promises the download will work, and the connect then fails because the
// app is speaking the wrong vendor's protocol.
//
// Issue #123: a Suunto Ocean advertises "S19 <4 hex> LE". dc_filter_oceans
// prefix-matches the two characters "S1" with strncasecmp, so the Oceans S1
// descriptor swallowed the watch. The two are unrelated: the Ocean is on
// Suunto's next-generation smartwatch platform, whose dive-download protocol
// has never been captured, let alone implemented, in libdivecomputer.
//
// The rejection is keyed on the whole advertised shape rather than on the
// looser "S1" prefix on the libdivecomputer side. The Oceans S1's own
// advertised name is documented nowhere: not in libdivecomputer, not in
// Subsurface, not in the S1 manual, which pairs by QR code. Tightening that
// prefix would be a guess against a discontinued product, and a wrong guess
// there silently hides working hardware.
//
// Across two scans five minutes apart the same watch advertised "S19 1DFC LE"
// and then "S19 700B LE" from two different MAC addresses, so the hex group is
// a rotating privacy identifier and "S19" is the stable model code.
//
// Every character outside the rotating group is pinned, including the "9".
// A sibling model on the same platform would carry a different code and would
// collide with the same "S1" prefix, but suppressing a name nobody has
// captured is the same guess this fix exists to avoid, and its cost is worse:
// hiding a device is harder to diagnose than mislabelling one. Add a model
// code here only with a real advertised name behind it, from a log.
static int is_suunto_ng_ble_name(const char *name) {
    // "S19 hhhh LE"
    static const size_t kLength = 11;

    if (name == NULL || strlen(name) != kLength) {
        return 0;
    }
    if (toupper((unsigned char)name[0]) != 'S' || name[1] != '1' ||
        name[2] != '9') {
        return 0;
    }
    if (name[3] != ' ' || name[8] != ' ') {
        return 0;
    }
    for (size_t i = 4; i < 8; i++) {
        if (!isxdigit((unsigned char)name[i])) {
            return 0;
        }
    }
    return toupper((unsigned char)name[9]) == 'L' &&
           toupper((unsigned char)name[10]) == 'E';
}

int libdc_descriptor_match(const char *name, unsigned int transport,
                           libdc_descriptor_info_t *info) {
    if (name == NULL || info == NULL) {
        return 0;
    }

    // Some advertised names identify hardware libdivecomputer has no support
    // for. Reject those up front, so that no descriptor can claim one on a
    // loose prefix match. See issue #123.
    if ((transport & LIBDC_TRANSPORT_BLE) && is_suunto_ng_ble_name(name)) {
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

// ============================================================
// USB HID Discovery Helpers
// ============================================================

// Finds the descriptor for an exact vendor/product/model triple.
// Returns NULL when nothing matches; the caller owns what it gets back and
// must dc_descriptor_free() it.
//
// Vendor and product are compared exactly, unlike the BLE name matcher above:
// these strings did not come off the air, they came from a descriptor this
// same table produced, so a spelling difference means a different device.
static dc_descriptor_t *find_descriptor_exact(const char *vendor,
                                              const char *product,
                                              unsigned int model) {
    if (vendor == NULL || product == NULL) {
        return NULL;
    }

    dc_iterator_t *iter = NULL;
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) {
        return NULL;
    }

    dc_descriptor_t *desc = NULL;
    dc_descriptor_t *found = NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *desc_vendor = dc_descriptor_get_vendor(desc);
        const char *desc_product = dc_descriptor_get_product(desc);
        if (desc_vendor != NULL && desc_product != NULL &&
            strcmp(desc_vendor, vendor) == 0 &&
            strcmp(desc_product, product) == 0 &&
            dc_descriptor_get_model(desc) == model) {
            found = desc;
            break;
        }
        dc_descriptor_free(desc);
    }

    dc_iterator_free(iter);
    return found;
}

unsigned int libdc_descriptor_transports(const char *vendor, const char *product,
                                         unsigned int model) {
    dc_descriptor_t *desc = find_descriptor_exact(vendor, product, model);
    if (desc == NULL) {
        return 0;
    }
    unsigned int transports = dc_descriptor_get_transports(desc);
    dc_descriptor_free(desc);
    return transports;
}

int libdc_usbhid_match(const char *vendor, const char *product,
                       unsigned int model,
                       unsigned short vid, unsigned short pid) {
    dc_descriptor_t *desc = find_descriptor_exact(vendor, product, model);
    if (desc == NULL) {
        return 0;
    }

    int matched = 0;
    if (dc_descriptor_get_transports(desc) & DC_TRANSPORT_USBHID) {
        dc_usbhid_desc_t usbhid = { vid, pid };
        matched = dc_descriptor_filter(desc, DC_TRANSPORT_USBHID, &usbhid) != 0;
    }

    dc_descriptor_free(desc);
    return matched;
}

void libdc_parsed_dive_free(libdc_parsed_dive_t *dive) {
    if (dive == NULL) {
        return;
    }
    free(dive->samples);
    free(dive->events);
    free(dive);
}

// Families whose DEVINFO model shares the descriptor table's code space. Add
// one only with evidence from its backend source: the model must be read
// from the device and compared against descriptor model codes there.
static int reported_model_family_allowed(dc_family_t family) {
    return family == DC_FAMILY_CRESSI_GOA;
}

int libdc_resolve_reported_product(const char *vendor, const char *product,
                                   unsigned int model,
                                   unsigned int reported_model,
                                   char *product_out,
                                   size_t product_out_size) {
    if (vendor == NULL || product == NULL || product_out == NULL ||
        product_out_size == 0 || reported_model == model) {
        return 0;
    }

    dc_iterator_t *iter = NULL;
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) {
        return 0;
    }

    // Pass 1: the family of the descriptor the download used.
    dc_family_t family = DC_FAMILY_NULL;
    int found = 0;
    dc_descriptor_t *desc = NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (!found && v != NULL && p != NULL && strcmp(v, vendor) == 0 &&
            strcmp(p, product) == 0 &&
            dc_descriptor_get_model(desc) == model) {
            family = dc_descriptor_get_type(desc);
            found = 1;
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    if (!found || !reported_model_family_allowed(family)) {
        return 0;
    }

    // Pass 2: the row the device named.
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) {
        return 0;
    }
    int resolved = 0;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (!resolved && v != NULL && p != NULL && strcmp(v, vendor) == 0 &&
            dc_descriptor_get_type(desc) == family &&
            dc_descriptor_get_model(desc) == reported_model) {
            size_t len = strlen(p);
            if (len < product_out_size) {
                memcpy(product_out, p, len + 1);
                resolved = 1;
            }
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    return resolved;
}

// ============================================================
// BLE Characteristic Read ioctl (issue #422)
// ============================================================

int libdc_ble_characteristic_read_decode(
    unsigned int request, const void *data, size_t size,
    char uuid_str[LIBDC_BLE_UUID_STRING_SIZE], size_t *value_size) {
    if (request != LIBDC_IOCTL_BLE_CHARACTERISTIC_READ) {
        return LIBDC_BLE_CHAR_READ_NOT_THIS;
    }
    if (data == NULL || size <= LIBDC_BLE_UUID_SIZE || uuid_str == NULL ||
        value_size == NULL) {
        return LIBDC_BLE_CHAR_READ_INVALID;
    }
    const unsigned char *u = (const unsigned char *)data;
    snprintf(uuid_str, LIBDC_BLE_UUID_STRING_SIZE,
             "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-"
             "%02x%02x%02x%02x%02x%02x",
             u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9],
             u[10], u[11], u[12], u[13], u[14], u[15]);
    *value_size = size - LIBDC_BLE_UUID_SIZE;
    return LIBDC_BLE_CHAR_READ_OK;
}

int libdc_ble_characteristic_read_fill(void *data, size_t size,
                                       const unsigned char *value,
                                       size_t value_len) {
    if (data == NULL || size <= LIBDC_BLE_UUID_SIZE) {
        return LIBDC_STATUS_INVALIDARGS;
    }
    size_t wanted = size - LIBDC_BLE_UUID_SIZE;
    if (value == NULL || value_len < wanted) {
        return LIBDC_STATUS_DATAFORMAT;
    }
    memcpy((unsigned char *)data + LIBDC_BLE_UUID_SIZE, value, wanted);
    return LIBDC_STATUS_SUCCESS;
}
