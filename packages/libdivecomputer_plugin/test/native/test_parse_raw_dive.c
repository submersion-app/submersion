#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libdivecomputer/parser.h>
#include "checksum.h"
#include "libdc_wrapper.h"

/* Load a binary file into a malloc'd buffer. On success returns the byte count
   and sets *out to the malloc'd buffer (caller frees). On any failure returns 0
   and sets *out to NULL, so the caller can safely free/assert without touching
   an uninitialized or partially-filled buffer. */
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

/* Error path: NULL arguments should return INVALIDARGS. */
static void test_null_args(void) {
    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive(NULL, "Leonardo", 1, (const unsigned char *)"x", 1, &result, err, sizeof(err));
    assert(rc != 0);

    rc = libdc_parse_raw_dive("Cressi", "Leonardo", 1, NULL, 0, &result, err, sizeof(err));
    assert(rc != 0);

    rc = libdc_parse_raw_dive("Cressi", "Leonardo", 1, (const unsigned char *)"x", 1, NULL, err, sizeof(err));
    assert(rc != 0);

    printf("PASS: test_null_args\n");
}

/* Error path: a missing fixture must report failure and null the out pointer. */
static void test_load_fixture_missing(void) {
    unsigned char *data = (unsigned char *)0x1; /* poison: must be overwritten */
    unsigned int size = load_fixture("fixtures/does_not_exist.bin", &data);
    assert(size == 0);
    assert(data == NULL);
    printf("PASS: test_load_fixture_missing\n");
}

/* Error path: unknown descriptor should return NODEVICE. */
static void test_unknown_descriptor(void) {
    libdc_parsed_dive_t result;
    char err[256] = {0};
    unsigned char dummy[16] = {0};

    int rc = libdc_parse_raw_dive("BogusVendor", "BogusProduct", 9999, dummy, sizeof(dummy), &result, err, sizeof(err));
    assert(rc != 0);
    assert(strlen(err) > 0);
    printf("PASS: test_unknown_descriptor (error: %s)\n", err);
}

/* Happy path: parse real Cressi Leonardo dive data from fixture. */
static void test_parse_cressi_leonardo(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture("fixtures/dive1_raw.bin", &data);
    assert(size == 400);
    assert(data != NULL);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Cressi", "Leonardo", 1, data, size, &result, err, sizeof(err));
    if (rc != 0) {
        fprintf(stderr, "FAIL: parse returned %d: %s\n", rc, err);
        free(data);
        assert(0 && "libdc_parse_raw_dive failed");
    }

    /* Basic sanity checks on parsed output. */
    assert(result.max_depth > 0.0);
    assert(result.duration > 0);
    assert(result.sample_count > 0);
    assert(result.samples != NULL);

    /* Verify samples are time-ordered and depths are non-negative. */
    for (unsigned int i = 0; i < result.sample_count; i++) {
        assert(result.samples[i].depth >= 0.0);
        if (i > 0) {
            assert(result.samples[i].time_ms >= result.samples[i - 1].time_ms);
        }
    }

    printf("PASS: test_parse_cressi_leonardo (depth=%.1fm, duration=%us, samples=%u)\n",
           result.max_depth, result.duration, result.sample_count);

    free(result.samples);
    free(result.events);
    free(data);
}

/* Issue #810: the wrapper must carry the raw O2 cell output through to
   libdc_sample_t, not just the ppO2 conversion. On this Petrel 3 the logged
   calibration is a factory default, so libdivecomputer withholds the per-cell
   ppO2 (NAN) and reports the millivolts instead. */
