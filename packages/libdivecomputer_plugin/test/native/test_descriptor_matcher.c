#include <assert.h>
#include <ctype.h>
#include <stdio.h>

// Mirror of the helper in libdc_wrapper.c. The wrapper keeps the symbol
// internal, so this file duplicates the logic (same pattern as
// test_serial_callbacks.c does for serial port filters). If the wrapper
// implementation changes, update this copy in lockstep.
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

// Regression for issue #198: BLE-advertised "Puck4" must match the
// libdivecomputer descriptor product "Puck 4" so that model 0x35
// (Genius/Sirius-family VARIABLE protocol) is selected instead of the
// first family-level fallback (Mares Smart, 0x10, FIXED protocol).
static void test_ble_name_matches_spaced_product(void) {
    assert(strcasecmp_nospace("Puck4", "Puck 4") == 0);
    assert(strcasecmp_nospace("Puck 4", "Puck4") == 0);
    assert(strcasecmp_nospace("PuckLite", "Puck Lite") == 0);
    assert(strcasecmp_nospace("Quad2", "Quad 2") == 0);
    printf("PASS: test_ble_name_matches_spaced_product\n");
}

static void test_matches_are_case_insensitive(void) {
    assert(strcasecmp_nospace("puck4", "Puck 4") == 0);
    assert(strcasecmp_nospace("PUCK4", "Puck 4") == 0);
    assert(strcasecmp_nospace("smart", "Smart") == 0);
    printf("PASS: test_matches_are_case_insensitive\n");
}

static void test_identical_names_match(void) {
    assert(strcasecmp_nospace("Teric", "Teric") == 0);
    assert(strcasecmp_nospace("Sirius", "Sirius") == 0);
    assert(strcasecmp_nospace("Puck 4", "Puck 4") == 0);
    printf("PASS: test_identical_names_match\n");
}

// Length mismatch: "Puck" (4 chars) must NOT match "Puck 4" (6 chars minus
// spaces = 5 chars). Without this guard the fix would pull in any prefix.
static void test_prefix_is_not_a_match(void) {
    assert(strcasecmp_nospace("Puck", "Puck 4") != 0);
    assert(strcasecmp_nospace("Puck 4", "Puck") != 0);
    assert(strcasecmp_nospace("Smart", "Smart Apnea") != 0);
    printf("PASS: test_prefix_is_not_a_match\n");
}

static void test_different_names_do_not_match(void) {
    assert(strcasecmp_nospace("Puck4", "Smart") != 0);
    assert(strcasecmp_nospace("Genius", "Sirius") != 0);
    assert(strcasecmp_nospace("Puck4", "Quad 2") != 0);
    printf("PASS: test_different_names_do_not_match\n");
}

static void test_edge_cases(void) {
    // Empty strings.
    assert(strcasecmp_nospace("", "") == 0);
    assert(strcasecmp_nospace("", "X") != 0);
    assert(strcasecmp_nospace("X", "") != 0);

    // Strings that differ only in embedded/leading/trailing spaces.
    assert(strcasecmp_nospace("A B C", "ABC") == 0);
    assert(strcasecmp_nospace("  ABC  ", "ABC") == 0);
    assert(strcasecmp_nospace("A  B", "AB") == 0);

    // All-space strings collapse to empty and match each other.
    assert(strcasecmp_nospace(" ", "  ") == 0);
    assert(strcasecmp_nospace("   ", "") == 0);

    // Tabs and newlines are NOT ignored (helper is space-only, not
    // general whitespace). BLE names don't carry them in practice.
    assert(strcasecmp_nospace("A\tB", "AB") != 0);
    assert(strcasecmp_nospace("A\nB", "AB") != 0);

    printf("PASS: test_edge_cases\n");
}

int main(void) {
    test_ble_name_matches_spaced_product();
    test_matches_are_case_insensitive();
    test_identical_names_match();
    test_prefix_is_not_a_match();
    test_different_names_do_not_match();
    test_edge_cases();
    printf("\nAll descriptor matcher tests passed.\n");
    return 0;
}
