/* Issue #5098: the Halcyon Symbios logs the computer's trim angle in an
   ID_TRIM record (type 0x10, 4 bytes): a signed byte at record offset 2, in
   whole degrees, positive head up. The fork reports it as DC_SAMPLE_TRIM.
   This test pins:
   - a negative byte reads as negative (0xF3 is -13, not 243);
   - a byte outside -90 to +90 is not reported;
   - a log with no trim records reports no trim.

   No Symbios raw dive is committed, so the log is built here: a header
   record (the sample interval at offset 10), then one depth record per
   sample, each followed by the trim record under test. The parser needs no
   footer for samples. */

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/parser.h>

#define ID_HEADER 0x01
#define ID_DEPTH 0x03
#define ID_TRIM 0x10
#define HEADER_SIZE 64
#define MAX_SAMPLES 16
#define MAX_LOG (HEADER_SIZE + MAX_SAMPLES * 8)

typedef struct {
    unsigned int index; /* sample being reported, counted from 1 */
    unsigned int trim_count;
    int has_trim[MAX_SAMPLES];
    double trim[MAX_SAMPLES];
} collected_t;

static void sample_cb(dc_sample_type_t type, const dc_sample_value_t *value, void *userdata) {
    collected_t *c = (collected_t *)userdata;
    if (type == DC_SAMPLE_TIME) {
        c->index++;
        return;
    }
    if (type != DC_SAMPLE_TRIM || c->index == 0 || c->index > MAX_SAMPLES) return;
    c->trim_count++;
    c->has_trim[c->index - 1] = 1;
    c->trim[c->index - 1] = value->trim;
}

/* Builds a Handset log with one sample per entry of [trims]; a negative
   entry in [present] leaves that sample without a trim record. */
static size_t build_log(unsigned char *log, const unsigned char *trims, const int *present,
                        unsigned int nsamples) {
    memset(log, 0, MAX_LOG);
    size_t n = 0;
    log[n + 0] = ID_HEADER;
    log[n + 1] = HEADER_SIZE;
    log[n + 2] = 7;   /* model: Symbios Handset */
    log[n + 10] = 10; /* sample interval, seconds */
    n += HEADER_SIZE;
    for (unsigned int i = 0; i < nsamples; i++) {
        unsigned int depth_cm = 500 + i * 100;
        log[n + 0] = ID_DEPTH;
        log[n + 1] = 4;
        log[n + 2] = depth_cm & 0xFF;
        log[n + 3] = (depth_cm >> 8) & 0xFF;
        n += 4;
        if (present[i] > 0) {
            log[n + 0] = ID_TRIM;
            log[n + 1] = 4;
            log[n + 2] = trims[i];
            n += 4;
        }
    }
    return n;
}

static dc_descriptor_t *find_handset(void) {
    dc_iterator_t *iter = NULL;
    if (dc_descriptor_iterator(&iter) != DC_STATUS_SUCCESS || iter == NULL) return NULL;
    dc_descriptor_t *desc = NULL;
    dc_descriptor_t *match = NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        if (match == NULL && strcmp(dc_descriptor_get_vendor(desc), "Halcyon") == 0 &&
            strcmp(dc_descriptor_get_product(desc), "Symbios Handset") == 0) {
            match = desc;
            continue;
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(iter);
    return match;
}

static void parse(const unsigned char *log, size_t size, collected_t *c) {
    dc_context_t *context = NULL;
    assert(dc_context_new(&context) == DC_STATUS_SUCCESS);
    dc_descriptor_t *descriptor = find_handset();
    assert(descriptor != NULL);
    dc_parser_t *parser = NULL;
    assert(dc_parser_new2(&parser, context, descriptor, log, size) == DC_STATUS_SUCCESS);
    memset(c, 0, sizeof(*c));
    assert(dc_parser_samples_foreach(parser, sample_cb, c) == DC_STATUS_SUCCESS);
    dc_parser_destroy(parser);
    dc_descriptor_free(descriptor);
    dc_context_free(context);
}

static void test_reports_signed_degrees_and_skips_out_of_range(void) {
    const unsigned char trims[] = {0x05, 0xF3, 0x00, 0x57, 0x9C, 0x7F, 0xA6, 0x5A};
    const int present[] = {1, 1, 1, 1, 1, 1, 1, 1};
    unsigned char log[MAX_LOG];
    size_t size = build_log(log, trims, present, 8);

    collected_t c;
    parse(log, size, &c);

    assert(c.index == 8);
    assert(c.has_trim[0] && c.trim[0] == 5.0);
    assert(c.has_trim[1] && c.trim[1] == -13.0);
    assert(c.has_trim[2] && c.trim[2] == 0.0);
    assert(c.has_trim[3] && c.trim[3] == 87.0);
    assert(!c.has_trim[4]); /* 0x9C: -100 */
    assert(!c.has_trim[5]); /* 0x7F: 127 */
    assert(c.has_trim[6] && c.trim[6] == -90.0);
    assert(c.has_trim[7] && c.trim[7] == 90.0);
    assert(c.trim_count == 6);
    printf("  PASS: signed degrees, out of range skipped\n");
}

static void test_no_trim_records_report_no_trim(void) {
    const unsigned char trims[] = {0, 0, 0};
    const int present[] = {0, 0, 0};
    unsigned char log[MAX_LOG];
    size_t size = build_log(log, trims, present, 3);

    collected_t c;
    parse(log, size, &c);

    assert(c.index == 3);
    assert(c.trim_count == 0);
    printf("  PASS: no trim records, no trim\n");
}

int main(void) {
    printf("test_halcyon_symbios_trim\n");
    test_reports_signed_degrees_and_skips_out_of_range();
    test_no_trim_records_report_no_trim();
    return 0;
}