static void test_o2_cell_millivolts_reach_the_sample(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture("fixtures/petrel3_ccr_o2_cells.bin", &data);
    assert(size == 22400);
    assert(data != NULL);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Shearwater", "Petrel 3", 10, data, size,
                                  &result, err, sizeof(err));
    if (rc != 0) {
        fprintf(stderr, "FAIL: parse returned %d: %s\n", rc, err);
        free(data);
        assert(0 && "libdc_parse_raw_dive failed for Petrel 3");
    }

    assert(result.sample_count == 419);

    unsigned int with_mv = 0;
    unsigned int mv_min = 0xFFFFFFFF, mv_max = 0;
    unsigned int samples_with_differing_cells = 0;
    for (unsigned int i = 0; i < result.sample_count; i++) {
        const libdc_sample_t *s = &result.samples[i];
        /* Only the first three cells are calibrated on this unit. */
        for (int c = 3; c < 6; c++) {
            assert(s->o2_sensor_mv[c] == UINT32_MAX);
        }
        for (int c = 0; c < 3; c++) {
            assert(s->o2_sensor_mv[c] != UINT32_MAX);
            with_mv++;
            if (s->o2_sensor_mv[c] < mv_min) mv_min = s->o2_sensor_mv[c];
            if (s->o2_sensor_mv[c] > mv_max) mv_max = s->o2_sensor_mv[c];
        }
        if (!(s->o2_sensor_mv[0] == s->o2_sensor_mv[1] &&
              s->o2_sensor_mv[1] == s->o2_sensor_mv[2])) {
            samples_with_differing_cells++;
        }
    }

    assert(with_mv == 419 * 3);
    /* A healthy cell reads 30-70 mV in 100% O2 at 1 ata. */
    assert(mv_min >= 10 && mv_max <= 120);
    /* Global min/max alone would pass on one cell's variation over time. */
    assert(samples_with_differing_cells > 0);

    /* The conversion stays withheld: a default calibration is not an anchor. */
    for (unsigned int i = 0; i < result.sample_count; i++) {
        for (int c = 0; c < 3; c++) {
            assert(isnan(result.samples[i].o2_sensor[c]));
        }
    }

    printf("PASS: test_o2_cell_millivolts_reach_the_sample (%u..%u mV)\n",
           mv_min, mv_max);

    free(result.samples);
    free(result.events);
    free(data);
}

/* --- Ratio iX3M synthetic dive (issue #926) ------------------------------
   The iX3M/iDive family does not implement DC_FIELD_LOCATION. It reports GPS
   as DC_SAMPLE_LOCATION entries inside the profile stream: an "info" record
   (type 1) carries a fix, which libdivecomputer attaches to the next real
   sample record (type 0). This builds the smallest blob that exercises that
   path so the wrapper's entry/exit extraction can be asserted without a
   device. Layout constants mirror divesystem_idive_parser.c. */

#define IX3M_HEADER_SIZE 0x36
#define IX3M_APOS4_SAMPLE_SIZE 0x40
#define IX3M_REC_SAMPLE 0
#define IX3M_REC_INFO 1
/* iX3M 2 GPS Pro. */
#define IX3M2_GPS_PRO_MODEL 0x92

static void put_u16le(unsigned char *p, unsigned int v) {
    p[0] = (unsigned char)(v & 0xFF);
    p[1] = (unsigned char)((v >> 8) & 0xFF);
}

static void put_u32le(unsigned char *p, unsigned int v) {
    p[0] = (unsigned char)(v & 0xFF);
    p[1] = (unsigned char)((v >> 8) & 0xFF);
    p[2] = (unsigned char)((v >> 16) & 0xFF);
    p[3] = (unsigned char)((v >> 24) & 0xFF);
}

/* Write a profile record of the given type at record index `idx`. */
static unsigned char *ix3m_record(unsigned char *blob, unsigned int idx) {
    return blob + IX3M_HEADER_SIZE + idx * IX3M_APOS4_SAMPLE_SIZE;
}

static void ix3m_put_sample(unsigned char *blob, unsigned int idx,
                            unsigned int time_s, unsigned int depth_dm) {
    unsigned char *rec = ix3m_record(blob, idx);
    put_u32le(rec + 2, time_s);
    put_u16le(rec + 6, depth_dm);
    put_u16le(rec + 52, IX3M_REC_SAMPLE);
}

