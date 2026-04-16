#include "dive_converter.h"

#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

const char* map_event_type(unsigned int type) {
    switch (type) {
        case 0: return "none";
        case 1: return "deco";
        case 2: return "ascent";
        case 3: return "ceiling";
        case 4: return "workload";
        case 5: return "transmitter";
        case 6: return "violation";
        case 7: return "bookmark";
        case 8: return "surface";
        case 9: return "safetystop";
        case 10: return "gaschange";
        case 11: return "safetystop_voluntary";
        case 12: return "safetystop_mandatory";
        case 13: return "deepstop";
        case 14: return "ceiling_safetystop";
        case 15: return "floor";
        case 16: return "divetime";
        case 17: return "maxdepth";
        case 18: return "OLF";
        case 19: return "PO2";
        case 20: return "airtime";
        case 21: return "rgbm";
        case 22: return "heading";
        case 23: return "tissuelevel";
        case 24: return "gaschange2";
        default: return "unknown";
    }
}

LibdivecomputerPluginParsedDive* convert_parsed_dive(
    const libdc_parsed_dive_t* dive) {
    if (!dive) return NULL;

    // Convert fingerprint to hex string.
    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1] = {0};
    for (unsigned int i = 0; i < dive->fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive->fingerprint[i]);
    }

    // Pass raw datetime components (wall-clock-as-UTC).
    int64_t dt_year = (int64_t)dive->year;
    int64_t dt_month = (int64_t)dive->month;
    int64_t dt_day = (int64_t)dive->day;
    int64_t dt_hour = (int64_t)dive->hour;
    int64_t dt_minute = (int64_t)dive->minute;
    int64_t dt_second = (int64_t)dive->second;

    // INT32_MIN means "timezone not reported" per libdivecomputer convention.
    int64_t tz_val = (int64_t)dive->timezone;
    int64_t* tz_offset =
        (dive->timezone == INT32_MIN) ? NULL : &tz_val;

    // Convert samples (all 14 fields, sentinels -> NULL).
    FlValue* samples = fl_value_new_list();
    if (dive->samples) {
        for (unsigned int i = 0; i < dive->sample_count; i++) {
            const libdc_sample_t* s = &dive->samples[i];

            int64_t time_seconds = (int64_t)(s->time_ms / 1000);

            // Nullable doubles: NaN -> NULL pointer.
            double temp_val = s->temperature;
            double* temp_c = isnan(temp_val) ? NULL : &temp_val;

            double press_val = s->pressure;
            double* pressure = isnan(press_val) ? NULL : &press_val;

            double sp_val = s->setpoint;
            double* setpoint = isnan(sp_val) ? NULL : &sp_val;

            double ppo2_val = s->ppo2;
            double* ppo2 = isnan(ppo2_val) ? NULL : &ppo2_val;

            double cns_val = s->cns;
            double* cns = isnan(cns_val) ? NULL : &cns_val;

            double dd_val = s->deco_depth;
            double* deco_depth = isnan(dd_val) ? NULL : &dd_val;

            // Nullable ints: UINT32_MAX -> NULL pointer.
            int64_t tank_val = (int64_t)s->tank;
            int64_t* tank_index =
                (s->tank == UINT32_MAX) ? NULL : &tank_val;

            int64_t hr_val = (int64_t)s->heartbeat;
            int64_t* heart_rate =
                (s->heartbeat == UINT32_MAX) ? NULL : &hr_val;

            int64_t rbt_val = (int64_t)s->rbt;
            int64_t* rbt = (s->rbt == UINT32_MAX) ? NULL : &rbt_val;

            int64_t dt_val = (int64_t)s->deco_type;
            int64_t* deco_type =
                (s->deco_type == UINT32_MAX) ? NULL : &dt_val;

            int64_t dtm_val = (int64_t)s->deco_time;
            int64_t* deco_time =
                (s->deco_time == UINT32_MAX) ? NULL : &dtm_val;

            // TTS: 0 means "not in deco" -> treat as null.
            int64_t tts_val = (int64_t)s->deco_tts;
            int64_t* tts =
                (s->deco_tts == UINT32_MAX || s->deco_tts == 0)
                    ? NULL
                    : &tts_val;

            LibdivecomputerPluginProfileSample* sample =
                libdivecomputer_plugin_profile_sample_new(
                    time_seconds, s->depth, temp_c, pressure, tank_index,
                    heart_rate, setpoint, ppo2, cns, rbt, deco_type,
                    deco_time, deco_depth, tts);

            fl_value_append_take(
                samples,
                fl_value_new_custom_object(132, G_OBJECT(sample)));
            g_object_unref(sample);
        }
    }

    // Convert gas mixes.
    FlValue* gas_mixes = fl_value_new_list();
    for (unsigned int i = 0; i < dive->gasmix_count; i++) {
        LibdivecomputerPluginGasMix* mix =
            libdivecomputer_plugin_gas_mix_new(
                (int64_t)i,
                dive->gasmixes[i].oxygen * 100.0,
                dive->gasmixes[i].helium * 100.0);
        fl_value_append_take(
            gas_mixes,
            fl_value_new_custom_object(133, G_OBJECT(mix)));
        g_object_unref(mix);
    }

    // Convert tanks.
    FlValue* tanks = fl_value_new_list();
    for (unsigned int i = 0; i < dive->tank_count; i++) {
        const libdc_tank_t* tk = &dive->tanks[i];

        double vol_val = tk->volume;
        double* volume = (vol_val == 0.0) ? NULL : &vol_val;

        double bp_val = tk->beginpressure;
        double* begin_p = (bp_val == 0.0) ? NULL : &bp_val;

        double ep_val = tk->endpressure;
        double* end_p = (ep_val == 0.0) ? NULL : &ep_val;

        LibdivecomputerPluginTankInfo* tank =
            libdivecomputer_plugin_tank_info_new(
                (int64_t)i, (int64_t)tk->gasmix, volume, begin_p, end_p);
        fl_value_append_take(
            tanks,
            fl_value_new_custom_object(134, G_OBJECT(tank)));
        g_object_unref(tank);
    }

    // Convert events.
    FlValue* events = fl_value_new_list();
    if (dive->events) {
        for (unsigned int i = 0; i < dive->event_count; i++) {
            const libdc_event_t* e = &dive->events[i];
            if (e->type == 0) continue;  // Skip EVENT_NONE.

            int64_t event_time = (int64_t)(e->time_ms / 1000);
            const char* type_name = map_event_type(e->type);

            // Build data map with flags and value as strings.
            FlValue* data = fl_value_new_map();
            char flags_str[32];
            char value_str[32];
            snprintf(flags_str, sizeof(flags_str), "%u", e->flags);
            snprintf(value_str, sizeof(value_str), "%u", e->value);
            fl_value_set_string_take(
                data, "flags", fl_value_new_string(flags_str));
            fl_value_set_string_take(
                data, "value", fl_value_new_string(value_str));

            LibdivecomputerPluginDiveEvent* event =
                libdivecomputer_plugin_dive_event_new(
                    event_time, type_name, data);
            fl_value_append_take(
                events,
                fl_value_new_custom_object(135, G_OBJECT(event)));
            g_object_unref(event);
            fl_value_unref(data);
        }
    }

    // Map dive mode.
    const char* dive_mode = NULL;
    switch (dive->dive_mode) {
        case 0: dive_mode = "freedive"; break;
        case 1: dive_mode = "gauge"; break;
        case 2: dive_mode = "open_circuit"; break;
        case 3: dive_mode = "ccr"; break;
        case 4: dive_mode = "scr"; break;
    }

    // Map deco model.
    const char* deco_algorithm = NULL;
    switch (dive->deco_model_type) {
        case 1: deco_algorithm = "buhlmann"; break;
        case 2: deco_algorithm = "vpm"; break;
        case 3: deco_algorithm = "rgbm"; break;
        case 4: deco_algorithm = "dciem"; break;
    }

    // Nullable temperatures.
    double min_t_val = dive->min_temp;
    double* min_temp = isnan(min_t_val) ? NULL : &min_t_val;
    double max_t_val = dive->max_temp;
    double* max_temp = isnan(max_t_val) ? NULL : &max_t_val;

    // GF/conservatism: 0 means unknown -> NULL.
    int64_t gf_low_val = (int64_t)dive->gf_low;
    int64_t* gf_low = (dive->gf_low == 0) ? NULL : &gf_low_val;

    int64_t gf_high_val = (int64_t)dive->gf_high;
    int64_t* gf_high = (dive->gf_high == 0) ? NULL : &gf_high_val;

    int64_t conserv_val = (int64_t)dive->deco_conservatism;
    int64_t* conservatism =
        (dive->deco_conservatism == 0) ? NULL : &conserv_val;

    // Raw dive data: pass pointer and length (NULL/0 if not available).
    const uint8_t* raw_data =
        (dive->raw_data != NULL && dive->raw_data_size > 0)
            ? dive->raw_data : NULL;
    size_t raw_data_length =
        (raw_data != NULL) ? (size_t)dive->raw_data_size : 0;

    const uint8_t* raw_fp =
        (dive->raw_fingerprint != NULL && dive->raw_fingerprint_size > 0)
            ? dive->raw_fingerprint : NULL;
    size_t raw_fp_length =
        (raw_fp != NULL) ? (size_t)dive->raw_fingerprint_size : 0;

    LibdivecomputerPluginParsedDive* result =
        libdivecomputer_plugin_parsed_dive_new(
            hex, dt_year, dt_month, dt_day, dt_hour, dt_minute, dt_second,
            tz_offset, dive->max_depth, dive->avg_depth,
            (int64_t)dive->duration, min_temp, max_temp, samples, tanks,
            gas_mixes, events, dive_mode, deco_algorithm, gf_low, gf_high,
            conservatism, raw_data, raw_data_length, raw_fp, raw_fp_length);

    fl_value_unref(samples);
    fl_value_unref(gas_mixes);
    fl_value_unref(tanks);
    fl_value_unref(events);

    return result;
}
