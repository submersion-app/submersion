// Download session implementation for libdivecomputer.
// Handles the full lifecycle: context -> descriptor -> iostream -> device -> parse.

#include "libdc_wrapper.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

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
};

// Data passed through the download pipeline callbacks.
typedef struct {
    libdc_download_session_t *session;
    const libdc_download_callbacks_t *callbacks;
    dc_descriptor_t *descriptor;
    dc_device_t *device;
    int dive_count;
    char *error_buf;
    size_t error_buf_size;
} download_state_t;

// Data collected during sample iteration.
typedef struct {
    libdc_parsed_dive_t *dive;
    int has_pending_sample;
    libdc_sample_t current_sample;
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
            strcmp(v, vendor) == 0 && strcmp(p, product) == 0 && m == model) {
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
        state->current_sample.depth = 0.0;
        state->current_sample.temperature = NAN;
        state->current_sample.pressure = NAN;
        state->current_sample.tank = UINT32_MAX;
        break;
    case DC_SAMPLE_DEPTH:
        state->current_sample.depth = value->depth;
        break;
    case DC_SAMPLE_TEMPERATURE:
        state->current_sample.temperature = value->temperature;
        break;
    case DC_SAMPLE_PRESSURE:
        state->current_sample.pressure = value->pressure.value;
        state->current_sample.tank = value->pressure.tank;
        break;
    default:
        break;
    }
}

static int parse_dive(download_state_t *state,
                       const unsigned char *data, unsigned int size,
                       const unsigned char *fingerprint, unsigned int fsize,
                       libdc_parsed_dive_t *dive) {
    memset(dive, 0, sizeof(*dive));
    dive->min_temp = NAN;
    dive->max_temp = NAN;

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

    // Extract gas mixes.
    unsigned int gasmix_count = 0;
    if (dc_parser_get_field(parser, DC_FIELD_GASMIX_COUNT, 0, &gasmix_count) == DC_STATUS_SUCCESS) {
        if (gasmix_count > LIBDC_MAX_GASMIXES) {
            gasmix_count = LIBDC_MAX_GASMIXES;
        }
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
        if (tank_count > LIBDC_MAX_TANKS) {
            tank_count = LIBDC_MAX_TANKS;
        }
        for (unsigned int i = 0; i < tank_count; i++) {
            dc_tank_t tk = {0};
            if (dc_parser_get_field(parser, DC_FIELD_TANK, i, &tk) == DC_STATUS_SUCCESS) {
                dive->tanks[i].gasmix = tk.gasmix;
                dive->tanks[i].volume = tk.volume;
                dive->tanks[i].workpressure = tk.workpressure;
                dive->tanks[i].beginpressure = tk.beginpressure;
                dive->tanks[i].endpressure = tk.endpressure;
            }
        }
        dive->tank_count = tank_count;
    }

    // Extract profile samples.
    sample_state_t sample_state = {0};
    sample_state.dive = dive;
    dc_parser_samples_foreach(parser, sample_callback, &sample_state);
    push_sample(&sample_state);

    dc_parser_destroy(parser);
    return 0;
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
        if (state->callbacks->on_dive != NULL) {
            state->callbacks->on_dive(&dive, state->callbacks->userdata);
        }
        state->dive_count++;
    }

    // Free dynamically allocated samples.
    free(dive.samples);

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
        struct timespec ts;
        ts.tv_sec = milliseconds / 1000;
        ts.tv_nsec = (milliseconds % 1000) * 1000000L;
        nanosleep(&ts, NULL);
        return DC_STATUS_SUCCESS;
    }
    return (dc_status_t)cbs->sleep(cbs->userdata, milliseconds);
}

// ============================================================
// Download Session
// ============================================================

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

    // 1. Find matching descriptor.
    state.descriptor = find_descriptor(vendor, product, model);
    if (state.descriptor == NULL) {
        set_error(&state, "No matching device descriptor found");
        return LIBDC_STATUS_NODEVICE;
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

    // The io_callbacks struct is passed as userdata to the bridge functions.
    // We need a mutable copy since dc_custom_open takes a non-const pointer.
    libdc_io_callbacks_t io_cbs_copy = *io_callbacks;

    dc_iostream_t *iostream = NULL;
    dc_status_t status = dc_custom_open(&iostream, session->context,
                                         (dc_transport_t)transport,
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

    // 5. Set progress event callback.
    dc_device_set_events(device, DC_EVENT_PROGRESS, event_callback, &state);

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
        } else {
            set_error(&state, "Download failed");
            result = (int)status;
        }
    }

    // 8. Cleanup.
    dc_device_close(device);
    dc_iostream_close(iostream);
    dc_descriptor_free(state.descriptor);

    return result;
}
