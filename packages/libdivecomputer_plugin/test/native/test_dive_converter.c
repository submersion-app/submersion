#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "libdc_wrapper.h"

static void test_sample_sentinels(void) {
    libdc_sample_t sample = {0};
    sample.time_ms = 60000;
    sample.depth = 10.5;
    sample.temperature = NAN;
    sample.pressure = NAN;
    sample.tank = UINT32_MAX;
    sample.heartbeat = UINT32_MAX;
    sample.setpoint = NAN;
    sample.ppo2 = 1.2;
    sample.cns = 45.0;
    sample.rbt = 600;
    sample.deco_type = 0;
    sample.deco_time = 300;
    sample.deco_depth = NAN;
    sample.deco_tts = 0;

    assert(sample.time_ms == 60000);
    assert(sample.depth == 10.5);
    assert(isnan(sample.temperature));
    assert(isnan(sample.pressure));
    assert(sample.tank == UINT32_MAX);
    assert(sample.heartbeat == UINT32_MAX);
    assert(isnan(sample.setpoint));
    assert(sample.ppo2 == 1.2);
    assert(sample.cns == 45.0);
    assert(sample.rbt == 600);
    assert(sample.deco_type == 0);
    assert(sample.deco_time == 300);
    assert(isnan(sample.deco_depth));
    assert(sample.deco_tts == 0);
    printf("PASS: test_sample_sentinels\n");
}

static void test_sample_valid_values(void) {
    libdc_sample_t sample = {0};
    sample.time_ms = 120000;
    sample.depth = 30.2;
    sample.temperature = 22.5;
    sample.pressure = 180.0;
    sample.tank = 0;
    sample.heartbeat = 85;
    sample.setpoint = 1.3;
    sample.ppo2 = 1.1;
    sample.cns = 12.5;
    sample.rbt = 45;
    sample.deco_type = 2;
    sample.deco_time = 180;
    sample.deco_depth = 6.0;
    sample.deco_tts = 420;

    assert(sample.time_ms == 120000);
    assert(sample.depth == 30.2);
    assert(!isnan(sample.temperature));
    assert(sample.temperature == 22.5);
    assert(!isnan(sample.pressure));
    assert(sample.pressure == 180.0);
    assert(sample.tank != UINT32_MAX);
    assert(sample.tank == 0);
    assert(sample.heartbeat != UINT32_MAX);
    assert(sample.heartbeat == 85);
    assert(!isnan(sample.setpoint));
    assert(sample.setpoint == 1.3);
    assert(!isnan(sample.ppo2));
    assert(sample.ppo2 == 1.1);
    assert(!isnan(sample.cns));
    assert(sample.cns == 12.5);
    assert(sample.rbt != UINT32_MAX);
    assert(sample.rbt == 45);
    assert(sample.deco_type != UINT32_MAX);
    assert(sample.deco_type == 2);
    assert(sample.deco_time != UINT32_MAX);
    assert(sample.deco_time == 180);
    assert(!isnan(sample.deco_depth));
    assert(sample.deco_depth == 6.0);
    assert(sample.deco_tts != UINT32_MAX && sample.deco_tts != 0);
    assert(sample.deco_tts == 420);
    printf("PASS: test_sample_valid_values\n");
}

static void test_deco_model_sentinels(void) {
    libdc_parsed_dive_t dive = {0};
    dive.deco_model_type = 1;
    dive.gf_low = 30;
    dive.gf_high = 70;
    dive.deco_conservatism = 0;

    assert(dive.deco_model_type == 1);
    assert(dive.gf_low == 30);
    assert(dive.gf_high == 70);
    assert(dive.deco_conservatism == 0);
    printf("PASS: test_deco_model_sentinels\n");
}

static void test_deco_model_unknown(void) {
    libdc_parsed_dive_t dive = {0};
    dive.deco_model_type = 0;
    dive.gf_low = 0;
    dive.gf_high = 0;
    dive.deco_conservatism = 0;

    assert(dive.deco_model_type == 0);
    assert(dive.gf_low == 0);
    assert(dive.gf_high == 0);
    printf("PASS: test_deco_model_unknown\n");
}

