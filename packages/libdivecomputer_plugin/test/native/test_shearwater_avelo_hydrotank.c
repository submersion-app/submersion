/* Shearwater's Avelo mode (issue #4657) logs the Avelo Dive System's
   Hydrotank, a cylinder the diver pumps water into for buoyancy. The water
   squeezes the gas, so the transmitter's pressure rises as the diver gets
   heavier, and the app must not read it as gas used. The fork tags the
   Hydrotank's tank with DC_USAGE_HYDROTANK; this test pins that tag.

   No Avelo log is publicly available, so the Avelo log is made from the
   Petrel 3 CCR dive shared with test_tank_transmitter_serial. Shearwater's
   Petrel Native Format is a run of 32-byte records whose first byte is the
   record type (the fixture starts with opening record 0, type 0x10, at byte
   0). Two changes make it an Avelo log, both read off the parser and checked
   against the fixture by walking its records:
   - opening record 4 (type 0x14, at byte 128) holds the dive mode at its
     byte 1, 0 (CC) here; Avelo mode is 12 (M_AVELO);
   - every dive sample (type 0x01, 419 of them) becomes an Avelo sample
     (type 0x03), which shares the dive sample's layout but carries only the
     T1 transmitter's pressure. */

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libdc_wrapper.h"

#define RECORD_SIZE 32
#define OPENING_4 0x14
#define DIVE_SAMPLE 0x01
#define AVELO_SAMPLE 0x03
#define MODE_AVELO 12

#define USAGE_HYDROTANK 4u
#define T1_SERIAL 123086u
#define T2_SERIAL 109623u

static unsigned int load_fixture(unsigned char **out) {
    *out = NULL;
    FILE *f = fopen("fixtures/petrel3_ccr_o2_cells.bin", "rb");
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

/* Rewrites [data] in place into the Avelo log described above. */
static void make_avelo(unsigned char *data, unsigned int size) {
    unsigned int samples = 0;
    int mode_set = 0;
    for (unsigned int off = 0; off + RECORD_SIZE <= size; off += RECORD_SIZE) {
        if (data[off] == OPENING_4) {
            data[off + 1] = MODE_AVELO;
            mode_set = 1;
        } else if (data[off] == DIVE_SAMPLE) {
            data[off] = AVELO_SAMPLE;
            samples++;
        }
    }
    assert(mode_set);
    assert(samples == 419);
}

static void parse(libdc_parsed_dive_t *dive, int avelo) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);
    assert(data != NULL);
    if (avelo) make_avelo(data, size);

    char err[256] = {0};
    int rc = libdc_parse_raw_dive("Shearwater", "Petrel 3", 10, data, size, dive,
                                  err, sizeof(err));
    if (rc != 0) {
        printf("FAIL: libdc_parse_raw_dive returned %d (%s)\n", rc, err);
    }
    assert(rc == 0);
    free(data);
}

static void release(libdc_parsed_dive_t *dive) {
    /* libdc_parse_raw_dive fills a caller-owned struct: free its arrays. */
    free(dive->samples);
    free(dive->events);
}

/* The T1 transmitter's tank is the Hydrotank. Avelo samples carry no T2
   pressure, so T2 never becomes an active tank and only T1 is reported. */
static void test_avelo_t1_is_hydrotank(void) {
    libdc_parsed_dive_t dive;
    parse(&dive, 1);

    printf("  tank_count %u, tank 0 serial %u usage %u\n",
           dive.tank_count, dive.tanks[0].serial, dive.tanks[0].usage);
    assert(dive.tank_count == 1);
    assert(dive.tanks[0].serial == T1_SERIAL);
    assert(dive.tanks[0].usage == USAGE_HYDROTANK);
    /* Avelo mode is open circuit to everything else. */
    assert(dive.dive_mode == 2);

    release(&dive);
    printf("PASS: test_avelo_t1_is_hydrotank\n");
}

/* An Avelo log whose T1 transmitter never read a pressure (switched off)
   has no tank to tag, and must still parse. The parser reads a sample's T1
   pressure as a big-endian word at sample byte 27, offset by one in this
   format (so record byte 28); 0xFFFF is the parser's "AI is off" code. */
static void test_avelo_without_t1_tags_nothing(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);
    make_avelo(data, size);
    for (unsigned int off = 0; off + RECORD_SIZE <= size; off += RECORD_SIZE) {
        if (data[off] == AVELO_SAMPLE) {
            data[off + 28] = 0xFF;
            data[off + 29] = 0xFF;
        }
    }

    libdc_parsed_dive_t dive;
    char err[256] = {0};
    int rc = libdc_parse_raw_dive("Shearwater", "Petrel 3", 10, data, size,
                                  &dive, err, sizeof(err));
    free(data);
    assert(rc == 0);
    assert(dive.tank_count == 0);
    assert(dive.sample_count > 0);

    release(&dive);
    printf("PASS: test_avelo_without_t1_tags_nothing\n");
}

/* A T3 transmitter in Avelo mode reports through the extended sample record
   (type 0xE1, read at log version 13 and up; this fixture's opening record 4
   holds 17 at its byte 16). It is an ordinary cylinder, so only T1 is the
   Hydrotank. The fixture has no 0xE1 record, so one info event (type 0x30)
   becomes one: its T3 pressure is a big-endian word at record byte 1, in
   units of 2 psi, here 0x0640 (3200 psi). */
