// Pins which self-reported models may relabel a computer (issue #422).
// Linked against the real descriptor table: the rows, families and model
// codes under test are libdivecomputer's own, not copies.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "libdc_wrapper.h"

static void test_cressi_goa_model_code_relabels(void) {
    char out[64] = "untouched";
    // The Cressi adapter advertises "1_..." (Cartesio); the version block
    // says model 4.
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 4,
                                          out, sizeof(out)) == 1);
    assert(strcmp(out, "Donatello") == 0);
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 10,
                                          out, sizeof(out)) == 1);
    assert(strcmp(out, "Nepto") == 0);
    printf("PASS: test_cressi_goa_model_code_relabels\n");
}

static void test_same_model_is_no_relabel(void) {
    char out[64] = "untouched";
    assert(libdc_resolve_reported_product("Cressi", "Donatello", 4, 4,
                                          out, sizeof(out)) == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_same_model_is_no_relabel\n");
}

static void test_unknown_goa_model_code_keeps_label(void) {
    char out[64] = "untouched";
    // No Goa row has model 7: a future model must not be guessed at.
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 7,
                                          out, sizeof(out)) == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_unknown_goa_model_code_keeps_label\n");
}

static void test_other_families_never_relabel(void) {
    char out[64] = "untouched";
    // Cressi Leonardo is a different family; its model 4 row (Giotto) must
    // not be reachable through a DEVINFO model.
    assert(libdc_resolve_reported_product("Cressi", "Leonardo", 1, 4,
                                          out, sizeof(out)) == 0);
    // A non-Cressi family whose model 10 row (Petrel 3) exists: Shearwater
    // DEVINFO models are a private code space.
    assert(libdc_resolve_reported_product("Shearwater", "Petrel", 3, 10,
                                          out, sizeof(out)) == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_other_families_never_relabel\n");
}

static void test_bad_arguments(void) {
    char out[64] = "untouched";
    assert(libdc_resolve_reported_product(NULL, "Cartesio", 1, 4,
                                          out, sizeof(out)) == 0);
    assert(libdc_resolve_reported_product("Cressi", NULL, 1, 4,
                                          out, sizeof(out)) == 0);
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 4,
                                          NULL, 64) == 0);
    assert(libdc_resolve_reported_product("Nobody", "Nothing", 1, 4,
                                          out, sizeof(out)) == 0);
    // The app matches descriptors by EXACT product string, so a truncated
    // name is worse than none.
    char tiny[4] = "abc";
    assert(libdc_resolve_reported_product("Cressi", "Cartesio", 1, 4,
                                          tiny, sizeof(tiny)) == 0);
    assert(strcmp(tiny, "abc") == 0);
    assert(strcmp(out, "untouched") == 0);
    printf("PASS: test_bad_arguments\n");
}

int main(void) {
    test_cressi_goa_model_code_relabels();
    test_same_model_is_no_relabel();
    test_unknown_goa_model_code_keeps_label();
    test_other_families_never_relabel();
    test_bad_arguments();
    printf("All reported product tests passed.\n");
    return 0;
}