static void ix3m_put_info(unsigned char *blob, unsigned int idx,
                          int latitude_e7, int longitude_e7) {
    unsigned char *rec = ix3m_record(blob, idx);
    put_u32le(rec + 40, 0);  /* altitude (mm) */
    put_u32le(rec + 44, (unsigned int)longitude_e7);
    put_u32le(rec + 48, (unsigned int)latitude_e7);
    put_u16le(rec + 52, IX3M_REC_INFO);
}

/* Regression test for issue #926: GPS fixes from a Ratio iX3M arrive as
   profile samples, not as DC_FIELD_LOCATION. The first fix must land in the
   entry position and the last in the exit position. */
static void test_parse_ratio_ix3m_sample_gps(void) {
    /* Malta: entry ~36.0400 / 14.3200, exit ~36.0450 / 14.3250. */
    const int entry_lat_e7 = 360400000;
    const int entry_lon_e7 = 143200000;
    const int exit_lat_e7 = 360450000;
    const int exit_lon_e7 = 143250000;

    const unsigned int nrecords = 5;
    const unsigned int size = IX3M_HEADER_SIZE + nrecords * IX3M_APOS4_SAMPLE_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    put_u16le(blob + 1, nrecords);
    /* Firmware >= 4.x selects the APOS4 sample size and the timezone-aware
       datetime path; byte 48 is the timezone index and must stay even. */
    put_u32le(blob + 0x2A, 40000000);

    ix3m_put_info(blob, 0, entry_lat_e7, entry_lon_e7);
    ix3m_put_sample(blob, 1, 0, 50);
    ix3m_put_sample(blob, 2, 10, 120);
    ix3m_put_info(blob, 3, exit_lat_e7, exit_lon_e7);
    ix3m_put_sample(blob, 4, 20, 30);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Ratio", "iX3M 2 GPS Pro", IX3M2_GPS_PRO_MODEL,
                                  blob, size, &result, err, sizeof(err));
    if (rc != 0) {
        fprintf(stderr, "FAIL: parse returned %d: %s\n", rc, err);
        free(blob);
        assert(0 && "libdc_parse_raw_dive failed for Ratio iX3M");
    }

    assert(result.sample_count == 3);

    assert(!isnan(result.entry_latitude));
    assert(!isnan(result.entry_longitude));
    assert(fabs(result.entry_latitude - 36.04) < 1e-7);
    assert(fabs(result.entry_longitude - 14.32) < 1e-7);

    assert(!isnan(result.exit_latitude));
    assert(!isnan(result.exit_longitude));
    assert(fabs(result.exit_latitude - 36.045) < 1e-7);
    assert(fabs(result.exit_longitude - 14.325) < 1e-7);

    printf("PASS: test_parse_ratio_ix3m_sample_gps (entry=%.5f,%.5f exit=%.5f,%.5f)\n",
           result.entry_latitude, result.entry_longitude,
           result.exit_latitude, result.exit_longitude);

    free(result.samples);
    free(result.events);
    free(blob);
}

/* A single GPS fix must populate the entry position only. Mirroring it into
   the exit position would render a spurious "exit point" on the map. */
