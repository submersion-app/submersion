/* Issue #1223: a dive logged with two AI transmitters showed one tank as a flat
   "(est.)" line, because the wrapper kept a single pressure per sample.

   libdivecomputer fires DC_SAMPLE_PRESSURE once per transmitter, so a sample can
   carry several readings before the next DC_SAMPLE_TIME closes it. The wrapper
   stored them in one `pressure`/`tank` pair, so the last transmitter of each
   sample overwrote every earlier one and the lower-numbered tank kept only the
   readings taken while the higher-numbered transmitter was out of comms.

   Fixture: the Petrel 3 CCR dive already used by test_shearwater_o2_millivolt
   (issue #810). It carries an O2 and a diluent transmitter, and 407 of its 419
   samples report both. */

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libdc_wrapper.h"

/* Both transmitters report on nearly every sample of the fixture. Counted from
   the parser directly (dc_parser_samples_foreach over DC_SAMPLE_PRESSURE). */
#define EXPECTED_TANK0_READINGS 413
#define EXPECTED_TANK1_READINGS 410
#define EXPECTED_SAMPLES        419

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

/* Count the samples that carry a reading for each tank. */
static void count_per_tank(const libdc_parsed_dive_t *dive,
                           unsigned int *counts, unsigned int ntanks) {
    memset(counts, 0, ntanks * sizeof(*counts));
    for (unsigned int i = 0; i < dive->sample_count; i++) {
        for (unsigned int t = 0; t < ntanks; t++) {
            if (!isnan(dive->samples[i].tank_pressure[t])) counts[t]++;
        }
    }
}

/* The heart of #1223: neither transmitter may be dropped when both report on
   the same sample. */
static void test_both_transmitters_survive(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    assert(dive.tank_count == 2);
    assert(dive.sample_count == EXPECTED_SAMPLES);

    unsigned int counts[2];
    count_per_tank(&dive, counts, 2);
    printf("  tank 0: %u readings, tank 1: %u readings\n", counts[0], counts[1]);
    assert(counts[0] == EXPECTED_TANK0_READINGS);
    assert(counts[1] == EXPECTED_TANK1_READINGS);

    /* libdc_parse_raw_dive fills a caller-owned struct: free its arrays, not it. */
    free(dive.samples);
    free(dive.events);
    printf("PASS: test_both_transmitters_survive\n");
}

/* The two series must be distinct: before the fix tank 0's readings were
   whatever tank 1 last reported, so the curves were identical wherever both
   transmitters were in comms. */
static void test_tanks_carry_distinct_pressures(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    unsigned int both = 0;
    unsigned int differing = 0;
    for (unsigned int i = 0; i < dive.sample_count; i++) {
        double p0 = dive.samples[i].tank_pressure[0];
        double p1 = dive.samples[i].tank_pressure[1];
        if (isnan(p0) || isnan(p1)) continue;
        both++;
        if (fabs(p0 - p1) > 0.01) differing++;
    }
    printf("  %u samples report both tanks, %u of them differ\n", both, differing);
    assert(both >= 400);
    assert(differing == both);

    /* libdc_parse_raw_dive fills a caller-owned struct: free its arrays, not it. */
    free(dive.samples);
    free(dive.events);
    printf("PASS: test_tanks_carry_distinct_pressures\n");
}

/* Sanity: the per-sample series must agree with the dive-level tank summary
   libdivecomputer reports, so the two cannot be attributed to opposite tanks. */
static void test_series_match_tank_summary(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    for (unsigned int t = 0; t < 2; t++) {
        double first = NAN, last = NAN;
        for (unsigned int i = 0; i < dive.sample_count; i++) {
            double p = dive.samples[i].tank_pressure[t];
            if (isnan(p)) continue;
            if (isnan(first)) first = p;
            last = p;
        }
        printf("  tank %u: series %.1f -> %.1f bar, summary %.1f -> %.1f bar\n",
               t, first, last, dive.tanks[t].beginpressure,
               dive.tanks[t].endpressure);
        assert(fabs(first - dive.tanks[t].beginpressure) < 1.0);
        assert(fabs(last - dive.tanks[t].endpressure) < 1.0);
    }

    /* libdc_parse_raw_dive fills a caller-owned struct: free its arrays, not it. */
    free(dive.samples);
    free(dive.events);
    printf("PASS: test_series_match_tank_summary\n");
}

/* A tank that reported nothing at a sample must stay unset, so the Dart layer
   can tell "no reading" from "0 bar". */
static void test_absent_tank_is_nan(void) {
    libdc_parsed_dive_t dive;
    parse_fixture(&dive);

    for (unsigned int i = 0; i < dive.sample_count; i++) {
        for (unsigned int t = 2; t < LIBDC_MAX_TANKS; t++) {
            assert(isnan(dive.samples[i].tank_pressure[t]));
        }
    }

    /* libdc_parse_raw_dive fills a caller-owned struct: free its arrays, not it. */
    free(dive.samples);
    free(dive.events);
    printf("PASS: test_absent_tank_is_nan\n");
}

int main(void) {
    printf("Running multi-transmitter pressure tests (issue #1223)...\n");
    test_both_transmitters_survive();
    test_tanks_carry_distinct_pressures();
    test_series_match_tank_summary();
    test_absent_tank_is_nan();
    printf("All multi-transmitter pressure tests passed\n");
    return 0;
}
