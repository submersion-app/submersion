// Thin C wrapper around libdivecomputer functions.
// Keeps libdivecomputer headers as an implementation detail, not part
// of the plugin framework's public interface.

#ifndef LIBDC_WRAPPER_H
#define LIBDC_WRAPPER_H

#include <stdint.h>
#include <stddef.h>

// Get the libdivecomputer version string.
// Returns a statically allocated string (do not free).
const char *libdc_get_version(void);

// Transport type bitmask values matching dc_transport_t.
#define LIBDC_TRANSPORT_SERIAL    (1 << 0)
#define LIBDC_TRANSPORT_USB       (1 << 1)
#define LIBDC_TRANSPORT_USBHID    (1 << 2)
#define LIBDC_TRANSPORT_IRDA      (1 << 3)
#define LIBDC_TRANSPORT_BLUETOOTH (1 << 4)
#define LIBDC_TRANSPORT_BLE       (1 << 5)

// Status codes (mirror dc_status_t).
#define LIBDC_STATUS_SUCCESS     0
#define LIBDC_STATUS_DONE        1
#define LIBDC_STATUS_UNSUPPORTED (-1)
#define LIBDC_STATUS_INVALIDARGS (-2)
#define LIBDC_STATUS_NOMEMORY    (-3)
#define LIBDC_STATUS_NODEVICE    (-4)
#define LIBDC_STATUS_NOACCESS    (-5)
#define LIBDC_STATUS_IO          (-6)
#define LIBDC_STATUS_TIMEOUT     (-7)
#define LIBDC_STATUS_PROTOCOL    (-8)
#define LIBDC_STATUS_DATAFORMAT  (-9)
#define LIBDC_STATUS_CANCELLED   (-10)

// ============================================================
// Descriptor Iterator
// ============================================================

// Descriptor info returned by the iterator.
typedef struct {
    const char *vendor;
    const char *product;
    unsigned int model;
    unsigned int transports;  // bitmask of LIBDC_TRANSPORT_* values
} libdc_descriptor_info_t;

// Opaque iterator handle.
typedef struct libdc_descriptor_iterator libdc_descriptor_iterator_t;

// Create a descriptor iterator. Returns NULL on failure.
libdc_descriptor_iterator_t *libdc_descriptor_iterator_new(void);

// Get the next descriptor. Returns 0 on success, 1 when done, -1 on error.
int libdc_descriptor_iterator_next(libdc_descriptor_iterator_t *iter,
                                   libdc_descriptor_info_t *info);

// Free the iterator.
void libdc_descriptor_iterator_free(libdc_descriptor_iterator_t *iter);

// ============================================================
// BLE Discovery Helper
// ============================================================

// Check if a device name matches any descriptor for the given transport.
// Returns 1 if match found (fills info), 0 if no match.
// The vendor/product strings in info point to static data (valid for program lifetime).
int libdc_descriptor_match(const char *name, unsigned int transport,
                           libdc_descriptor_info_t *info);

// Lookup a descriptor by exact model + transport.
// Returns 1 if found (fills info), 0 otherwise.
int libdc_descriptor_lookup_model(unsigned int transport, unsigned int model,
                                  libdc_descriptor_info_t *info);

// ============================================================
// Custom I/O Callbacks (for BLE bridge)
// ============================================================

// Callback function types matching dc_custom_cbs_t return values.
// Return 0 (LIBDC_STATUS_SUCCESS) on success, negative on error.
typedef int (*libdc_io_set_timeout_fn)(void *userdata, int timeout);
typedef int (*libdc_io_read_fn)(void *userdata, void *data, size_t size,
                                size_t *actual);
typedef int (*libdc_io_write_fn)(void *userdata, const void *data, size_t size,
                                 size_t *actual);
typedef int (*libdc_io_ioctl_fn)(void *userdata, unsigned int request,
                                 void *data, size_t size);
typedef int (*libdc_io_close_fn)(void *userdata);
typedef int (*libdc_io_poll_fn)(void *userdata, int timeout);
typedef int (*libdc_io_purge_fn)(void *userdata, unsigned int direction);
typedef int (*libdc_io_sleep_fn)(void *userdata, unsigned int milliseconds);
typedef int (*libdc_io_configure_fn)(void *userdata, unsigned int baudrate,
                                     unsigned int databits, unsigned int parity,
                                     unsigned int stopbits, unsigned int flowcontrol);
typedef int (*libdc_io_set_dtr_fn)(void *userdata, unsigned int value);
typedef int (*libdc_io_set_rts_fn)(void *userdata, unsigned int value);

typedef struct {
    libdc_io_set_timeout_fn set_timeout;  // may be NULL
    libdc_io_read_fn read;                // required
    libdc_io_write_fn write;              // required
    libdc_io_ioctl_fn ioctl;              // may be NULL
    libdc_io_close_fn close;              // required
    libdc_io_poll_fn poll;                // may be NULL
    libdc_io_purge_fn purge;              // may be NULL
    libdc_io_sleep_fn sleep;              // may be NULL
    libdc_io_configure_fn configure;      // may be NULL (serial port config)
    libdc_io_set_dtr_fn set_dtr;          // may be NULL (serial DTR line)
    libdc_io_set_rts_fn set_rts;          // may be NULL (serial RTS line)
    void *userdata;
} libdc_io_callbacks_t;

// ============================================================
// Parsed Dive Data
// ============================================================

#define LIBDC_MAX_FINGERPRINT 64
#define LIBDC_MAX_GASMIXES    16
#define LIBDC_MAX_TANKS       16

