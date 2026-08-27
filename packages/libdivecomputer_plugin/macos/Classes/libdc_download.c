// Download session implementation for libdivecomputer.
// Handles the full lifecycle: context -> descriptor -> iostream -> device -> parse.

#include "libdc_wrapper.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
#endif

#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/device.h>
#include <libdivecomputer/parser.h>
#include <libdivecomputer/iostream.h>
#include <libdivecomputer/custom.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/datetime.h>

// ============================================================
// Internal Types
// ============================================================

struct libdc_download_session {
    volatile int cancelled;
    dc_context_t *context;
    // Last ERROR-level message libdivecomputer logged during this session's
    // run. The generic "Download failed" surfaced to the app hid the
    // protocol-level cause (issue #766 took three rounds of user logs to
    // localize); appending this message to error_buf puts the diagnosis in
    // the app log and the UI on every platform.
    char last_error[160];
};

// Data passed through the download pipeline callbacks.
typedef struct {
    libdc_download_session_t *session;
    const libdc_download_callbacks_t *callbacks;
    dc_descriptor_t *descriptor;
    dc_device_t *device;
    int dive_count;
    unsigned int serial;
    unsigned int firmware;
    char *error_buf;
    size_t error_buf_size;
} download_state_t;

// Data collected during sample iteration.
typedef struct {
    libdc_parsed_dive_t *dive;
    int has_pending_sample;
    unsigned int current_gasmix;  // active gas index, carried across samples
    // Deco obligation, likewise carried: it is state the computer holds, not a
    // reading it retakes, so it stands until the computer reports a new one.
    unsigned int current_deco_type;
    unsigned int current_deco_time;
    double current_deco_depth;
    unsigned int current_deco_tts;
    libdc_sample_t current_sample;
    // GPS reported as profile samples (see DC_SAMPLE_LOCATION below). Fixes
    // are only collected here and resolved once the whole profile has been
    // walked: which end of the dive a lone fix belongs to is knowable only
    // relative to the profile's full length.
    int has_field_entry;  // DC_FIELD_LOCATION already supplied the entry
    int has_field_exit;   // ...and/or the exit
    unsigned int location_count;
    double first_latitude;
    double first_longitude;
    unsigned int first_location_time_ms;
    double last_latitude;
    double last_longitude;
} sample_state_t;

// ============================================================
// Helpers
// ============================================================

static void set_error(download_state_t *state, const char *msg) {
    if (state->error_buf != NULL && state->error_buf_size > 0) {
        strncpy(state->error_buf, msg, state->error_buf_size - 1);
        state->error_buf[state->error_buf_size - 1] = '\0';
    }
}