static void test_fingerprint_hex(void) {
    libdc_parsed_dive_t dive = {0};
    dive.fingerprint[0] = 0xAB;
    dive.fingerprint[1] = 0xCD;
    dive.fingerprint[2] = 0xEF;
    dive.fingerprint_size = 3;

    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1] = {0};
    for (unsigned int i = 0; i < dive.fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive.fingerprint[i]);
    }
    assert(strcmp(hex, "abcdef") == 0);
    printf("PASS: test_fingerprint_hex\n");
}

static void test_fingerprint_full_length(void) {
    libdc_parsed_dive_t dive = {0};
    dive.fingerprint_size = LIBDC_MAX_FINGERPRINT;
    for (unsigned int i = 0; i < LIBDC_MAX_FINGERPRINT; i++) {
        dive.fingerprint[i] = (unsigned char)i;
    }

    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1] = {0};
    for (unsigned int i = 0; i < dive.fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive.fingerprint[i]);
    }
    assert(strlen(hex) == LIBDC_MAX_FINGERPRINT * 2);
    assert(hex[0] == '0' && hex[1] == '0');
    assert(hex[2] == '0' && hex[3] == '1');
    printf("PASS: test_fingerprint_full_length\n");
}

static void test_event_fields(void) {
    libdc_event_t event = {0};
    event.time_ms = 30000;
    event.type = 10;
    event.flags = 2;
    event.value = 21;

    assert(event.time_ms == 30000);
    assert(event.type == 10);
    assert(event.flags == 2);
    assert(event.value == 21);
    printf("PASS: test_event_fields\n");
}

static void test_event_count_zero(void) {
    libdc_parsed_dive_t dive = {0};
    dive.event_count = 0;
    dive.events = NULL;
    assert(dive.event_count == 0);
    assert(dive.events == NULL);
    printf("PASS: test_event_count_zero\n");
}

static void test_gasmix_fractions(void) {
    libdc_gasmix_t mix = {0};
    mix.oxygen = 0.21;
    mix.helium = 0.35;

    assert(mix.oxygen == 0.21);
    assert(mix.helium == 0.35);
    // Percent conversion used by all platforms.
    assert(mix.oxygen * 100.0 == 21.0);
    assert(mix.helium * 100.0 == 35.0);
    printf("PASS: test_gasmix_fractions\n");
}

static void test_tank_fields(void) {
    libdc_tank_t tank = {0};
    tank.gasmix = 0;
    tank.volume = 12.0;
    tank.beginpressure = 200.0;
    tank.endpressure = 50.0;

    assert(tank.gasmix == 0);
    assert(tank.volume == 12.0);
    assert(tank.beginpressure == 200.0);
    assert(tank.endpressure == 50.0);
    printf("PASS: test_tank_fields\n");
}

static void test_dive_mode_values(void) {
    // Verify expected enum values from libdivecomputer.
    libdc_parsed_dive_t dive = {0};

    dive.dive_mode = 0;
    assert(dive.dive_mode == 0);  // freedive

    dive.dive_mode = 2;
    assert(dive.dive_mode == 2);  // open_circuit

    dive.dive_mode = 3;
    assert(dive.dive_mode == 3);  // ccr

    dive.dive_mode = 4;
    assert(dive.dive_mode == 4);  // scr
    printf("PASS: test_dive_mode_values\n");
}

static void test_temperature_sentinels(void) {
    libdc_parsed_dive_t dive = {0};
    dive.min_temp = NAN;
    dive.max_temp = 28.5;

    assert(isnan(dive.min_temp));
    assert(!isnan(dive.max_temp));
    assert(dive.max_temp == 28.5);
    printf("PASS: test_temperature_sentinels\n");
}

int main(void) {
    test_sample_sentinels();
    test_sample_valid_values();
    test_deco_model_sentinels();
    test_deco_model_unknown();
    test_fingerprint_hex();
    test_fingerprint_full_length();
    test_event_fields();
    test_event_count_zero();
    test_gasmix_fractions();
    test_tank_fields();
    test_dive_mode_values();
    test_temperature_sentinels();
    printf("\nAll tests passed.\n");
    return 0;
}
