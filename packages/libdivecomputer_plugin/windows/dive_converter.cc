#include "dive_converter.h"

#include <climits>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

namespace libdivecomputer_plugin {

std::string MapEventType(unsigned int type) {
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
        default: return "unknown_" + std::to_string(type);
    }
}

ParsedDive ConvertParsedDive(const libdc_parsed_dive_t& dive) {
    // Convert fingerprint to hex string.
    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1] = {0};
    for (unsigned int i = 0; i < dive.fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive.fingerprint[i]);
    }

    // Pass raw datetime components (wall-clock-as-UTC).
    int64_t dt_year = static_cast<int64_t>(dive.year);
    int64_t dt_month = static_cast<int64_t>(dive.month);
    int64_t dt_day = static_cast<int64_t>(dive.day);
    int64_t dt_hour = static_cast<int64_t>(dive.hour);
    int64_t dt_minute = static_cast<int64_t>(dive.minute);
    int64_t dt_second = static_cast<int64_t>(dive.second);

    // INT32_MIN means "timezone not reported" per libdivecomputer convention.
    std::optional<int64_t> tz_offset =
        (dive.timezone == INT32_MIN)
            ? std::nullopt
            : std::optional<int64_t>(static_cast<int64_t>(dive.timezone));

    // Convert samples (all 14 fields, sentinels -> nullptr).
    flutter::EncodableList samples;
    if (dive.samples) {
        samples.reserve(dive.sample_count);
        for (unsigned int i = 0; i < dive.sample_count; i++) {
            const libdc_sample_t& s = dive.samples[i];

            int64_t time_seconds = static_cast<int64_t>(s.time_ms / 1000);

            // Nullable doubles: NaN -> nullptr.
            std::optional<double> temp_c =
                std::isnan(s.temperature) ? std::nullopt
                                          : std::optional<double>(s.temperature);
            std::optional<double> pressure =
                std::isnan(s.pressure) ? std::nullopt
                                       : std::optional<double>(s.pressure);
            std::optional<double> setpoint =
                std::isnan(s.setpoint) ? std::nullopt
                                       : std::optional<double>(s.setpoint);
            std::optional<double> ppo2 =
                std::isnan(s.ppo2) ? std::nullopt
                                   : std::optional<double>(s.ppo2);
            std::optional<double> cns =
                std::isnan(s.cns) ? std::nullopt
                                  : std::optional<double>(s.cns);
            std::optional<double> deco_depth =
                std::isnan(s.deco_depth) ? std::nullopt
                                         : std::optional<double>(s.deco_depth);

            // Nullable ints: UINT32_MAX -> nullptr.
            std::optional<int64_t> tank_index =
                (s.tank == UINT32_MAX)
                    ? std::nullopt
                    : std::optional<int64_t>(static_cast<int64_t>(s.tank));
            std::optional<int64_t> heart_rate =
                (s.heartbeat == UINT32_MAX)
                    ? std::nullopt
                    : std::optional<int64_t>(
                          static_cast<int64_t>(s.heartbeat));
            std::optional<int64_t> rbt =
                (s.rbt == UINT32_MAX)
                    ? std::nullopt
                    : std::optional<int64_t>(static_cast<int64_t>(s.rbt));
            std::optional<int64_t> deco_type =
                (s.deco_type == UINT32_MAX)
                    ? std::nullopt
                    : std::optional<int64_t>(
                          static_cast<int64_t>(s.deco_type));
            std::optional<int64_t> deco_time =
                (s.deco_time == UINT32_MAX)
                    ? std::nullopt
                    : std::optional<int64_t>(
                          static_cast<int64_t>(s.deco_time));
            // TTS: 0 means "not in deco" -> treat as null.
            std::optional<int64_t> tts =
                (s.deco_tts == UINT32_MAX || s.deco_tts == 0)
                    ? std::nullopt
                    : std::optional<int64_t>(
                          static_cast<int64_t>(s.deco_tts));

            samples.push_back(
                flutter::CustomEncodableValue(ProfileSample(
                    time_seconds, s.depth,
                    temp_c ? &*temp_c : nullptr,
                    pressure ? &*pressure : nullptr,
                    tank_index ? &*tank_index : nullptr,
                    heart_rate ? &*heart_rate : nullptr,
                    setpoint ? &*setpoint : nullptr,
                    ppo2 ? &*ppo2 : nullptr,
                    cns ? &*cns : nullptr,
                    rbt ? &*rbt : nullptr,
                    deco_type ? &*deco_type : nullptr,
                    deco_time ? &*deco_time : nullptr,
                    deco_depth ? &*deco_depth : nullptr,
                    tts ? &*tts : nullptr)));
        }
    }

    // Convert gas mixes.
    flutter::EncodableList gas_mixes;
    gas_mixes.reserve(dive.gasmix_count);
    for (unsigned int i = 0; i < dive.gasmix_count; i++) {
        gas_mixes.push_back(flutter::CustomEncodableValue(GasMix(
            static_cast<int64_t>(i),
            dive.gasmixes[i].oxygen * 100.0,
            dive.gasmixes[i].helium * 100.0)));
    }

    // Convert tanks.
    flutter::EncodableList tanks;
    tanks.reserve(dive.tank_count);
    for (unsigned int i = 0; i < dive.tank_count; i++) {
        const libdc_tank_t& tk = dive.tanks[i];
        double volume = tk.volume;
        double begin_p = tk.beginpressure;
        double end_p = tk.endpressure;

        std::optional<double> opt_vol =
            (volume == 0.0) ? std::nullopt : std::optional<double>(volume);
        std::optional<double> opt_begin =
            (begin_p == 0.0) ? std::nullopt : std::optional<double>(begin_p);
        std::optional<double> opt_end =
            (end_p == 0.0) ? std::nullopt : std::optional<double>(end_p);

        tanks.push_back(flutter::CustomEncodableValue(TankInfo(
            static_cast<int64_t>(i),
            static_cast<int64_t>(tk.gasmix),
            opt_vol ? &*opt_vol : nullptr,
            opt_begin ? &*opt_begin : nullptr,
            opt_end ? &*opt_end : nullptr)));
    }

    // Convert events.
    flutter::EncodableList events;
    if (dive.events) {
        for (unsigned int i = 0; i < dive.event_count; i++) {
            const libdc_event_t& e = dive.events[i];
            if (e.type == 0) continue;  // Skip EVENT_NONE.

            int64_t event_time = static_cast<int64_t>(e.time_ms / 1000);
            std::string type_name = MapEventType(e.type);

            flutter::EncodableMap data;
            data[flutter::EncodableValue("flags")] =
                flutter::EncodableValue(std::to_string(e.flags));
            data[flutter::EncodableValue("value")] =
                flutter::EncodableValue(std::to_string(e.value));

            events.push_back(flutter::CustomEncodableValue(
                DiveEvent(event_time, type_name, &data)));
        }
    }

    // Map dive mode.
    std::optional<std::string> dive_mode;
    switch (dive.dive_mode) {
        case 0: dive_mode = "freedive"; break;
        case 1: dive_mode = "gauge"; break;
        case 2: dive_mode = "open_circuit"; break;
        case 3: dive_mode = "ccr"; break;
        case 4: dive_mode = "scr"; break;
    }

    // Map deco model.
    std::optional<std::string> deco_algorithm;
    switch (dive.deco_model_type) {
        case 1: deco_algorithm = "buhlmann"; break;
        case 2: deco_algorithm = "vpm"; break;
        case 3: deco_algorithm = "rgbm"; break;
        case 4: deco_algorithm = "dciem"; break;
    }

    // Nullable temperature.
    std::optional<double> min_temp =
        std::isnan(dive.min_temp) ? std::nullopt
                                  : std::optional<double>(dive.min_temp);
    std::optional<double> max_temp =
        std::isnan(dive.max_temp) ? std::nullopt
                                  : std::optional<double>(dive.max_temp);

    // GF/conservatism: 0 means unknown -> null.
    std::optional<int64_t> gf_low =
        (dive.gf_low == 0)
            ? std::nullopt
            : std::optional<int64_t>(static_cast<int64_t>(dive.gf_low));
    std::optional<int64_t> gf_high =
        (dive.gf_high == 0)
            ? std::nullopt
            : std::optional<int64_t>(static_cast<int64_t>(dive.gf_high));
    std::optional<int64_t> deco_conservatism =
        (dive.deco_conservatism == 0)
            ? std::nullopt
            : std::optional<int64_t>(
                  static_cast<int64_t>(dive.deco_conservatism));

    // Copy raw dive data bytes if available.
    std::optional<std::vector<uint8_t>> raw_data;
    if (dive.raw_data != nullptr && dive.raw_data_size > 0) {
        raw_data.emplace(dive.raw_data, dive.raw_data + dive.raw_data_size);
    }
    std::optional<std::vector<uint8_t>> raw_fp;
    if (dive.raw_fingerprint != nullptr && dive.raw_fingerprint_size > 0) {
        raw_fp.emplace(dive.raw_fingerprint,
                       dive.raw_fingerprint + dive.raw_fingerprint_size);
    }

    return ParsedDive(
        std::string(hex),
        dt_year,
        dt_month,
        dt_day,
        dt_hour,
        dt_minute,
        dt_second,
        tz_offset ? &*tz_offset : nullptr,
        dive.max_depth,
        dive.avg_depth,
        static_cast<int64_t>(dive.duration),
        min_temp ? &*min_temp : nullptr,
        max_temp ? &*max_temp : nullptr,
        samples,
        tanks,
        gas_mixes,
        events,
        dive_mode ? &*dive_mode : nullptr,
        deco_algorithm ? &*deco_algorithm : nullptr,
        gf_low ? &*gf_low : nullptr,
        gf_high ? &*gf_high : nullptr,
        deco_conservatism ? &*deco_conservatism : nullptr,
        raw_data ? &*raw_data : nullptr,
        raw_fp ? &*raw_fp : nullptr);
}

}  // namespace libdivecomputer_plugin