static dc_descriptor_t *find_descriptor(const char *vendor, const char *product,
                                         unsigned int model) {
    dc_iterator_t *iter = NULL;
    dc_status_t status = dc_descriptor_iterator(&iter);
    if (status != DC_STATUS_SUCCESS || iter == NULL) {
        return NULL;
    }

    dc_descriptor_t *desc = NULL;
    dc_descriptor_t *match = NULL;
    while (dc_iterator_next(iter, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        unsigned int m = dc_descriptor_get_model(desc);
        if (v != NULL && p != NULL &&
            strcmp(v, vendor) == 0 && strcmp(p, product) == 0 &&
            (model == 0 || m == model)) {
            match = desc;
            break;
        }
        dc_descriptor_free(desc);
    }

    dc_iterator_free(iter);
    return match;
}

static void push_sample(sample_state_t *state) {
    if (!state->has_pending_sample) {
        return;
    }
    libdc_parsed_dive_t *dive = state->dive;

    if (dive->sample_count >= dive->sample_capacity) {
        unsigned int new_cap = dive->sample_capacity == 0 ? 256 :
                               dive->sample_capacity * 2;
        libdc_sample_t *new_buf = realloc(dive->samples,
                                          new_cap * sizeof(libdc_sample_t));
        if (new_buf == NULL) {
            return;
        }
        dive->samples = new_buf;
        dive->sample_capacity = new_cap;
    }

    dive->samples[dive->sample_count++] = state->current_sample;
    state->has_pending_sample = 0;
}

// A dive computer with no satellite lock reports 0/0 rather than omitting the
// record, and a corrupt record can yield values far outside the WGS84 range.
// Either would place the dive somewhere it never happened, so both are dropped.
static int is_usable_location(double latitude, double longitude) {
    if (isnan(latitude) || isnan(longitude)) {
        return 0;
    }
    if (latitude == 0.0 && longitude == 0.0) {
        return 0;
    }
    return latitude >= -90.0 && latitude <= 90.0 &&
           longitude >= -180.0 && longitude <= 180.0;
}

static void push_event(libdc_parsed_dive_t *dive,
                        unsigned int time_ms,
                        unsigned int type,
                        unsigned int flags,
                        unsigned int value) {
    if (dive->event_count >= dive->event_capacity) {
        unsigned int new_cap = dive->event_capacity == 0 ? 64 :
                               dive->event_capacity * 2;
        if (new_cap > LIBDC_MAX_EVENTS) {
            new_cap = LIBDC_MAX_EVENTS;
        }
        if (dive->event_count >= new_cap) {
            return;  // at capacity
        }
        libdc_event_t *new_buf = realloc(dive->events,
                                          new_cap * sizeof(libdc_event_t));
        if (new_buf == NULL) {
            return;
        }
        dive->events = new_buf;
        dive->event_capacity = new_cap;
    }
    libdc_event_t *evt = &dive->events[dive->event_count++];
    evt->time_ms = time_ms;
    evt->type = type;
    evt->flags = flags;
    evt->value = value;
}

// ============================================================
// Callbacks
// ============================================================

static int cancel_callback(void *userdata) {
    download_state_t *state = (download_state_t *)userdata;
    return state->session->cancelled;
}

static void event_callback(dc_device_t *device, dc_event_type_t event,
                            const void *data, void *userdata) {
    download_state_t *state = (download_state_t *)userdata;
    (void)device;

    if (event == DC_EVENT_PROGRESS && state->callbacks->on_progress != NULL) {
        const dc_event_progress_t *progress = (const dc_event_progress_t *)data;
        state->callbacks->on_progress(progress->current, progress->maximum,
                                      state->callbacks->userdata);
    } else if (event == DC_EVENT_DEVINFO) {
        const dc_event_devinfo_t *devinfo = (const dc_event_devinfo_t *)data;
        state->serial = devinfo->serial;
        state->firmware = devinfo->firmware;
    }
}

static void sample_callback(dc_sample_type_t type,
                             const dc_sample_value_t *value,
                             void *userdata) {
    sample_state_t *state = (sample_state_t *)userdata;

    switch (type) {
    case DC_SAMPLE_TIME:
        push_sample(state);
        state->has_pending_sample = 1;
        state->current_sample.time_ms = value->time;
        // NAN, not 0.0: libdivecomputer opens a sample for every timestamp in
        // the log, and several families stamp records that carry no depth
        // (Divesoft logs O2-cell, battery, GPS and tissue records on their own
        // second). Defaulting to 0.0 turned every one of those into a sample at
        // the surface. fill_missing_depths() resolves the NANs once the whole
        // profile is known -- no NAN depth ever leaves this file.
        state->current_sample.depth = NAN;
        state->current_sample.temperature = NAN;
        state->current_sample.pressure = NAN;
        state->current_sample.tank = UINT32_MAX;
        for (unsigned int t = 0; t < LIBDC_MAX_TANKS; t++) {
            state->current_sample.tank_pressure[t] = NAN;
        }
        // Carry the active gas forward across samples, not just the switch sample.
        state->current_sample.gasmix = state->current_gasmix;
        state->current_sample.heartbeat = UINT32_MAX;
        state->current_sample.heading = UINT32_MAX;
        state->current_sample.setpoint = NAN;
        state->current_sample.ppo2 = NAN;
        for (int cell = 0; cell < 6; cell++) {
            state->current_sample.o2_sensor[cell] = NAN;
            state->current_sample.o2_sensor_mv[cell] = UINT32_MAX;
        }
        state->current_sample.cns = NAN;
        state->current_sample.rbt = UINT32_MAX;
        // Carry the deco state forward for the same reason as the gas: a
        // record that carries no deco field is not the computer saying the
        // obligation cleared. Divesoft reports deco only on its POINT_1
        // records, so resetting here dropped the diver out of deco on every
        // other sample and hid the deco stop entirely.
        state->current_sample.deco_type = state->current_deco_type;
        state->current_sample.deco_time = state->current_deco_time;
        state->current_sample.deco_depth = state->current_deco_depth;
        state->current_sample.deco_tts = state->current_deco_tts;
        break;
    case DC_SAMPLE_DEPTH:
        state->current_sample.depth = value->depth;
        break;
    case DC_SAMPLE_TEMPERATURE:
        state->current_sample.temperature = value->temperature;
        break;
    case DC_SAMPLE_PRESSURE:
        // Issue #1223. libdivecomputer fires this once per transmitter, so a
        // single sample can carry a reading for several tanks. Record each one
        // against its own tank; keeping only the pair below dropped every tank
        // but the last, which drew the others as a flat "(est.)" line.
        if (value->pressure.tank < LIBDC_MAX_TANKS) {
            state->current_sample.tank_pressure[value->pressure.tank] =
                value->pressure.value;
        }
        state->current_sample.pressure = value->pressure.value;
        state->current_sample.tank = value->pressure.tank;
        break;
    case DC_SAMPLE_GASMIX:
        // Per-sample active gas (replaces the deprecated SAMPLE_EVENT_GASCHANGE).
        state->current_gasmix = value->gasmix;
        state->current_sample.gasmix = value->gasmix;
        break;
    case DC_SAMPLE_HEARTBEAT:
        state->current_sample.heartbeat = value->heartbeat;
        break;
    case DC_SAMPLE_BEARING:
        state->current_sample.heading = value->bearing;
        break;
    case DC_SAMPLE_SETPOINT:
        state->current_sample.setpoint = value->setpoint;
        break;
    case DC_SAMPLE_PPO2:
        // libdivecomputer fires this once per O2 cell (sensor = 0,1,2,...) and
        // optionally once with DC_SENSOR_NONE for the aggregate/computed value.
        // Keep the aggregate in `ppo2`; store each cell separately. Don't derive
        // ppo2 from a cell -- the Dart layer averages the cells when no
        // aggregate is present.
        if (value->ppo2.sensor == DC_SENSOR_NONE) {
            state->current_sample.ppo2 = value->ppo2.value;
        } else if (value->ppo2.sensor < 6) {
            state->current_sample.o2_sensor[value->ppo2.sensor] =
                value->ppo2.value;
            // Zero means the device reports no millivolts; keep the sentinel so
            // it does not reach the chart as a flat 0 mV line.
            if (value->ppo2.millivolt) {
                state->current_sample.o2_sensor_mv[value->ppo2.sensor] =
                    value->ppo2.millivolt;
            }
        }
        break;
    case DC_SAMPLE_CNS:
        state->current_sample.cns = value->cns * 100.0;  // fraction to percentage
        break;
    case DC_SAMPLE_RBT:
        state->current_sample.rbt = value->rbt;
        break;
    case DC_SAMPLE_DECO:
        state->current_deco_type = value->deco.type;
        state->current_deco_time = value->deco.time;
        state->current_deco_depth = value->deco.depth;
        state->current_deco_tts = value->deco.tts;
        state->current_sample.deco_type = value->deco.type;
        state->current_sample.deco_time = value->deco.time;
        state->current_sample.deco_depth = value->deco.depth;
        state->current_sample.deco_tts = value->deco.tts;
        break;
    case DC_SAMPLE_LOCATION:
        // Issue #926. Most GPS-capable families -- Ratio / DiveSystem iX3M and
        // iDive, Halcyon Symbios, OSTC 4, Divesoft Freedom -- do not implement
        // DC_FIELD_LOCATION at all, emitting each fix as a profile sample
        // instead. Record the first and last usable fix and the time of the
        // first; resolve_sample_locations() turns them into the dive-level
        // entry/exit positions once the profile length is known.
        if (!is_usable_location(value->location.latitude,
                                value->location.longitude)) {
            break;
        }
        if (state->location_count == 0) {
            state->first_latitude = value->location.latitude;
            state->first_longitude = value->location.longitude;
            state->first_location_time_ms = state->current_sample.time_ms;
        }
        state->last_latitude = value->location.latitude;
        state->last_longitude = value->location.longitude;
        state->location_count++;
        break;
    case DC_SAMPLE_EVENT:
        push_event(state->dive,
                   state->current_sample.time_ms,
                   value->event.type,
                   value->event.flags,
                   value->event.value);
        break;
    default:
        break;
    }
}

// Resolve the depths left as NAN by the profile walk (see DC_SAMPLE_TIME).
// Must run after the final push_sample(), because a gap is filled from the
// samples on both sides of it.
//
// Depth is the one sample field with no null representation downstream
// (ProfileSample.depthMeters is non-nullable, and dive_profiles.depth is
// written unconditionally), so a value has to be chosen here. Linear
// interpolation in time is the honest one: it keeps the diver on the path the
// computer actually recorded between the two depths it reported. Repeating the
// previous depth instead would flatten the trace and then jump, and the
// ascent-rate calculator smooths over a ~15 s window -- one such step becomes a
// sustained false rate spread across it, which is exactly how a fabricated
// sample turns into a rapid-ascent safety finding.
static void fill_missing_depths(sample_state_t *state) {
    libdc_parsed_dive_t *dive = state->dive;
    unsigned int count = dive->sample_count;
    unsigned int prev = UINT32_MAX;  // last sample with a reported depth

    for (unsigned int i = 0; i < count; i++) {
        if (isnan(dive->samples[i].depth)) {
            continue;
        }
        if (prev == UINT32_MAX) {
            // Leading gap: nothing earlier to interpolate from, so hold the
            // first reported depth. The dive starts at the surface anyway.
            for (unsigned int j = 0; j < i; j++) {
                dive->samples[j].depth = dive->samples[i].depth;
            }
        } else {
            unsigned int t0 = dive->samples[prev].time_ms;
            unsigned int t1 = dive->samples[i].time_ms;
            double d0 = dive->samples[prev].depth;
            double d1 = dive->samples[i].depth;
            for (unsigned int j = prev + 1; j < i; j++) {
                double fraction = t1 > t0
                    ? (double)(dive->samples[j].time_ms - t0) / (double)(t1 - t0)
                    : 0.0;
                dive->samples[j].depth = d0 + (d1 - d0) * fraction;
            }
        }
        prev = i;
    }

    if (prev == UINT32_MAX) {
        // The computer reported no depth anywhere in this profile. Nothing can
        // be inferred, but a NAN must not escape: it would reach the platform
        // layers as a null depth or a broken chart axis.
        for (unsigned int i = 0; i < count; i++) {
            dive->samples[i].depth = 0.0;
        }
        return;
    }

    // Trailing gap: hold the last reported depth.
    for (unsigned int i = prev + 1; i < count; i++) {
        dive->samples[i].depth = dive->samples[prev].depth;
    }
}

// Turn the per-sample GPS fixes collected during the profile walk into the
// dive-level entry/exit positions the rest of the app consumes. Must run after
// the final push_sample() so the profile's length is known.
static void resolve_sample_locations(sample_state_t *state) {
    libdc_parsed_dive_t *dive = state->dive;

    if (state->location_count == 0) {
        return;
    }

    // Two different positions: the dive genuinely moved between the first and
    // last lock, so they are the entry and exit points.
    //
    // Exact equality is deliberate here, not an oversight. Every source
    // quantizes to an integer before we see it -- int32 / 1e7 for Ratio, / 1e6
    // for Halcyon and Divesoft, and an exactly-widened float32 for OSTC 4 --
    // and this file only copies the value, so identical device bytes always
    // produce bit-identical doubles. Equality therefore means "the device
    // replayed the same record", which is the only case worth collapsing. A
    // distance tolerance would instead discard real data: a shore dive exits a
    // few metres from where it entered, and those are two genuine fixes.
    if (state->first_latitude != state->last_latitude ||
        state->first_longitude != state->last_longitude) {
        if (!state->has_field_entry) {
            dive->entry_latitude = state->first_latitude;
            dive->entry_longitude = state->first_longitude;
        }
        if (!state->has_field_exit) {
            dive->exit_latitude = state->last_latitude;
            dive->exit_longitude = state->last_longitude;
        }
        return;
    }

    // Every fix reported the same position, so this dive has one known point
    // rather than an entry/exit pair. Writing it to both slots would render a
    // bogus second marker, and always calling it the entry is wrong for a
    // receiver that only got a lock after surfacing -- a real case now that
    // OSTC 4 and Divesoft, which log fixes anywhere in the profile, reach this
    // code. Let its timestamp pick the end it belongs to. Either slot resolves
    // a dive site: the matcher falls back to the exit when entry is absent.
    unsigned int profile_end_ms = dive->sample_count > 0
        ? dive->samples[dive->sample_count - 1].time_ms
        : 0;
    if (state->first_location_time_ms <= profile_end_ms / 2) {
        if (!state->has_field_entry) {
            dive->entry_latitude = state->first_latitude;
            dive->entry_longitude = state->first_longitude;
        }
    } else if (!state->has_field_exit) {
        dive->exit_latitude = state->first_latitude;
        dive->exit_longitude = state->first_longitude;
    }
}

// Extract all fields (datetime, summary, deco model, gas mixes, tanks, samples)
// from an already-created parser into the dive struct.
// Returns 0 on success.
static int extract_dive_fields(dc_parser_t *parser, libdc_parsed_dive_t *dive) {
    // Extract datetime.
    dc_datetime_t dt = {0};
    if (dc_parser_get_datetime(parser, &dt) == DC_STATUS_SUCCESS) {
        dive->year = dt.year;
        dive->month = dt.month;
        dive->day = dt.day;
        dive->hour = dt.hour;
        dive->minute = dt.minute;
        dive->second = dt.second;
        dive->timezone = dt.timezone;
    }

    // Extract summary fields.
    double dval = 0;
    unsigned int uval = 0;

    if (dc_parser_get_field(parser, DC_FIELD_MAXDEPTH, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->max_depth = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_AVGDEPTH, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->avg_depth = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_DIVETIME, 0, &uval) == DC_STATUS_SUCCESS) {
        dive->duration = uval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_TEMPERATURE_MINIMUM, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->min_temp = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_TEMPERATURE_MAXIMUM, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->max_temp = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_DIVEMODE, 0, &uval) == DC_STATUS_SUCCESS) {
        dive->dive_mode = uval;
    }

    // Extract decompression model.
    dc_decomodel_t decomodel = {0};
    if (dc_parser_get_field(parser, DC_FIELD_DECOMODEL, 0, &decomodel) == DC_STATUS_SUCCESS) {
        dive->deco_model_type = decomodel.type;
        dive->deco_conservatism = decomodel.conservatism;
        dive->gf_low = decomodel.params.gf.low;
        dive->gf_high = decomodel.params.gf.high;
    }

    // Extract GPS entry/exit fixes (Shearwater Swift). flags: 0=entry, 1=exit.
    // Patched libdivecomputer maps these to opening[9]/closing[9] record 9.
    // Families that report GPS per-sample instead are handled in
    // sample_callback's DC_SAMPLE_LOCATION branch.
    // Tracked per side: a parser that supplies only the entry via the field
    // while reporting the exit per-sample must not lose its exit.
    int has_field_entry = 0;
    int has_field_exit = 0;
    dc_location_t loc = {0};
    if (dc_parser_get_field(parser, DC_FIELD_LOCATION, 0, &loc) == DC_STATUS_SUCCESS) {
        dive->entry_latitude = loc.latitude;
        dive->entry_longitude = loc.longitude;
        has_field_entry = 1;
    }
    if (dc_parser_get_field(parser, DC_FIELD_LOCATION, 1, &loc) == DC_STATUS_SUCCESS) {
        dive->exit_latitude = loc.latitude;
        dive->exit_longitude = loc.longitude;
        has_field_exit = 1;
    }

    // Extract gas mixes.
    unsigned int gasmix_count = 0;
    if (dc_parser_get_field(parser, DC_FIELD_GASMIX_COUNT, 0, &gasmix_count) == DC_STATUS_SUCCESS) {
        if (gasmix_count > LIBDC_MAX_GASMIXES) gasmix_count = LIBDC_MAX_GASMIXES;
        for (unsigned int i = 0; i < gasmix_count; i++) {
            dc_gasmix_t gm = {0};
            if (dc_parser_get_field(parser, DC_FIELD_GASMIX, i, &gm) == DC_STATUS_SUCCESS) {
                dive->gasmixes[i].oxygen = gm.oxygen;
                dive->gasmixes[i].helium = gm.helium;
            }
        }
        dive->gasmix_count = gasmix_count;
    }

    // Extract tanks.
    unsigned int tank_count = 0;
    if (dc_parser_get_field(parser, DC_FIELD_TANK_COUNT, 0, &tank_count) == DC_STATUS_SUCCESS) {
        if (tank_count > LIBDC_MAX_TANKS) tank_count = LIBDC_MAX_TANKS;
        for (unsigned int i = 0; i < tank_count; i++) {
            dc_tank_t tk = {0};
            if (dc_parser_get_field(parser, DC_FIELD_TANK, i, &tk) == DC_STATUS_SUCCESS) {
                dive->tanks[i].gasmix = tk.gasmix;
                dive->tanks[i].volume = tk.volume;
                dive->tanks[i].workpressure = tk.workpressure;
                dive->tanks[i].beginpressure = tk.beginpressure;
                dive->tanks[i].endpressure = tk.endpressure;
                dive->tanks[i].usage = tk.usage;
            }
        }
        dive->tank_count = tank_count;
    }

    // Extract profile samples.
    sample_state_t sample_state = {0};
    sample_state.dive = dive;
    sample_state.current_gasmix = UINT32_MAX;  // 0 is a valid gas index
    sample_state.current_deco_type = UINT32_MAX;  // no obligation reported yet
    sample_state.current_deco_depth = NAN;
    sample_state.current_deco_tts = UINT32_MAX;
    sample_state.has_field_entry = has_field_entry;
    sample_state.has_field_exit = has_field_exit;
    dc_parser_samples_foreach(parser, sample_callback, &sample_state);
    push_sample(&sample_state);
    fill_missing_depths(&sample_state);
    resolve_sample_locations(&sample_state);

    return 0;
}