static void test_parse_ratio_ix3m_single_fix(void) {
    const unsigned int nrecords = 3;
    const unsigned int size = IX3M_HEADER_SIZE + nrecords * IX3M_APOS4_SAMPLE_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    put_u16le(blob + 1, nrecords);
    put_u32le(blob + 0x2A, 40000000);

    ix3m_put_info(blob, 0, 360400000, 143200000);
    ix3m_put_sample(blob, 1, 0, 50);
    ix3m_put_sample(blob, 2, 10, 120);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Ratio", "iX3M 2 GPS Pro", IX3M2_GPS_PRO_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(fabs(result.entry_latitude - 36.04) < 1e-7);
    assert(fabs(result.entry_longitude - 14.32) < 1e-7);
    assert(isnan(result.exit_latitude));
    assert(isnan(result.exit_longitude));

    printf("PASS: test_parse_ratio_ix3m_single_fix\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* A record with no satellite fix reports 0/0. Treating Null Island as a real
   position would drop the dive in the Gulf of Guinea. */
static void test_parse_ratio_ix3m_null_island_ignored(void) {
    const unsigned int nrecords = 3;
    const unsigned int size = IX3M_HEADER_SIZE + nrecords * IX3M_APOS4_SAMPLE_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    put_u16le(blob + 1, nrecords);
    put_u32le(blob + 0x2A, 40000000);

    ix3m_put_info(blob, 0, 0, 0);
    ix3m_put_sample(blob, 1, 0, 50);
    ix3m_put_sample(blob, 2, 10, 120);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Ratio", "iX3M 2 GPS Pro", IX3M2_GPS_PRO_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(isnan(result.entry_latitude));
    assert(isnan(result.entry_longitude));
    assert(isnan(result.exit_latitude));
    assert(isnan(result.exit_longitude));

    printf("PASS: test_parse_ratio_ix3m_null_island_ignored\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* A receiver that reacquires its original position after an intermediate fix
   (A, B, A) must not leave the mid-dive position B as the exit point: the dive
   started and ended at A, so A is the one known position and there is no
   distinct exit. */
static void test_parse_ratio_ix3m_returns_to_entry(void) {
    const int a_lat_e7 = 360400000, a_lon_e7 = 143200000;
    const int b_lat_e7 = 360900000, b_lon_e7 = 143900000;

    const unsigned int nrecords = 6;
    const unsigned int size = IX3M_HEADER_SIZE + nrecords * IX3M_APOS4_SAMPLE_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    put_u16le(blob + 1, nrecords);
    put_u32le(blob + 0x2A, 40000000);

    ix3m_put_info(blob, 0, a_lat_e7, a_lon_e7);
    ix3m_put_sample(blob, 1, 0, 50);
    ix3m_put_info(blob, 2, b_lat_e7, b_lon_e7);
    ix3m_put_sample(blob, 3, 10, 120);
    ix3m_put_info(blob, 4, a_lat_e7, a_lon_e7);
    ix3m_put_sample(blob, 5, 20, 30);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Ratio", "iX3M 2 GPS Pro", IX3M2_GPS_PRO_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(fabs(result.entry_latitude - 36.04) < 1e-7);
    assert(fabs(result.entry_longitude - 14.32) < 1e-7);
    assert(isnan(result.exit_latitude));
    assert(isnan(result.exit_longitude));

    printf("PASS: test_parse_ratio_ix3m_returns_to_entry\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* A receiver that only gets a lock after surfacing yields one fix, late in the
   profile. That is the exit position, not the entry -- storing it as the entry
   would pin the dive at the wrong end. Site matching reads the exit when the
   entry is absent, so the dive still resolves to a site. */
static void test_parse_ratio_ix3m_late_fix_is_exit(void) {
    const unsigned int nrecords = 5;
    const unsigned int size = IX3M_HEADER_SIZE + nrecords * IX3M_APOS4_SAMPLE_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    put_u16le(blob + 1, nrecords);
    put_u32le(blob + 0x2A, 40000000);

    ix3m_put_sample(blob, 0, 0, 50);
    ix3m_put_sample(blob, 1, 600, 180);
    ix3m_put_sample(blob, 2, 1200, 120);
    ix3m_put_info(blob, 3, 360400000, 143200000);
    ix3m_put_sample(blob, 4, 1800, 10);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Ratio", "iX3M 2 GPS Pro", IX3M2_GPS_PRO_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(isnan(result.entry_latitude));
    assert(isnan(result.entry_longitude));
    assert(fabs(result.exit_latitude - 36.04) < 1e-7);
    assert(fabs(result.exit_longitude - 14.32) < 1e-7);

    printf("PASS: test_parse_ratio_ix3m_late_fix_is_exit\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* --- Divesoft Liberty synthetic dive --------------------------------------
   The Divesoft log is a stream of 16-byte records, each stamped with its own
   second. Only LREC_POINT records carry a depth; measurement records (O2
   cells, battery, AI pressure, GPS) and tissue-state records advance the clock
   without one. libdivecomputer opens a new sample for every distinct
   timestamp, so a second holding only a measurement record reaches the wrapper
   as DC_SAMPLE_TIME with no DC_SAMPLE_DEPTH behind it. A CCR like the Liberty
   logs those constantly. Layout constants mirror divesoft_freedom_parser.c. */

#define DS_HEADER_SIZE 64
#define DS_RECORD_SIZE 16
#define DS_SIGNATURE_V2 0x45566944 /* "DiVE" */
#define DS_LREC_POINT 0
#define DS_LREC_MEASURE 7
#define DS_POINT_1 0
#define DS_MEASURE_ID_BATTERY 1
#define DS_MEASURE_ID_GPS 4
#define DS_STMODE_CCR 2
#define DIVESOFT_LIBERTY_MODEL 10

/* Record header word: type in bits 0-3, timestamp in bits 4-20, id in 21-30. */
static unsigned int ds_flags(unsigned int type, unsigned int timestamp,
                             unsigned int id) {
    return (type & 0x0F) | ((timestamp & 0x1FFFF) << 4) | ((id & 0x3FF) << 21);
}

static unsigned char *ds_record(unsigned char *blob, unsigned int idx) {
    return blob + DS_HEADER_SIZE + idx * DS_RECORD_SIZE;
}

static void ds_put_header(unsigned char *blob, unsigned int divetime_s,
                          unsigned int maxdepth_cm) {
    put_u32le(blob + 0, DS_SIGNATURE_V2);
    put_u32le(blob + 12, divetime_s);
    blob[18] = DS_STMODE_CCR;
    put_u16le(blob + 24, 200);          /* minimum temperature, 0.1 C */
    put_u16le(blob + 28, maxdepth_cm);
    put_u16le(blob + 32, 1013);         /* surface pressure, mbar */
    put_u16le(blob + 38, maxdepth_cm / 2);
    put_u16le(blob + 4, checksum_crc16r_ansi(blob + 6, DS_HEADER_SIZE - 6,
                                             0xFFFF, 0x0000));
}

/* A general log record: depth, plus the deco state carried by POINT_1. */
static void ds_put_point(unsigned char *blob, unsigned int idx,
                         unsigned int time_s, unsigned int depth_cm,
                         unsigned int ceiling_cm, unsigned int ndl_min) {
    unsigned char *rec = ds_record(blob, idx);
    put_u32le(rec + 0, ds_flags(DS_LREC_POINT, time_s, DS_POINT_1));
    put_u16le(rec + 4, depth_cm);
    put_u16le(rec + 6, 0);  /* ppO2 */
    /* misc: NDL in bits 0-9, TTS in 10-19, temperature (0.1 C) in 20-29. */
    put_u32le(rec + 8, (ndl_min & 0x3FF) | ((200u & 0x3FF) << 20));
    put_u16le(rec + 12, ceiling_cm);
}

/* A measurement record the parser reads no sample values from: it only moves
   the clock, which is exactly the case that used to fabricate a 0 m sample. */
static void ds_put_measure_battery(unsigned char *blob, unsigned int idx,
                                   unsigned int time_s) {
    unsigned char *rec = ds_record(blob, idx);
    put_u32le(rec + 0, ds_flags(DS_LREC_MEASURE, time_s, DS_MEASURE_ID_BATTERY));
}

/* Seconds logged without a depth must be filled from the surrounding samples,
   never reported as 0 m. A fabricated surface sample mid-dive both draws a
   spike to the surface on the profile and, because the ascent-rate smoother
   spreads it across a 15 s window, invents rapid-ascent violations. The deco
   state is likewise only reported on POINT_1 records and has to persist across
   the gap, or the dive stops showing as being in deco. */
static void test_parse_divesoft_liberty_depth_gap(void) {
    const unsigned int nrecords = 6;
    const unsigned int size = DS_HEADER_SIZE + nrecords * DS_RECORD_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    ds_put_header(blob, 20, 2000);
    ds_put_point(blob, 0, 0, 0, 0, 99);        /* surface, no deco */
    ds_put_point(blob, 1, 10, 1000, 300, 0);   /* 10 m, deco stop at 3 m */
    ds_put_measure_battery(blob, 2, 11);       /* no depth, no deco */
    ds_put_point(blob, 3, 12, 1200, 300, 0);   /* 12 m */
    ds_put_measure_battery(blob, 4, 13);       /* no depth, no deco */
    ds_put_point(blob, 5, 20, 2000, 300, 0);   /* 20 m */

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Divesoft", "Liberty", DIVESOFT_LIBERTY_MODEL,
                                  blob, size, &result, err, sizeof(err));
    if (rc != 0) {
        fprintf(stderr, "FAIL: parse returned %d: %s\n", rc, err);
        free(blob);
        assert(0 && "libdc_parse_raw_dive failed for Divesoft Liberty");
    }

    assert(result.sample_count == 6);
    assert(result.samples[2].time_ms == 11000);
    assert(result.samples[4].time_ms == 13000);

    /* Interpolated from the neighbouring points, not zeroed: 10 m -> 12 m over
       two seconds puts the missing second at 11 m, and 12 m -> 20 m over eight
       seconds puts the next one at 13 m. */
    assert(fabs(result.samples[2].depth - 11.0) < 1e-6);
    assert(fabs(result.samples[4].depth - 13.0) < 1e-6);

    /* Reported depths stay untouched. */
    assert(fabs(result.samples[1].depth - 10.0) < 1e-6);
    assert(fabs(result.samples[3].depth - 12.0) < 1e-6);
    assert(fabs(result.samples[5].depth - 20.0) < 1e-6);

    /* Deco obligation persists across the gap. */
    assert(result.samples[2].deco_type == DC_DECO_DECOSTOP);
    assert(fabs(result.samples[2].deco_depth - 3.0) < 1e-6);
    assert(result.samples[4].deco_type == DC_DECO_DECOSTOP);

    /* ...but is not invented before the computer first reports one. */
    assert(result.samples[0].deco_type == DC_DECO_NDL);

    printf("PASS: test_parse_divesoft_liberty_depth_gap\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* Gaps at the ends of the profile have only one neighbour to work from, so
   they hold that neighbour's depth. A dive whose log opens or closes with a
   measurement record must not begin or end with a phantom 0 m sample. */
static void test_parse_divesoft_liberty_edge_gaps(void) {
    const unsigned int nrecords = 4;
    const unsigned int size = DS_HEADER_SIZE + nrecords * DS_RECORD_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    ds_put_header(blob, 30, 1800);
    ds_put_measure_battery(blob, 0, 0);        /* leading gap */
    ds_put_point(blob, 1, 10, 1500, 0, 5);     /* 15 m */
    ds_put_point(blob, 2, 20, 1800, 0, 5);     /* 18 m */
    ds_put_measure_battery(blob, 3, 30);       /* trailing gap */

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Divesoft", "Liberty", DIVESOFT_LIBERTY_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(result.sample_count == 4);
    assert(fabs(result.samples[0].depth - 15.0) < 1e-6);
    assert(fabs(result.samples[3].depth - 18.0) < 1e-6);

    printf("PASS: test_parse_divesoft_liberty_edge_gaps\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* A profile that never reports a depth has nothing to interpolate from. It
   must still produce finite depths -- NAN is an internal marker, and letting
   one reach the platform layers would store a NULL depth or crash a chart. */
static void test_parse_divesoft_liberty_no_depth_at_all(void) {
    const unsigned int nrecords = 2;
    const unsigned int size = DS_HEADER_SIZE + nrecords * DS_RECORD_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    ds_put_header(blob, 10, 0);
    ds_put_measure_battery(blob, 0, 0);
    ds_put_measure_battery(blob, 1, 10);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Divesoft", "Liberty", DIVESOFT_LIBERTY_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(result.sample_count == 2);
    for (unsigned int i = 0; i < result.sample_count; i++) {
        assert(!isnan(result.samples[i].depth));
        assert(result.samples[i].depth == 0.0);
    }

    printf("PASS: test_parse_divesoft_liberty_no_depth_at_all\n");

    free(result.samples);
    free(result.events);
    free(blob);
}

/* The Liberty logs a satellite fix as a measurement record inside the profile
   (DC_SAMPLE_LOCATION), the same channel as Ratio, OSTC 4 and Halcyon, and
   never as DC_FIELD_LOCATION. Coordinates are microdegrees. */
static void ds_put_measure_gps(unsigned char *blob, unsigned int idx,
                               unsigned int time_s, int latitude_e6,
                               int longitude_e6) {
    unsigned char *rec = ds_record(blob, idx);
    put_u32le(rec + 0, ds_flags(DS_LREC_MEASURE, time_s, DS_MEASURE_ID_GPS));
    put_u32le(rec + 4, (unsigned int)latitude_e6);
    put_u32le(rec + 8, (unsigned int)longitude_e6);
}

/* A Liberty's GPS fixes must reach the dive-level entry/exit positions, which
   is what dive-site matching reads. This is the same wiring issue #926 fixed
   for Ratio; the Divesoft family shares it. */
static void test_parse_divesoft_liberty_gps(void) {
    const unsigned int nrecords = 5;
    const unsigned int size = DS_HEADER_SIZE + nrecords * DS_RECORD_SIZE;
    unsigned char *blob = (unsigned char *)calloc(1, size);
    assert(blob != NULL);

    ds_put_header(blob, 20, 2000);
    ds_put_measure_gps(blob, 0, 0, 36040000, 14320000);
    ds_put_point(blob, 1, 0, 0, 0, 99);
    ds_put_point(blob, 2, 10, 2000, 0, 20);
    ds_put_measure_gps(blob, 3, 19, 36045000, 14325000);
    ds_put_point(blob, 4, 20, 100, 0, 99);

    libdc_parsed_dive_t result;
    char err[256] = {0};

    int rc = libdc_parse_raw_dive("Divesoft", "Liberty", DIVESOFT_LIBERTY_MODEL,
                                  blob, size, &result, err, sizeof(err));
    assert(rc == 0);

    assert(fabs(result.entry_latitude - 36.04) < 1e-7);
    assert(fabs(result.entry_longitude - 14.32) < 1e-7);
    assert(fabs(result.exit_latitude - 36.045) < 1e-7);
    assert(fabs(result.exit_longitude - 14.325) < 1e-7);

    printf("PASS: test_parse_divesoft_liberty_gps (entry=%.5f,%.5f exit=%.5f,%.5f)\n",
           result.entry_latitude, result.entry_longitude,
           result.exit_latitude, result.exit_longitude);

    free(result.samples);
    free(result.events);
    free(blob);
}

int main(void) {
    test_null_args();
    test_load_fixture_missing();
    test_unknown_descriptor();
    test_parse_cressi_leonardo();
    test_o2_cell_millivolts_reach_the_sample();
    test_parse_ratio_ix3m_sample_gps();
    test_parse_ratio_ix3m_single_fix();
    test_parse_ratio_ix3m_null_island_ignored();
    test_parse_ratio_ix3m_returns_to_entry();
    test_parse_ratio_ix3m_late_fix_is_exit();
    test_parse_divesoft_liberty_depth_gap();
    test_parse_divesoft_liberty_edge_gaps();
    test_parse_divesoft_liberty_no_depth_at_all();
    test_parse_divesoft_liberty_gps();
    printf("\nAll parse_raw_dive tests passed.\n");
    return 0;
}