static void test_avelo_t3_stays_untagged(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);
    make_avelo(data, size);
    int converted = 0;
    for (unsigned int off = 0; off + RECORD_SIZE <= size; off += RECORD_SIZE) {
        if (data[off] == 0x30) {
            memset(data + off, 0, RECORD_SIZE);
            data[off] = 0xE1;
            data[off + 1] = 0x06;
            data[off + 2] = 0x40;
            converted = 1;
            break;
        }
    }
    assert(converted);

    libdc_parsed_dive_t dive;
    char err[256] = {0};
    int rc = libdc_parse_raw_dive("Shearwater", "Petrel 3", 10, data, size,
                                  &dive, err, sizeof(err));
    free(data);
    assert(rc == 0);

    printf("  tank_count %u\n", dive.tank_count);
    assert(dive.tank_count == 2);
    unsigned int hydrotanks = 0;
    for (unsigned int t = 0; t < dive.tank_count; t++) {
        if (dive.tanks[t].usage == USAGE_HYDROTANK) {
            hydrotanks++;
            assert(dive.tanks[t].serial == T1_SERIAL);
        }
    }
    assert(hydrotanks == 1);

    release(&dive);
    printf("PASS: test_avelo_t3_stays_untagged\n");
}

/* The same log outside Avelo mode carries no Hydrotank. */
static void test_non_avelo_has_no_hydrotank(void) {
    libdc_parsed_dive_t dive;
    parse(&dive, 0);

    assert(dive.tank_count == 2);
    for (unsigned int t = 0; t < dive.tank_count; t++) {
        assert(dive.tanks[t].usage != USAGE_HYDROTANK);
    }
    assert(dive.tanks[1].serial == T2_SERIAL);

    release(&dive);
    printf("PASS: test_non_avelo_has_no_hydrotank\n");
}

/* Issue #4664: the Avelo sample's gas remaining, buoyancy and computer RMV
   reach the wrapper's sample struct, with the absent markers where the
   computer logged a code. Sample byte N is record byte N + 1. */
static void set_avelo_fields(unsigned char *rec, unsigned int gas,
                             unsigned int buoyancy, unsigned int rmv) {
    rec[1 + 10] = (unsigned char)gas;
    rec[1 + 11] = (unsigned char)(buoyancy >> 8);
    rec[1 + 12] = (unsigned char)(buoyancy & 0xFF);
    rec[1 + 29] = (unsigned char)(rmv >> 8);
    rec[1 + 30] = (unsigned char)(rmv & 0xFF);
}

static void test_avelo_samples_reach_the_wrapper(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);
    make_avelo(data, size);
    unsigned int n = 0;
    for (unsigned int off = 0; off + RECORD_SIZE <= size; off += RECORD_SIZE) {
        if (data[off] != AVELO_SAMPLE) continue;
        if (n == 0) set_avelo_fields(data + off, 100, 0xFE77, 0x042C);
        if (n == 1) set_avelo_fields(data + off, 0xFE, 0x7FFE, 0xFFFE);
        if (++n == 2) break;
    }

    libdc_parsed_dive_t dive;
    char err[256] = {0};
    int rc = libdc_parse_raw_dive("Shearwater", "Petrel 3", 10, data, size,
                                  &dive, err, sizeof(err));
    free(data);
    assert(rc == 0);
    assert(dive.sample_count == 419);

    assert(dive.samples[0].gas_remaining == 100);
    assert(fabs(dive.samples[0].avelo_buoyancy - (-0.393)) < 1e-9);
    assert(fabs(dive.samples[0].computer_rmv - 10.68) < 1e-9);
    assert(dive.samples[1].gas_remaining == UINT32_MAX);
    assert(isnan(dive.samples[1].avelo_buoyancy));
    assert(isnan(dive.samples[1].computer_rmv));

    release(&dive);
    printf("PASS: test_avelo_samples_reach_the_wrapper\n");
}

/* Outside Avelo mode the same bytes hold CCR data: the wrapper reports the
   Avelo fields as absent on every sample. */
static void test_dive_samples_have_no_avelo_fields(void) {
    libdc_parsed_dive_t dive;
    parse(&dive, 0);
    for (unsigned int i = 0; i < dive.sample_count; i++) {
        assert(dive.samples[i].gas_remaining == UINT32_MAX);
        assert(isnan(dive.samples[i].avelo_buoyancy));
        assert(isnan(dive.samples[i].computer_rmv));
    }
    release(&dive);
    printf("PASS: test_dive_samples_have_no_avelo_fields\n");
}

int main(void) {
    printf("Running Shearwater Avelo Hydrotank tests...\n");
    test_avelo_t1_is_hydrotank();
    test_avelo_without_t1_tags_nothing();
    test_avelo_t3_stays_untagged();
    test_non_avelo_has_no_hydrotank();
    test_avelo_samples_reach_the_wrapper();
    test_dive_samples_have_no_avelo_fields();
    printf("All Shearwater Avelo Hydrotank tests passed\n");
    return 0;
}