static int parse_dive(download_state_t *state,
                       const unsigned char *data, unsigned int size,
                       const unsigned char *fingerprint, unsigned int fsize,
                       libdc_parsed_dive_t *dive) {
    memset(dive, 0, sizeof(*dive));
    dive->min_temp = NAN;
    dive->max_temp = NAN;
    dive->entry_latitude = NAN;
    dive->entry_longitude = NAN;
    dive->exit_latitude = NAN;
    dive->exit_longitude = NAN;
    dive->deco_model_type = 0;  // DC_DECOMODEL_NONE
    dive->deco_conservatism = 0;
    dive->gf_low = 0;
    dive->gf_high = 0;
    dive->events = NULL;
    dive->event_count = 0;
    dive->event_capacity = 0;
    dive->raw_data = NULL;
    dive->raw_data_size = 0;
    dive->raw_fingerprint = NULL;
    dive->raw_fingerprint_size = 0;

    // Store fingerprint.
    if (fingerprint != NULL && fsize > 0) {
        unsigned int copy_size = fsize < LIBDC_MAX_FINGERPRINT ?
                                 fsize : LIBDC_MAX_FINGERPRINT;
        memcpy(dive->fingerprint, fingerprint, copy_size);
        dive->fingerprint_size = copy_size;
    }

    // Create parser.
    dc_parser_t *parser = NULL;
    dc_status_t status = dc_parser_new(&parser, state->device, data, size);
    if (status != DC_STATUS_SUCCESS || parser == NULL) {
        return -1;
    }

    int result = extract_dive_fields(parser, dive);

    dc_parser_destroy(parser);
    return result;
}

