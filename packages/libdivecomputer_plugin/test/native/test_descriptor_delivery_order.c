// Regression test for issue #2902: the descriptor catalog says which backends
// deliver dives oldest-first.
//
// libdivecomputer's foreach contract is newest-first, which is what lets a
// driver stop at the saved fingerprint. The fork reversed exactly one profile
// loop, shearwater_petrel.c (issue #480), so only for that family is a
// download that stopped part way a contiguous run of the oldest new dives.
// The import wizard advances the saved fingerprint after a partial import
// only for such a backend. Taking the newest dive of a newest-first partial
// set as the resume point hid every older dive the failed session never
// reached (the Halcyon Symbios report in #2902).
//
// The expectations come from descriptor.c's own family field, read through
// libdivecomputer's public iterator, never from the wrapper, so a wrong
// implementation cannot make its own test pass.

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>

#include "libdc_wrapper.h"

// The family descriptor.c records for this vendor, product and model.
static dc_family_t descriptor_family(const char *vendor, const char *product,
                                     unsigned int model) {
    dc_iterator_t *iter = NULL;
    // Calls with side effects stay outside assert(), which NDEBUG removes.
    dc_status_t status = dc_descriptor_iterator(&iter);
    assert(status == DC_STATUS_SUCCESS);
    (void)status;
    dc_descriptor_t *desc = NULL;
    dc_family_t family = DC_FAMILY_NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        if (strcmp(dc_descriptor_get_vendor(desc), vendor) == 0 &&
            strcmp(dc_descriptor_get_product(desc), product) == 0 &&
            dc_descriptor_get_model(desc) == model) {
            family = dc_descriptor_get_type(desc);
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    return family;
}

// The catalog entry for this vendor and product, failing if it is absent.
static libdc_descriptor_info_t catalog_entry(const char *vendor,
                                             const char *product) {
    libdc_descriptor_iterator_t *iter = libdc_descriptor_iterator_new();
    assert(iter != NULL);
    libdc_descriptor_info_t info;
    libdc_descriptor_info_t found;
    int matched = 0;
    while (libdc_descriptor_iterator_next(iter, &info) == 0) {
        if (strcmp(info.vendor, vendor) == 0 &&
            strcmp(info.product, product) == 0) {
            found = info;
            matched = 1;
            break;
        }
    }
    libdc_descriptor_iterator_free(iter);
    if (!matched) {
        fprintf(stderr, "FAIL: %s %s is not in the catalog\n", vendor, product);
        assert(0);
    }
    return found;
}

static void test_flag_follows_the_petrel_family(void) {
    libdc_descriptor_iterator_t *iter = libdc_descriptor_iterator_new();
    assert(iter != NULL);
    libdc_descriptor_info_t info;
    int count = 0;
    int oldest_first = 0;
    while (libdc_descriptor_iterator_next(iter, &info) == 0) {
        int expected = descriptor_family(info.vendor, info.product,
                                         info.model) ==
                       DC_FAMILY_SHEARWATER_PETREL;
        if (info.delivers_oldest_first != expected) {
            fprintf(stderr, "FAIL: %s %s delivers_oldest_first=%d, want %d\n",
                    info.vendor, info.product, info.delivers_oldest_first,
                    expected);
            assert(0);
        }
        oldest_first += info.delivers_oldest_first;
        count++;
    }
    libdc_descriptor_iterator_free(iter);
    // A broken iterator that yields nothing, or a flag that is never set,
    // would pass the loop above.
    assert(count > 300);
    assert(oldest_first > 0);
    printf("PASS: test_flag_follows_the_petrel_family\n");
}

static void test_named_backends(void) {
    assert(catalog_entry("Shearwater", "Perdix 3").delivers_oldest_first == 1);
    assert(catalog_entry("Shearwater", "Teric").delivers_oldest_first == 1);
    // The older Predator backend still walks its ring buffer newest-first.
    assert(catalog_entry("Shearwater", "Predator").delivers_oldest_first == 0);
    assert(catalog_entry("Halcyon", "Symbios HUD").delivers_oldest_first == 0);
    assert(catalog_entry("Halcyon", "Symbios Handset").delivers_oldest_first ==
           0);
    assert(catalog_entry("Suunto", "Vyper").delivers_oldest_first == 0);
    printf("PASS: test_named_backends\n");
}

// libdc_descriptor_match and libdc_descriptor_lookup_model fill the same
// struct, so they must write the flag too rather than leave stack garbage.
static void test_match_and_lookup_write_the_flag(void) {
    libdc_descriptor_info_t info;

    int matched;

    memset(&info, 0x7F, sizeof(info));
    matched = libdc_descriptor_match("Perdix 3", LIBDC_TRANSPORT_BLE, &info);
    assert(matched == 1);
    assert(info.delivers_oldest_first == 1);

    memset(&info, 0x7F, sizeof(info));
    matched = libdc_descriptor_match("Petrel", LIBDC_TRANSPORT_BLE, &info);
    assert(matched == 1);
    assert(info.delivers_oldest_first == 1);

    // A Symbios HUD advertises its serial; model digits [4:6] are 01. The
    // date and unit digits are zeroed, as in the #357 regression test.
    memset(&info, 0x7F, sizeof(info));
    matched = libdc_descriptor_match("0000010000", LIBDC_TRANSPORT_BLE, &info);
    assert(matched == 1);
    assert(strcmp(info.vendor, "Halcyon") == 0);
    assert(info.delivers_oldest_first == 0);

    // Model codes repeat across vendors, so compare against the family of
    // whichever descriptor the lookup returns rather than assume which one.
    libdc_descriptor_info_t perdix = catalog_entry("Shearwater", "Perdix 3");
    memset(&info, 0x7F, sizeof(info));
    matched = libdc_descriptor_lookup_model(LIBDC_TRANSPORT_BLE, perdix.model,
                                            &info);
    assert(matched == 1);
    (void)matched;
    assert(info.delivers_oldest_first ==
           (descriptor_family(info.vendor, info.product, info.model) ==
            DC_FAMILY_SHEARWATER_PETREL));

    printf("PASS: test_match_and_lookup_write_the_flag\n");
}

int main(void) {
    test_flag_follows_the_petrel_family();
    test_named_backends();
    test_match_and_lookup_write_the_flag();
    return 0;
}
