/* Two dive computers paired to the same air-integration transmitter log the
   same cylinder, whatever gas mix each had programmed for it. The transmitter
   serial is therefore the cylinder's identity across computers, and the
   consolidation code needs it on every downloaded tank.

   libdivecomputer's Shearwater parser already decodes the serial from opening
   record 5 (and 6/7 for tanks 3 and 4) but never exposed it through
   DC_FIELD_TANK. The fork adds `dc_tank_t.serial`; this test pins the value
   the wrapper carries out of it.

   Fixture: the Petrel 3 CCR dive shared with test_multi_transmitter_pressure.
   Its opening record 5 holds the BCD serials 12 30 86 and 10 96 23, decoded
   by hand from the raw bytes, not from the code under test. The Petrel 3 is
   not a Teric, so the Teric digit-pair swap does not apply. */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libdc_wrapper.h"

#define EXPECTED_TANK0_SERIAL 123086u
#define EXPECTED_TANK1_SERIAL 109623u

/* The slot is reported as the physical transmitter slot plus one, so a
   zeroed field means "unknown". Both serials come from opening record 5,
   whose first entry is T1 and second T2, so the two active tanks sit in
   T1 and T2: slots 1 and 2. */
#define EXPECTED_TANK0_SLOT 1u
#define EXPECTED_TANK1_SLOT 2u

static unsigned int load_fixture(const char *path, unsigned char **out) {
    *out = NULL;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return 0; }
    unsigned char *buf = (unsigned char *)malloc((size_t)len);
    if (!buf) { fclose(f); return 0; }
    size_t read = fread(buf, 1, (size_t)len, f);
    fclose(f);
    if (read != (size_t)len) { free(buf); return 0; }
    *out = buf;
    return (unsigned int)read;
}

static void parse_fixture(libdc_parsed_dive_t *dive) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture("fixtures/petrel3_ccr_o2_cells.bin", &data);
    assert(size == 22400);
    assert(data != NULL);

    char err[256] = {0};
    int rc = libdc_parse_raw_dive("Shearwater", "Petrel 3", 10, data, size, dive,
                                  err, sizeof(err));
    if (rc != 0) {
        printf("FAIL: libdc_parse_raw_dive returned %d (%s)\n", rc, err);
    }
    assert(rc == 0);
    free(data);
}

/* Each active transmitter's serial must ride along with its tank. */
static void test_tanks_carry_transmitter_serials(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    assert(dive.tank_count == 2);
    printf("  tank 0 serial %u, tank 1 serial %u\n",
           dive.tanks[0].serial, dive.tanks[1].serial);
    assert(dive.tanks[0].serial == EXPECTED_TANK0_SERIAL);
    assert(dive.tanks[1].serial == EXPECTED_TANK1_SERIAL);

    /* libdc_parse_raw_dive fills a caller-owned struct: free its arrays, not it. */
    free(dive.samples);
    free(dive.events);
    printf("PASS: test_tanks_carry_transmitter_serials\n");
}

/* Slots beyond tank_count are untouched by the parser and must read as
   "no transmitter", so a binding that walks the whole array cannot invent a
   serial for a tank that does not exist. */
static void test_unused_tank_slots_have_no_serial(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    for (unsigned int t = dive.tank_count; t < LIBDC_MAX_TANKS; t++) {
        assert(dive.tanks[t].serial == 0);
    }

    free(dive.samples);
    free(dive.events);
    printf("PASS: test_unused_tank_slots_have_no_serial\n");
}

/* Each active transmitter reports the physical slot it was paired to (issue
   #4347), so a file import that names slots T1 to T4 can be matched to it. */
static void test_tanks_carry_transmitter_slots(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    assert(dive.tank_count == 2);
    printf("  tank 0 slot %u, tank 1 slot %u\n",
           dive.tanks[0].slot, dive.tanks[1].slot);
    assert(dive.tanks[0].slot == EXPECTED_TANK0_SLOT);
    assert(dive.tanks[1].slot == EXPECTED_TANK1_SLOT);
    for (unsigned int t = dive.tank_count; t < LIBDC_MAX_TANKS; t++) {
        assert(dive.tanks[t].slot == 0);
    }

    free(dive.samples);
    free(dive.events);
    printf("PASS: test_tanks_carry_transmitter_slots\n");
}

int main(void) {
    printf("Running tank transmitter serial tests...\n");
    test_tanks_carry_transmitter_serials();
    test_unused_tank_slots_have_no_serial();
    test_tanks_carry_transmitter_slots();
    printf("All tank transmitter serial tests passed\n");
    return 0;
}