static int dive_callback(const unsigned char *data, unsigned int size,
                          const unsigned char *fingerprint, unsigned int fsize,
                          void *userdata) {
    download_state_t *state = (download_state_t *)userdata;

    if (state->session->cancelled) {
        return 0;
    }

    libdc_parsed_dive_t dive;
    if (parse_dive(state, data, size, fingerprint, fsize, &dive) == 0) {
        // Retain raw bytes for archival (pointers valid for this callback scope)
        dive.raw_data = data;
        dive.raw_data_size = size;
        dive.raw_fingerprint = fingerprint;
        dive.raw_fingerprint_size = fsize;

        if (state->callbacks->on_dive != NULL) {
            state->callbacks->on_dive(&dive, state->callbacks->userdata);
        }
        state->dive_count++;
    }

    // Free dynamically allocated data.
    free(dive.samples);
    free(dive.events);

    return 1;  // continue
}

// ============================================================
// Custom iostream bridge (wraps Swift BLE callbacks)
// ============================================================

static dc_status_t bridge_set_timeout(void *userdata, int timeout) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->set_timeout == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->set_timeout(cbs->userdata, timeout);
}

static dc_status_t bridge_read(void *userdata, void *data, size_t size,
                                size_t *actual) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->read == NULL) return DC_STATUS_UNSUPPORTED;
    return (dc_status_t)cbs->read(cbs->userdata, data, size, actual);
}

