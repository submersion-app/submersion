/* PR #342: the Cressi Leonardo logged a decompression obligation that never
   reached the app, and marked most of an ordinary ascent as a warning.

   Each in-water sample is a single 16-bit word: depth in bits 0-10, a deco
   obligation flag in bit 11, and an ascent rate graded 0-3 in bits 14-15.
   Only level 3 sounds the computer's alarm; the lower levels move the rate
   indicator on its display. The parser used to ignore bit 11 entirely and to
   raise SAMPLE_EVENT_ASCENT for every non-zero level.

   The reporting rule under test matters as much as the bits. libdc_download.c
   carries deco state forward across samples and seeds it with "never
   reported", so the parser reports the obligation only when it changes, and a
   dive that never incurs one is left unknown rather than being told there is
   none. The Leonardo logs no stop depth, no stop time and no remaining
   no-stop time, so those stay zero and must not be read as measurements.

   Bit 11 and the ascent grading are confirmed on the Leonardo only. The
   Giotto, Newton and Drake share this parser and keep the original
   behaviour, which the last test pins.

   The fixtures are synthesised from the record layout the parser documents,
   which keeps the bits under test visible rather than buried in a blob. */

#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libdivecomputer/parser.h>

#include "libdc_wrapper.h"

#define CRESSI_VENDOR   "Cressi"
#define LEONARDO_PRODUCT "Leonardo"
#define LEONARDO_MODEL  1
#define GIOTTO_PRODUCT  "Giotto"
#define GIOTTO_MODEL    4

#define SZ_HEADER 82
#define INTERVAL  20 /* seconds per sample, fixed on every model but the Drake */

/* One in-water sample as the computer packs it. */
typedef struct {
    unsigned int depth_dm; /* 1/10 m, bits 0-10 */
    unsigned int deco;     /* bit 11 */
    unsigned int ascent;   /* 0-3, bits 14-15 */
} leonardo_sample_t;

static void put_u16(unsigned char *p, unsigned int value) {
    p[0] = (unsigned char)(value & 0xFF);
    p[1] = (unsigned char)((value >> 8) & 0xFF);
}

/* Build a raw Leonardo dive: an 82-byte header followed by 2-byte samples. */
static unsigned char *build_dive(const leonardo_sample_t *samples,
                                 unsigned int count,
                                 unsigned int *size_out) {
    unsigned int size = SZ_HEADER + count * 2;
    unsigned char *data = (unsigned char *)calloc(1, size);
    assert(data != NULL);

    put_u16(data + 0x06, count); /* sample count, also the dive time */
    data[0x08] = 24;             /* 2024 */
    data[0x09] = 6;
    data[0x0A] = 15;
    data[0x0B] = 10;
    data[0x0C] = 30;
    data[0x19] = 21;             /* O2 % */
    data[0x22] = 18;             /* minimum water temperature, degrees C */

    unsigned int max_depth_dm = 0;
    for (unsigned int i = 0; i < count; i++) {
        const leonardo_sample_t *s = &samples[i];
        unsigned int word = (s->depth_dm & 0x07FF) |
                            (s->deco ? 0x0800 : 0) |
                            ((s->ascent & 0x03) << 14);
        put_u16(data + SZ_HEADER + i * 2, word);
        if (s->depth_dm > max_depth_dm) max_depth_dm = s->depth_dm;
    }
    put_u16(data + 0x20, max_depth_dm);

    *size_out = size;
    return data;
}

/* libdc_parse_raw_dive fills a caller-owned struct, so its two heap members
   are released individually; libdc_parsed_dive_free() would also free the
   struct itself, which is undefined for a stack dive. */
static void release(libdc_parsed_dive_t *dive) {
    free(dive->samples);
    free(dive->events);
    dive->samples = NULL;
    dive->events = NULL;
}

static void parse(const char *product, unsigned int model,
                  const leonardo_sample_t *samples, unsigned int count,
                  libdc_parsed_dive_t *dive) {
    unsigned int size = 0;
    unsigned char *data = build_dive(samples, count, &size);

    char err[256] = {0};
    int rc = libdc_parse_raw_dive(CRESSI_VENDOR, product, model,
                                  data, size, dive, err, sizeof(err));
    if (rc != 0) {
        printf("FAIL: libdc_parse_raw_dive returned %d (%s)\n", rc, err);
    }
    assert(rc == 0);
    free(data);
}

/* A ten-sample dive: down to 18 m and back, no deco, no ascent alarm. */
static void fill_recreational(leonardo_sample_t *samples) {
    static const unsigned int depths[10] = {50,  110, 160, 180, 180,
                                            170, 120, 80,  40,  10};
    for (unsigned int i = 0; i < 10; i++) {
        samples[i].depth_dm = depths[i];
        samples[i].deco = 0;
        samples[i].ascent = 0;
    }
}

/* A dive with no obligation must leave the obligation unknown. Reporting
   DC_DECO_NDL with a zero time on every sample instead would tell the app the
   computer measured zero minutes of no-stop time for the whole dive, which it
   then draws in place of its own calculated curve. */
