#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <libdivecomputer/parser.h>
#include "libdc_wrapper.h"

/* Every platform binding used to carry its own copy of the event-name table,
   and every copy skipped SAMPLE_EVENT_RBT, so each code from 2 upward was
   off by one: an ascent-rate alarm (SAMPLE_EVENT_ASCENT) came through as
   "ceiling" and was displayed as a deco violation on no-deco dives (Mares
   Sirius report on ScubaBoard, 2026-08-30). The table now lives in the C
   wrapper, and this test pins each name to the enum SYMBOL rather than a
   magic number, so an upstream enum change fails here instead of in a
   diver's profile. */
static const struct {
    parser_sample_event_t type;
    const char *name;
} expected[] = {
    { SAMPLE_EVENT_NONE, "none" },
    { SAMPLE_EVENT_DECOSTOP, "deco" },
    { SAMPLE_EVENT_RBT, "rbt" },
    { SAMPLE_EVENT_ASCENT, "ascent" },
    { SAMPLE_EVENT_CEILING, "ceiling" },
    { SAMPLE_EVENT_WORKLOAD, "workload" },
    { SAMPLE_EVENT_TRANSMITTER, "transmitter" },
    { SAMPLE_EVENT_VIOLATION, "violation" },
    { SAMPLE_EVENT_BOOKMARK, "bookmark" },
    { SAMPLE_EVENT_SURFACE, "surface" },
    { SAMPLE_EVENT_SAFETYSTOP, "safetystop" },
    { SAMPLE_EVENT_GASCHANGE, "gaschange" },
    { SAMPLE_EVENT_SAFETYSTOP_VOLUNTARY, "safetystop_voluntary" },
    { SAMPLE_EVENT_SAFETYSTOP_MANDATORY, "safetystop_mandatory" },
    { SAMPLE_EVENT_DEEPSTOP, "deepstop" },
    { SAMPLE_EVENT_CEILING_SAFETYSTOP, "ceiling_safetystop" },
    { SAMPLE_EVENT_FLOOR, "floor" },
    { SAMPLE_EVENT_DIVETIME, "divetime" },
    { SAMPLE_EVENT_MAXDEPTH, "maxdepth" },
    { SAMPLE_EVENT_OLF, "OLF" },
    { SAMPLE_EVENT_PO2, "PO2" },
    { SAMPLE_EVENT_AIRTIME, "airtime" },
    { SAMPLE_EVENT_RGBM, "rgbm" },
    { SAMPLE_EVENT_HEADING, "heading" },
    { SAMPLE_EVENT_TISSUELEVEL, "tissuelevel" },
    { SAMPLE_EVENT_GASCHANGE2, "gaschange2" },
};

static void test_every_enum_member_has_its_name(void) {
    size_t count = sizeof(expected) / sizeof(expected[0]);
    for (size_t i = 0; i < count; i++) {
        const char *actual = libdc_event_type_name(expected[i].type);
        assert(actual != NULL);
        if (strcmp(actual, expected[i].name) != 0) {
            printf("FAIL: code %u expected \"%s\" got \"%s\"\n",
                   (unsigned int)expected[i].type, expected[i].name, actual);
            assert(0);
        }
    }
    /* The table above must cover the whole enum, in order. */
    assert(count == (size_t)SAMPLE_EVENT_GASCHANGE2 + 1);
    for (size_t i = 0; i < count; i++) {
        assert((size_t)expected[i].type == i);
    }
    printf("PASS: test_every_enum_member_has_its_name (%zu names)\n", count);
}

/* The Mares Icon HD family raises SAMPLE_EVENT_ASCENT for its fast-ascent
   and slow-down alarms, several times on an ordinary recreational dive.
   Those must never surface as a ceiling breach. */
static void test_ascent_alarm_is_not_a_ceiling(void) {
    const char *name = libdc_event_type_name(SAMPLE_EVENT_ASCENT);
    assert(strcmp(name, "ascent") == 0);
    assert(strcmp(name, "ceiling") != 0);
    assert(strcmp(libdc_event_type_name(SAMPLE_EVENT_CEILING), "ceiling") == 0);
    printf("PASS: test_ascent_alarm_is_not_a_ceiling\n");
}

static void test_codes_outside_the_enum_are_unknown(void) {
    assert(strcmp(libdc_event_type_name(SAMPLE_EVENT_GASCHANGE2 + 1),
                  "unknown") == 0);
    assert(strcmp(libdc_event_type_name(UINT_MAX), "unknown") == 0);
    printf("PASS: test_codes_outside_the_enum_are_unknown\n");
}

/* The clock sync outcome crosses every binding as one of these names; the
   Dart side switches on the spelling, so it is pinned here beside the event
   table (issue #1216). */
static void test_clock_sync_status_names(void) {
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_NOT_REQUESTED),
                  "not_requested") == 0);
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_SYNCED),
                  "synced") == 0);
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_UNSUPPORTED),
                  "unsupported") == 0);
    assert(strcmp(libdc_clock_sync_status_name(LIBDC_CLOCK_SYNC_FAILED),
                  "failed") == 0);
    assert(strcmp(libdc_clock_sync_status_name((libdc_clock_sync_status_t)99),
                  "unknown") == 0);
    printf("PASS: test_clock_sync_status_names\n");
}

int main(void) {
    test_every_enum_member_has_its_name();
    test_ascent_alarm_is_not_a_ceiling();
    test_codes_outside_the_enum_are_unknown();
    test_clock_sync_status_names();
    printf("All event type name tests passed.\n");
    return 0;
}