static dc_status_t bridge_write(void *userdata, const void *data, size_t size,
                                 size_t *actual) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->write == NULL) return DC_STATUS_UNSUPPORTED;
    return (dc_status_t)cbs->write(cbs->userdata, data, size, actual);
}

static dc_status_t bridge_ioctl(void *userdata, unsigned int request,
                                 void *data, size_t size) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->ioctl == NULL) return DC_STATUS_UNSUPPORTED;
    return (dc_status_t)cbs->ioctl(cbs->userdata, request, data, size);
}

static dc_status_t bridge_close(void *userdata) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->close == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->close(cbs->userdata);
}

static dc_status_t bridge_poll(void *userdata, int timeout) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->poll == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->poll(cbs->userdata, timeout);
}

static dc_status_t bridge_purge(void *userdata, dc_direction_t direction) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->purge == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->purge(cbs->userdata, (unsigned int)direction);
}

static dc_status_t bridge_sleep(void *userdata, unsigned int milliseconds) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->sleep == NULL) {
#ifdef _WIN32
        Sleep(milliseconds);
#else
        struct timespec ts;
        ts.tv_sec = milliseconds / 1000;
        ts.tv_nsec = (milliseconds % 1000) * 1000000L;
        nanosleep(&ts, NULL);
#endif
        return DC_STATUS_SUCCESS;
    }
    return (dc_status_t)cbs->sleep(cbs->userdata, milliseconds);
}

