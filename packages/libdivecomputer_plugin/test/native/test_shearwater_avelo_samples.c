/* Issue #4664: Shearwater's Avelo sample record (type 0x03) repurposes bytes
   of the dive sample layout. Decoded from eight real Avelo dives and checked
   against Shearwater Cloud's own statistics
   (docs/design/findings/2026-11-19-avelo-sample-bytes.md):
   - sample byte 10: gas remaining, percent; 0xFE with no transmitter comms;
   - sample bytes 11-12: buoyancy, signed big-endian, grams; 0x7FFE when not
     available;
   - sample bytes 29-30: the computer's RMV, hundredths of a litre per
     minute; 0xFFF8 to 0xFFFE are special codes.
   The fork reports them as DC_SAMPLE_GASREMAINING, DC_SAMPLE_BUOYANCY (kg)
   and DC_SAMPLE_RMV (L/min); this test pins that, and that a normal dive
   sample (type 0x01), whose same bytes hold other data, reports none.

   The real dives are not committed, so the Avelo log is made from the
   Petrel 3 fixture the way test_shearwater_avelo_hydrotank does it, and the
   bytes under test are written into chosen samples. Sample byte N is record
   byte N + 1 (the record type comes first). */

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/parser.h>

#define RECORD_SIZE 32
#define OPENING_4 0x14
#define DIVE_SAMPLE 0x01
#define AVELO_SAMPLE 0x03
#define MODE_AVELO 12
#define NSAMPLES 419

typedef struct {
    unsigned int index; /* sample being reported, counted from 1 */
    unsigned int buoyancy_count;
    unsigned int gas_count;
    unsigned int rmv_count;
    int has_buoyancy[NSAMPLES];
    int has_gas[NSAMPLES];
    int has_rmv[NSAMPLES];
    double buoyancy[NSAMPLES];
    unsigned int gas[NSAMPLES];
    double rmv[NSAMPLES];
} collected_t;

static void sample_cb(dc_sample_type_t type, const dc_sample_value_t *value, void *userdata) {
    collected_t *c = (collected_t *)userdata;
    if (type == DC_SAMPLE_TIME) {
        c->index++;
        return;
    }
    if (c->index == 0 || c->index > NSAMPLES) return;
    unsigned int i = c->index - 1;
    switch (type) {
    case DC_SAMPLE_BUOYANCY:
        c->buoyancy_count++;
        c->has_buoyancy[i] = 1;
        c->buoyancy[i] = value->buoyancy;
        break;
    case DC_SAMPLE_GASREMAINING:
        c->gas_count++;
        c->has_gas[i] = 1;
        c->gas[i] = value->gasremaining;
        break;
    case DC_SAMPLE_RMV:
        c->rmv_count++;
        c->has_rmv[i] = 1;
        c->rmv[i] = value->rmv;
        break;
    default:
        break;
    }
}

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

/* Rewrites [data] in place into an Avelo log, as in
   test_shearwater_avelo_hydrotank.c. */
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
    assert(samples == NSAMPLES);
}

/* Record offset of the [n]th sample record (0x01 or 0x03), from 0. */
static unsigned int sample_record(const unsigned char *data, unsigned int size, unsigned int n) {
    unsigned int seen = 0;
    for (unsigned int off = 0; off + RECORD_SIZE <= size; off += RECORD_SIZE) {
        if (data[off] == DIVE_SAMPLE || data[off] == AVELO_SAMPLE) {
            if (seen == n) return off;
            seen++;
        }
    }
    assert(0 && "sample record not found");
    return 0;
}

/* Writes the three Avelo fields of sample [n]. */
static void set_avelo_fields(unsigned char *data, unsigned int size, unsigned int n,
                             unsigned int gas, unsigned int buoyancy, unsigned int rmv) {
    unsigned int off = sample_record(data, size, n);
    data[off + 1 + 10] = (unsigned char)gas;
    data[off + 1 + 11] = (unsigned char)(buoyancy >> 8);
    data[off + 1 + 12] = (unsigned char)(buoyancy & 0xFF);
    data[off + 1 + 29] = (unsigned char)(rmv >> 8);
    data[off + 1 + 30] = (unsigned char)(rmv & 0xFF);
}

static dc_descriptor_t *find_descriptor(const char *vendor, const char *product, unsigned int model) {
    dc_iterator_t *iter = NULL;
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) return NULL;

    dc_descriptor_t *desc = NULL;
    dc_descriptor_t *match = NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (v && p && strcmp(v, vendor) == 0 && strcmp(p, product) == 0 &&
            dc_descriptor_get_model(desc) == model) {
            match = desc;
            break;
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    return match;
}

