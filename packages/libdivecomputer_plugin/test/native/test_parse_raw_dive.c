#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "libdc_wrapper.h"

/* Load a binary file into a malloc'd buffer. Returns size, or 0 on failure. */
static unsigned int load_fixture(const char *path, unsigned char **out) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return 0; }
    *out = (unsigned char *)malloc((size_t)len);
    size_t read = fread(*out, 1, (size_t)len, f);
    fclose(f);
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

int main(void) {
    test_null_args();
    test_unknown_descriptor();
    test_parse_cressi_leonardo();
    printf("\nAll parse_raw_dive tests passed.\n");
    return 0;
}