static dc_status_t bridge_configure(void *userdata, unsigned int baudrate,
                                    unsigned int databits, dc_parity_t parity,
                                    dc_stopbits_t stopbits,
                                    dc_flowcontrol_t flowcontrol) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->configure == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->configure(cbs->userdata, baudrate, databits,
                                       parity, stopbits, flowcontrol);
}

static dc_status_t bridge_set_dtr(void *userdata, unsigned int value) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->set_dtr == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->set_dtr(cbs->userdata, value);
}

static dc_status_t bridge_set_rts(void *userdata, unsigned int value) {
    libdc_io_callbacks_t *cbs = (libdc_io_callbacks_t *)userdata;
    if (cbs->set_rts == NULL) return DC_STATUS_SUCCESS;
    return (dc_status_t)cbs->set_rts(cbs->userdata, value);
}

// ============================================================
// Download Session
// ============================================================

// Adapter that bridges dc_logfunc_t to libdc_log_callback_fn.
// g_log_callback/g_log_userdata are defined in libdc_wrapper.c and accessed
// via the public API function libdc_set_log_callback.
// We declare the globals extern here so this translation unit can read them
// without exposing them in the public header.
extern libdc_log_callback_fn g_log_callback;
extern void *g_log_userdata;

static void libdc_logfunc_wrapper(dc_context_t *context, dc_loglevel_t loglevel,
                                   const char *file, unsigned int line,
                                   const char *function, const char *message,
                                   void *userdata) {
    (void)context; (void)file; (void)line; (void)function;
    if (g_log_callback != NULL && message != NULL) {
        g_log_callback((int)loglevel, message, g_log_userdata);
    }
    // Keep the most recent ERROR so a failed run can report its actual
    // protocol-level cause instead of a bare "Download failed".
    libdc_download_session_t *session = (libdc_download_session_t *)userdata;
    if (session != NULL && message != NULL && loglevel == DC_LOGLEVEL_ERROR) {
        strncpy(session->last_error, message, sizeof(session->last_error) - 1);
        session->last_error[sizeof(session->last_error) - 1] = '\0';
    }
}

