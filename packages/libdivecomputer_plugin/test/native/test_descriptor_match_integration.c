// Integration test for libdc_descriptor_match against the REAL libdivecomputer
// descriptor table. Unlike test_descriptor_matcher.c (which unit-tests the
// strcasecmp_nospace helper in isolation), this test links the actual
// descriptor.c so it exercises end-to-end BLE name -> descriptor resolution.
//
// Regression for issue #285: the Scubapro Galileo HUD advertises the short BLE
// name "HUD", but dc_filter_uwatec matches that alias against EVERY Uwatec/
// Scubapro descriptor. Without an alias->model mapping, the matcher falls back
// to the first family-level descriptor ("Aladin Sport Matrix", model 0x17)
// instead of the real model ("G2 HUD", model 0x42). The same alias-vs-product
// gap affects "Galileo 3" (product "G3"), "A1" ("Aladin A1") and "A2"
// ("Aladin A2"). Model codes below come from descriptor.c.
//
// Regression for issue #357: a Halcyon Symbios Handset (an all-digit BLE
// serial) was always identified as a HUD. Both Symbios descriptor rows
// ("Symbios HUD" model 1, "Symbios Handset" model 7) share dc_filter_halcyon,
// which matched the serial against the UNION {1, 7}, so both rows passed for
// any Symbios serial and the first (HUD) always won. dc_match_halcyon
// disambiguates by the serial's [4:6] digits (01 = HUD, 07 = Handset), so each
// row must filter on its own model. The serials below are synthetic: only the
// model-code digits [4:6] are significant, so the surrounding manufacture-date
// and unit-number digits are zeroed (the bug was first reported against real
// Symbios devices in issue #288).

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "libdc_wrapper.h"

static void expect_ble_match(const char *name, const char *expected_product,
                             unsigned int expected_model) {
    libdc_descriptor_info_t info;
    memset(&info, 0, sizeof(info));
    int ok = libdc_descriptor_match(name, LIBDC_TRANSPORT_BLE, &info);
    if (!ok) {
        fprintf(stderr, "FAIL: \"%s\" did not match any descriptor\n", name);
        assert(ok);
    }
    if (strcmp(info.product, expected_product) != 0 ||
        info.model != expected_model) {
        fprintf(stderr,
                "FAIL: \"%s\" resolved to %s/0x%02x, expected %s/0x%02x\n",
                name, info.product, info.model, expected_product,
                expected_model);
        assert(0);
    }
}

// The reported device: BLE name "HUD" must resolve to the G2 HUD (0x42),
// not the family-level "Aladin Sport Matrix" fallback (0x17).
static void test_hud_resolves_to_g2_hud(void) {
    expect_ble_match("HUD", "G2 HUD", 0x42);
    printf("PASS: test_hud_resolves_to_g2_hud\n");
}

// Same alias-vs-product gap for the other short Scubapro/Uwatec BLE names.
static void test_other_short_aliases_resolve(void) {
    expect_ble_match("Galileo 3", "G3", 0x34);
    expect_ble_match("A1", "Aladin A1", 0x25);
    expect_ble_match("A2", "Aladin A2", 0x28);
    printf("PASS: test_other_short_aliases_resolve\n");
}

// Aliases are case-insensitive (BLE advertised names vary by stack/firmware).
static void test_alias_match_is_case_insensitive(void) {
    expect_ble_match("hud", "G2 HUD", 0x42);
    expect_ble_match("a1", "Aladin A1", 0x25);
    printf("PASS: test_alias_match_is_case_insensitive\n");
}

// Regression guard: names whose product string already matches exactly must
// keep resolving to themselves and must NOT be captured by the alias table.
static void test_exact_product_names_unchanged(void) {
    expect_ble_match("G2", "G2", 0x32);
    expect_ble_match("G2 TEK", "G2 TEK", 0x31);
    expect_ble_match("Luna 2.0", "Luna 2.0", 0x51);
    expect_ble_match("Luna 2.0 AI", "Luna 2.0 AI", 0x50);
    printf("PASS: test_exact_product_names_unchanged\n");
}

// Regression guard: a non-Uwatec device (different vendor/filter) is unaffected.
static void test_non_uwatec_device_unaffected(void) {
    libdc_descriptor_info_t info;
    memset(&info, 0, sizeof(info));
    int ok = libdc_descriptor_match("Teric", LIBDC_TRANSPORT_BLE, &info);
    assert(ok);
    assert(strcmp(info.vendor, "Shearwater") == 0);
    assert(strcmp(info.product, "Teric") == 0);
    printf("PASS: test_non_uwatec_device_unaffected\n");
}

// Issue #483: the Shearwater Perdix 3 advertises the BLE name "Perdix 3",
// which was absent from both the descriptor table and dc_filter_shearwater's
// exact-match whitelist, so every descriptor rejected it and the device never
// appeared during scanning. Model 14 continues Shearwater's sequential model
// numbering (Petrel 3 = 10, Perdix 2 = 11, Tern = 12, Peregrine TX = 13).
static void test_perdix_3_resolves(void) {
    expect_ble_match("Perdix 3", "Perdix 3", 14);
    expect_ble_match("perdix 3", "Perdix 3", 14);
    printf("PASS: test_perdix_3_resolves\n");
}

// Issue #483 regression guard: dc_filter_shearwater passes a whitelisted name
// for EVERY Shearwater row, so resolution relies on the wrapper preferring the
// row whose product exactly equals the BLE name. The new "Perdix 3" row must
// not disturb that for the older Perdix models.
static void test_other_perdix_models_unchanged(void) {
    expect_ble_match("Perdix", "Perdix", 5);
    expect_ble_match("Perdix 2", "Perdix 2", 11);
    printf("PASS: test_other_perdix_models_unchanged\n");
}

// Issue #357: a Handset serial (model-code digits [4:6] = "07") must resolve to
// the "Symbios Handset" descriptor (model 7), not the "Symbios HUD" row
// (model 1) that previously always won because both rows matched the union
// {1, 7}.
static void test_symbios_handset_resolves_to_handset(void) {
    expect_ble_match("0000070000", "Symbios Handset", 7);
    printf("PASS: test_symbios_handset_resolves_to_handset\n");
}

// Issue #357 regression guard: a HUD serial (model-code digits [4:6] = "01")
// must keep resolving to the "Symbios HUD" descriptor and must not be captured
// by the Handset row once each row filters on its own model.
static void test_symbios_hud_resolves_to_hud(void) {
    expect_ble_match("0000010000", "Symbios HUD", 1);
    printf("PASS: test_symbios_hud_resolves_to_hud\n");
}

int main(void) {
    test_hud_resolves_to_g2_hud();
    test_other_short_aliases_resolve();
    test_alias_match_is_case_insensitive();
    test_exact_product_names_unchanged();
    test_non_uwatec_device_unaffected();
    test_perdix_3_resolves();
    test_other_perdix_models_unchanged();
    test_symbios_handset_resolves_to_handset();
    test_symbios_hud_resolves_to_hud();
    printf("\nAll descriptor match integration tests passed.\n");
    return 0;
}