typedef struct {
    unsigned int time_ms;      // milliseconds since dive start
    double depth;              // meters
    double temperature;        // celsius (NAN if unavailable)
    double pressure;           // bar (NAN if unavailable)
    unsigned int tank;         // tank index (UINT32_MAX if unavailable)
    // New fields for full sample capture
    unsigned int heartbeat;    // bpm (UINT32_MAX if unavailable)
    double setpoint;           // bar (NAN if unavailable)
    double ppo2;               // bar (NAN if unavailable, first sensor)
    double cns;                // percentage 0-100 (NAN if unavailable)
    unsigned int rbt;          // remaining bottom time in seconds (UINT32_MAX if unavailable)
    // Decompression status at this sample
    unsigned int deco_type;    // 0=NDL, 1=safetystop, 2=decostop, 3=deepstop (UINT32_MAX if unavailable)
    unsigned int deco_time;    // seconds (NDL seconds or stop time remaining)
    double deco_depth;         // stop depth in meters (NAN if unavailable)
    unsigned int deco_tts;     // Time To Surface in seconds (UINT32_MAX if unavailable)
} libdc_sample_t;

typedef struct {
    double oxygen;             // fraction 0.0-1.0
    double helium;             // fraction 0.0-1.0
} libdc_gasmix_t;

typedef struct {
    unsigned int gasmix;       // gasmix index
    double volume;             // liters
    double workpressure;       // bar
    double beginpressure;      // bar
    double endpressure;        // bar
} libdc_tank_t;

#define LIBDC_MAX_EVENTS 256

typedef struct {
    unsigned int time_ms;      // milliseconds since dive start
    unsigned int type;         // parser_sample_event_t enum value
    unsigned int flags;        // event-specific flags
    unsigned int value;        // event-specific value
} libdc_event_t;

typedef struct {
    // DateTime
    int year, month, day, hour, minute, second, timezone;

    // Summary fields
    double max_depth;          // meters
    double avg_depth;          // meters
    unsigned int duration;     // seconds
    double min_temp;           // celsius (NAN if unavailable)
    double max_temp;           // celsius (NAN if unavailable)
    unsigned int dive_mode;    // 0=freedive, 1=gauge, 2=OC, 3=CCR, 4=SCR

    // Fingerprint
    unsigned char fingerprint[LIBDC_MAX_FINGERPRINT];
    unsigned int fingerprint_size;

    // Profile samples (dynamically allocated)
    libdc_sample_t *samples;
    unsigned int sample_count;
    unsigned int sample_capacity;

    // Gas mixes (fixed-size arrays)
    libdc_gasmix_t gasmixes[LIBDC_MAX_GASMIXES];
    unsigned int gasmix_count;

    // Tanks (fixed-size arrays)
    libdc_tank_t tanks[LIBDC_MAX_TANKS];
    unsigned int tank_count;

    // Decompression model from dive computer
    unsigned int deco_model_type;  // 0=none, 1=buhlmann, 2=vpm, 3=rgbm, 4=dciem
    int deco_conservatism;         // personal adjustment (0 = neutral)
    unsigned int gf_low;           // gradient factor low 0-100 (0 if unknown)
    unsigned int gf_high;          // gradient factor high 0-100 (0 if unknown)

    // Events (dynamically allocated)
    libdc_event_t *events;
    unsigned int event_count;
    unsigned int event_capacity;
} libdc_parsed_dive_t;

// Free a parsed dive (frees the samples array).
void libdc_parsed_dive_free(libdc_parsed_dive_t *dive);

// ============================================================
// Download Session
// ============================================================

typedef struct libdc_download_session libdc_download_session_t;

// Download event callbacks.
typedef void (*libdc_on_progress_fn)(unsigned int current, unsigned int maximum,
                                     void *userdata);
typedef void (*libdc_on_dive_fn)(const libdc_parsed_dive_t *dive, void *userdata);

typedef struct {
    libdc_on_progress_fn on_progress;  // may be NULL
    libdc_on_dive_fn on_dive;          // required
    void *userdata;
} libdc_download_callbacks_t;

// Create a download session. Returns NULL on failure.
libdc_download_session_t *libdc_download_session_new(void);

// Run the download. Blocks until complete or cancelled.
// Returns 0 on success, non-zero on error.
// serial_out/firmware_out receive device info from DC_EVENT_DEVINFO (may be NULL).
// error_buf receives a human-readable error message (optional, may be NULL).
int libdc_download_run(
    libdc_download_session_t *session,
    const char *vendor, const char *product, unsigned int model,
    unsigned int transport,
    const libdc_io_callbacks_t *io_callbacks,
    const unsigned char *fingerprint, unsigned int fsize,
    const libdc_download_callbacks_t *callbacks,
    unsigned int *serial_out,
    unsigned int *firmware_out,
    char *error_buf, size_t error_buf_size);

// Cancel a running download (thread-safe).
void libdc_download_cancel(libdc_download_session_t *session);

// Free the session.
void libdc_download_session_free(libdc_download_session_t *session);

// ============================================================
// Standalone Raw Dive Parsing
// ============================================================

/// Parse raw dive computer binary data without a device connection.
/// Uses dc_parser_new2() with a descriptor looked up by vendor/product/model.
/// Returns 0 on success, negative on failure.
/// The caller must free result->samples and result->events when done.
int libdc_parse_raw_dive(
    const char *vendor, const char *product, unsigned int model,
    const unsigned char *data, unsigned int size,
    libdc_parsed_dive_t *result,
    char *error_buf, size_t error_buf_size);

#endif