libdc_download_session_t *libdc_download_session_new(void) {
    libdc_download_session_t *session = calloc(1, sizeof(*session));
    if (session == NULL) {
        return NULL;
    }

    dc_status_t status = dc_context_new(&session->context);
    if (status != DC_STATUS_SUCCESS) {
        free(session);
        return NULL;
    }

    // Route libdivecomputer's internal diagnostic messages through the
    // registered log callback if one has been set, and capture the last
    // error-level message for failure reporting either way.
    dc_context_set_loglevel(session->context, DC_LOGLEVEL_ALL);
    dc_context_set_logfunc(session->context, libdc_logfunc_wrapper, session);

    return session;
}

void libdc_download_cancel(libdc_download_session_t *session) {
    if (session != NULL) {
        session->cancelled = 1;
    }
}

void libdc_download_session_free(libdc_download_session_t *session) {
    if (session == NULL) {
        return;
    }
    if (session->context != NULL) {
        dc_context_free(session->context);
    }
    free(session);
}

int libdc_download_run(
    libdc_download_session_t *session,
    const char *vendor, const char *product, unsigned int model,
    unsigned int transport,
    const libdc_io_callbacks_t *io_callbacks,
    const unsigned char *fingerprint, unsigned int fsize,
    const libdc_download_callbacks_t *callbacks,
    unsigned int *serial_out,
    unsigned int *firmware_out,
    char *error_buf, size_t error_buf_size)
{
    if (session == NULL || vendor == NULL || product == NULL ||
        io_callbacks == NULL || callbacks == NULL) {
        return LIBDC_STATUS_INVALIDARGS;
    }

    download_state_t state = {0};
    state.session = session;
    state.callbacks = callbacks;
    state.error_buf = error_buf;
    state.error_buf_size = error_buf_size;
    session->last_error[0] = '\0';

    // 1. Find matching descriptor.
    state.descriptor = find_descriptor(vendor, product, model);
    if (state.descriptor == NULL) {
        set_error(&state, "No matching device descriptor found");
        return LIBDC_STATUS_NODEVICE;
    }

    // Use the descriptor's actual transport if the caller passed a generic
    // USB transport but the device is really serial (e.g., Cressi Leonardo).
    unsigned int actual_transport = transport;
    unsigned int desc_transports = dc_descriptor_get_transports(state.descriptor);
    if ((transport & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        !(desc_transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) &&
        (desc_transports & LIBDC_TRANSPORT_SERIAL)) {
        actual_transport = LIBDC_TRANSPORT_SERIAL;
    }

    // 2. Create custom iostream bridging to Swift BLE callbacks.
    dc_custom_cbs_t custom_cbs = {0};
    custom_cbs.set_timeout = bridge_set_timeout;
    custom_cbs.read = bridge_read;
    custom_cbs.write = bridge_write;
    custom_cbs.ioctl = bridge_ioctl;
    custom_cbs.close = bridge_close;
    custom_cbs.poll = bridge_poll;
    custom_cbs.purge = bridge_purge;
    custom_cbs.sleep = bridge_sleep;
    custom_cbs.configure = bridge_configure;
    custom_cbs.set_dtr = bridge_set_dtr;
    custom_cbs.set_rts = bridge_set_rts;

    // The io_callbacks struct is passed as userdata to the bridge functions.
    // We need a mutable copy since dc_custom_open takes a non-const pointer.
    libdc_io_callbacks_t io_cbs_copy = *io_callbacks;

    dc_iostream_t *iostream = NULL;
    dc_status_t status = dc_custom_open(&iostream, session->context,
                                         (dc_transport_t)actual_transport,
                                         &custom_cbs, &io_cbs_copy);
    if (status != DC_STATUS_SUCCESS) {
        set_error(&state, "Failed to create custom iostream");
        dc_descriptor_free(state.descriptor);
        return (int)status;
    }

    // 3. Open device.
    dc_device_t *device = NULL;
    status = dc_device_open(&device, session->context, state.descriptor,
                             iostream);
    if (status != DC_STATUS_SUCCESS) {
        set_error(&state, "Failed to open device");
        dc_iostream_close(iostream);
        dc_descriptor_free(state.descriptor);
        return (int)status;
    }
    state.device = device;

    // 4. Set cancel callback.
    dc_device_set_cancel(device, cancel_callback, &state);

    // 5. Set event callbacks (progress + device info).
    dc_device_set_events(device, DC_EVENT_PROGRESS | DC_EVENT_DEVINFO,
                         event_callback, &state);

    // 6. Set fingerprint for incremental downloads.
    if (fingerprint != NULL && fsize > 0) {
        dc_device_set_fingerprint(device, fingerprint, fsize);
    }

    // 7. Download dives.
    status = dc_device_foreach(device, dive_callback, &state);

    int result = 0;
    if (status != DC_STATUS_SUCCESS) {
        if (session->cancelled) {
            set_error(&state, "Download cancelled");
            result = LIBDC_STATUS_CANCELLED;
        } else if (session->last_error[0] != '\0') {
            // Surface the protocol-level cause libdivecomputer logged, not
            // just the generic failure (issue #766).
            char msg[224];
            snprintf(msg, sizeof(msg), "Download failed: %s",
                     session->last_error);
            set_error(&state, msg);
            result = (int)status;
        } else {
            set_error(&state, "Download failed");
            result = (int)status;
        }
    }

    // 8. Write device info output parameters.
    if (serial_out != NULL) {
        *serial_out = state.serial;
    }
    if (firmware_out != NULL) {
        *firmware_out = state.firmware;
    }

    // 9. Cleanup.
    dc_device_close(device);
    dc_iostream_close(iostream);
    dc_descriptor_free(state.descriptor);

    return result;
}

// ============================================================
// Standalone Raw Dive Parsing
// ============================================================

int libdc_parse_raw_dive(
    const char *vendor, const char *product, unsigned int model,
    const unsigned char *data, unsigned int size,
    libdc_parsed_dive_t *result,
    char *error_buf, size_t error_buf_size)
{
    if (vendor == NULL || product == NULL || data == NULL ||
        size == 0 || result == NULL) {
        if (error_buf && error_buf_size > 0) {
            strncpy(error_buf, "Invalid arguments", error_buf_size - 1);
            error_buf[error_buf_size - 1] = '\0';
        }
        return LIBDC_STATUS_INVALIDARGS;
    }

    memset(result, 0, sizeof(*result));
    result->min_temp = NAN;
    result->max_temp = NAN;
    result->entry_latitude = NAN;
    result->entry_longitude = NAN;
    result->exit_latitude = NAN;
    result->exit_longitude = NAN;
    result->events = NULL;
    result->event_count = 0;
    result->event_capacity = 0;

    dc_context_t *context = NULL;
    dc_status_t status = dc_context_new(&context);
    if (status != DC_STATUS_SUCCESS) {
        if (error_buf && error_buf_size > 0) {
            strncpy(error_buf, "Failed to create context", error_buf_size - 1);
            error_buf[error_buf_size - 1] = '\0';
        }
        return (int)status;
    }

    dc_descriptor_t *descriptor = find_descriptor(vendor, product, model);
    if (descriptor == NULL) {
        dc_context_free(context);
        if (error_buf && error_buf_size > 0)
            snprintf(error_buf, error_buf_size,
                     "No descriptor for %s %s (model %u)",
                     vendor, product, model);
        return LIBDC_STATUS_NODEVICE;
    }

    dc_parser_t *parser = NULL;
    status = dc_parser_new2(&parser, context, descriptor, data, size);
    if (status != DC_STATUS_SUCCESS || parser == NULL) {
        dc_descriptor_free(descriptor);
        dc_context_free(context);
        if (error_buf && error_buf_size > 0)
            snprintf(error_buf, error_buf_size,
                     "Parser creation failed (status %d)", (int)status);
        return (int)status;
    }

    int parse_result = extract_dive_fields(parser, result);

    dc_parser_destroy(parser);
    dc_descriptor_free(descriptor);
    dc_context_free(context);

    if (parse_result != 0 && error_buf && error_buf_size > 0) {
        strncpy(error_buf, "Field extraction failed", error_buf_size - 1);
        error_buf[error_buf_size - 1] = '\0';
    }

    return parse_result;
}
