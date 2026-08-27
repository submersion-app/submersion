/* Issue #810: the Petrel 3 writes the factory default calibration value for
   every O2 cell, which libdivecomputer read as "never calibrated" and used to
   suppress the cell samples entirely.

   Fixture: the dive attached to #810, reduced to its raw PNF log blob with the
   computer serial anonymised. */

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/parser.h>

#define NCELLS 3

/* A healthy cell reads 30-70 mV in 100% O2 at 1 ata. */
#define MV_MIN 10
#define MV_MAX 120

typedef struct {
    unsigned int aggregate;         /* DC_SAMPLE_PPO2 with DC_SENSOR_NONE */
    unsigned int cells;             /* DC_SAMPLE_PPO2 with a sensor index */
    unsigned int per_cell[NCELLS];
    unsigned int finite_ppo2;       /* per-cell samples carrying a usable ppO2 */
    unsigned int mv_in_range;
    unsigned int mv_min;
    unsigned int mv_max;
    unsigned int samples_with_differing_cells;
    unsigned int pending[NCELLS];   /* cells seen since the last aggregate */
    unsigned int npending;
    double last_aggregate;
} counters_t;

/* The aggregate precedes each sample's cells, so it marks the boundary. */
static void flush_pending(counters_t *c) {
    if (c->npending == NCELLS &&
        !(c->pending[0] == c->pending[1] && c->pending[1] == c->pending[2])) {
        c->samples_with_differing_cells++;
    }
    c->npending = 0;
}

static void sample_cb(dc_sample_type_t type, const dc_sample_value_t *value, void *userdata) {
    counters_t *c = (counters_t *)userdata;

    if (type != DC_SAMPLE_PPO2) return;

    if (value->ppo2.sensor == DC_SENSOR_NONE) {
        flush_pending(c);
        c->aggregate++;
        c->last_aggregate = value->ppo2.value;
        return;
    }

    c->cells++;
    if (value->ppo2.sensor < NCELLS) c->per_cell[value->ppo2.sensor]++;
    if (!isnan(value->ppo2.value)) c->finite_ppo2++;

    unsigned int mv = value->ppo2.millivolt;
    if (mv >= MV_MIN && mv <= MV_MAX) c->mv_in_range++;
    if (mv < c->mv_min) c->mv_min = mv;
    if (mv > c->mv_max) c->mv_max = mv;
    if (c->npending < NCELLS) c->pending[c->npending++] = mv;
}

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

static void parse_fixture(counters_t *counters) {
    unsigned char *data = NULL;
    unsigned int size = load_fixture("fixtures/petrel3_ccr_o2_cells.bin", &data);
    assert(size == 22400);
    assert(data != NULL);

    dc_context_t *context = NULL;
    assert(dc_context_new(&context) == DC_STATUS_SUCCESS);

    dc_descriptor_t *descriptor = find_descriptor("Shearwater", "Petrel 3", 10);
    assert(descriptor != NULL);

    dc_parser_t *parser = NULL;
    assert(dc_parser_new2(&parser, context, descriptor, data, size) == DC_STATUS_SUCCESS);

    memset(counters, 0, sizeof(*counters));
    counters->mv_min = 0xFFFFFFFF;
    assert(dc_parser_samples_foreach(parser, sample_cb, counters) == DC_STATUS_SUCCESS);
    flush_pending(counters); /* the final sample has no aggregate after it */

    dc_parser_destroy(parser);
    dc_descriptor_free(descriptor);
    dc_context_free(context);
    free(data);
}

/* The aggregate curve must be unaffected by any of this. */
static void test_aggregate_ppo2_still_reported(void) {
    counters_t c;
    parse_fixture(&c);

    assert(c.aggregate == 419);
    assert(c.last_aggregate > 0.0);

    printf("PASS: test_aggregate_ppo2_still_reported (%u samples)\n", c.aggregate);
}

static void test_per_cell_samples_are_reported(void) {
    counters_t c;
    parse_fixture(&c);

    assert(c.cells > 0);
    for (unsigned int i = 0; i < NCELLS; ++i) {
        assert(c.per_cell[i] == 419);
    }

    printf("PASS: test_per_cell_samples_are_reported (%u samples across %d cells)\n",
           c.cells, NCELLS);
}

static void test_per_cell_samples_carry_millivolts(void) {
    counters_t c;
    parse_fixture(&c);

    /* Without this the rest holds vacuously when no cells are reported. */
    assert(c.cells > 0);
    assert(c.mv_in_range == c.cells);
    assert(c.mv_min <= c.mv_max);
    assert(c.mv_min >= MV_MIN && c.mv_max <= MV_MAX);
    /* Global min/max would pass on time variation alone. */
    assert(c.samples_with_differing_cells > 0);

    printf("PASS: test_per_cell_samples_carry_millivolts (%u..%u mV)\n", c.mv_min, c.mv_max);
}

/* Factory default calibration: the conversion must be withheld, not guessed. */
static void test_ppo2_withheld_when_calibration_untrusted(void) {
    counters_t c;
    parse_fixture(&c);

    assert(c.finite_ppo2 == 0);

    printf("PASS: test_ppo2_withheld_when_calibration_untrusted\n");
}

int main(void) {
    test_aggregate_ppo2_still_reported();
    test_per_cell_samples_are_reported();
    test_per_cell_samples_carry_millivolts();
    test_ppo2_withheld_when_calibration_untrusted();
    printf("\nAll shearwater O2 millivolt tests passed.\n");
    return 0;
}