static void parse(const unsigned char *data, unsigned int size, collected_t *c) {
    dc_context_t *context = NULL;
    assert(dc_context_new(&context) == DC_STATUS_SUCCESS);
    dc_descriptor_t *descriptor = find_descriptor("Shearwater", "Petrel 3", 10);
    assert(descriptor != NULL);
    dc_parser_t *parser = NULL;
    assert(dc_parser_new2(&parser, context, descriptor, data, size) == DC_STATUS_SUCCESS);

    memset(c, 0, sizeof(*c));
    assert(dc_parser_samples_foreach(parser, sample_cb, c) == DC_STATUS_SUCCESS);
    assert(c->index == NSAMPLES);

    dc_parser_destroy(parser);
    dc_descriptor_free(descriptor);
    dc_context_free(context);
}

static int near(double a, double b) { return fabs(a - b) < 1e-9; }

static void test_avelo_fields_are_decoded(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);
    make_avelo(data, size);
    /* Values from dive 1636: buoyancy -393 g and +1242 g, RMV 10.68 and
       29.75 L/min, gas remaining 100 and 35 percent. */
    set_avelo_fields(data, size, 0, 100, 0xFE77, 0x042C);
    set_avelo_fields(data, size, 1, 35, 0x04DA, 0x0B9F);
    set_avelo_fields(data, size, 2, 0, 0x0000, 0x0000);

    collected_t c;
    parse(data, size, &c);
    free(data);

    assert(c.has_gas[0] && c.gas[0] == 100);
    assert(c.has_gas[1] && c.gas[1] == 35);
    assert(c.has_gas[2] && c.gas[2] == 0);
    assert(c.has_buoyancy[0] && near(c.buoyancy[0], -0.393));
    assert(c.has_buoyancy[1] && near(c.buoyancy[1], 1.242));
    assert(c.has_buoyancy[2] && near(c.buoyancy[2], 0.0));
    assert(c.has_rmv[0] && near(c.rmv[0], 10.68));
    assert(c.has_rmv[1] && near(c.rmv[1], 29.75));
    assert(c.has_rmv[2] && near(c.rmv[2], 0.0));

    printf("PASS: test_avelo_fields_are_decoded\n");
}

/* Special codes seen in the real dives leave the sample without that value. */
static void test_special_codes_report_nothing(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);
    make_avelo(data, size);
    /* No transmitter comms: buoyancy 0x7FFE, gas remaining 0xFE, RMV 0xFFFE. */
    set_avelo_fields(data, size, 0, 0xFE, 0x7FFE, 0xFFFE);
    /* Before the dive and while still computing: RMV 0xFFFA, 0xFFF9, 0xFFF8. */
    set_avelo_fields(data, size, 1, 100, 0xFFA0, 0xFFFA);
    set_avelo_fields(data, size, 2, 101, 0x7FF0, 0xFFF9);
    set_avelo_fields(data, size, 3, 100, 0x0000, 0xFFF8);

    collected_t c;
    parse(data, size, &c);
    free(data);

    assert(!c.has_gas[0] && !c.has_buoyancy[0] && !c.has_rmv[0]);
    assert(!c.has_rmv[1] && !c.has_rmv[2] && !c.has_rmv[3]);
    /* Above 100 percent is no percentage. */
    assert(!c.has_gas[2]);
    /* 0x7FF0 to 0x7FFF are reserved for codes; 0xFFA0 is -96 g. */
    assert(!c.has_buoyancy[2]);
    assert(c.has_buoyancy[1] && near(c.buoyancy[1], -0.096));

    printf("PASS: test_special_codes_report_nothing\n");
}

/* A normal dive sample's bytes 10, 11-12 and 29-30 hold other data (CCR
   status, O2 cell millivolts): it must report none of the Avelo values. */
static void test_dive_samples_report_no_avelo_fields(void) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture(&data);
    assert(size == 22400);

    collected_t c;
    parse(data, size, &c);
    free(data);

    assert(c.buoyancy_count == 0);
    assert(c.gas_count == 0);
    assert(c.rmv_count == 0);

    printf("PASS: test_dive_samples_report_no_avelo_fields\n");
}

int main(void) {
    test_avelo_fields_are_decoded();
    test_special_codes_report_nothing();
    test_dive_samples_report_no_avelo_fields();
    printf("\nAll shearwater Avelo sample tests passed.\n");
    return 0;
}