static void test_no_deco_dive_leaves_obligation_unknown(void) {
    leonardo_sample_t samples[10];
    fill_recreational(samples);

    libdc_parsed_dive_t dive;
    parse(LEONARDO_PRODUCT, LEONARDO_MODEL, samples, 10, &dive);

    printf("  recreational: %u samples, %u events, deco_type[0]=%u\n",
           dive.sample_count, dive.event_count, dive.samples[0].deco_type);
    assert(dive.sample_count == 10);
    assert(dive.event_count == 0);
    for (unsigned int i = 0; i < dive.sample_count; i++) {
        assert(dive.samples[i].deco_type == UINT32_MAX);
    }

    release(&dive);
    printf("PASS: test_no_deco_dive_leaves_obligation_unknown\n");
}

/* The obligation is reported on each transition and carried in between, and
   the stop depth stays absent because the computer never logs one. */
static void test_deco_run_reports_begin_and_end(void) {
    leonardo_sample_t samples[10];
    fill_recreational(samples);
    for (unsigned int i = 3; i <= 6; i++) samples[i].deco = 1;

    libdc_parsed_dive_t dive;
    parse(LEONARDO_PRODUCT, LEONARDO_MODEL, samples, 10, &dive);

    assert(dive.sample_count == 10);
    printf("  deco run: %u events\n", dive.event_count);
    assert(dive.event_count == 2);

    assert(dive.events[0].type == SAMPLE_EVENT_DECOSTOP);
    assert(dive.events[0].flags == SAMPLE_FLAGS_BEGIN);
    assert(dive.events[0].time_ms == 4 * INTERVAL * 1000);
    assert(dive.events[1].type == SAMPLE_EVENT_DECOSTOP);
    assert(dive.events[1].flags == SAMPLE_FLAGS_END);
    assert(dive.events[1].time_ms == 8 * INTERVAL * 1000);

    /* Unknown before the obligation, a stop while it stands, cleared after. */
    for (unsigned int i = 0; i < 3; i++) {
        assert(dive.samples[i].deco_type == UINT32_MAX);
    }
    for (unsigned int i = 3; i <= 6; i++) {
        assert(dive.samples[i].deco_type == DC_DECO_DECOSTOP);
        assert(dive.samples[i].deco_time == 0);
        assert(dive.samples[i].deco_depth == 0.0);
    }
    for (unsigned int i = 7; i < 10; i++) {
        assert(dive.samples[i].deco_type == DC_DECO_NDL);
    }

    release(&dive);
    printf("PASS: test_deco_run_reports_begin_and_end\n");
}

/* Only the level that sounds the alarm is an event. */
static void test_ascent_event_only_at_the_alarm_level(void) {
    leonardo_sample_t samples[10];
    fill_recreational(samples);
    samples[6].ascent = 1;
    samples[7].ascent = 2;
    samples[8].ascent = 3;

    libdc_parsed_dive_t dive;
    parse(LEONARDO_PRODUCT, LEONARDO_MODEL, samples, 10, &dive);

    printf("  ascent levels 1/2/3: %u events\n", dive.event_count);
    assert(dive.event_count == 1);
    assert(dive.events[0].type == SAMPLE_EVENT_ASCENT);
    assert(dive.events[0].value == 3);
    assert(dive.events[0].time_ms == 9 * INTERVAL * 1000);

    release(&dive);
    printf("PASS: test_ascent_event_only_at_the_alarm_level\n");
}

/* Bit 11 and the ascent grading are confirmed on the Leonardo only, so the
   other models in this family must be untouched: every ascent level is still
   an event, and bit 11 is still ignored. */
static void test_other_models_keep_original_behaviour(void) {
    leonardo_sample_t samples[10];
    fill_recreational(samples);
    samples[4].deco = 1;
    samples[6].ascent = 1;

    libdc_parsed_dive_t dive;
    parse(GIOTTO_PRODUCT, GIOTTO_MODEL, samples, 10, &dive);

    printf("  Giotto: %u events\n", dive.event_count);
    assert(dive.event_count == 1);
    assert(dive.events[0].type == SAMPLE_EVENT_ASCENT);
    assert(dive.events[0].value == 1);
    for (unsigned int i = 0; i < dive.sample_count; i++) {
        assert(dive.samples[i].deco_type == UINT32_MAX);
    }

    release(&dive);
    printf("PASS: test_other_models_keep_original_behaviour\n");
}

/* The Leonardo reports its water temperature in the header and never as a
   sample, so the dive-level minimum is the only place it exists. */
static void test_header_supplies_the_water_temperature(void) {
    leonardo_sample_t samples[10];
    fill_recreational(samples);

    libdc_parsed_dive_t dive;
    parse(LEONARDO_PRODUCT, LEONARDO_MODEL, samples, 10, &dive);

    printf("  min_temp: %.1f C\n", dive.min_temp);
    assert(!isnan(dive.min_temp));
    assert(fabs(dive.min_temp - 18.0) < 0.001);
    for (unsigned int i = 0; i < dive.sample_count; i++) {
        assert(isnan(dive.samples[i].temperature));
    }

    release(&dive);
    printf("PASS: test_header_supplies_the_water_temperature\n");
}

int main(void) {
    printf("Running Cressi Leonardo deco and ascent tests (PR #342)...\n");
    test_no_deco_dive_leaves_obligation_unknown();
    test_deco_run_reports_begin_and_end();
    test_ascent_event_only_at_the_alarm_level();
    test_other_models_keep_original_behaviour();
    test_header_supplies_the_water_temperature();
    printf("All Cressi Leonardo deco and ascent tests passed\n");
    return 0;
}
