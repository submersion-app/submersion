// Regression test for issue #280: the Heinrichs Weikamp OSTC nano (and the
// whole hw_ostc3 family) connected over BLE but failed to download dives with
// result=-7.
//
// Root cause: hw_ostc3_read() reads fixed blocks (e.g. the 4096-byte COMPACT
// logbook) in 1024-byte chunks and assumed each dc_iostream_read() returned the
// full requested size. That holds for serial (its inter-byte timeout stops a
// read at the gap between packets), but the BLE transport returns at most one
// GATT notification per read -- the packet-boundary behavior added in
// "fix(ble): preserve GATT notification boundaries" for the i330R/Shearwater
// parsers. The driver advanced its write offset by the requested length instead
// of the bytes actually read, so it consumed only one notification per 1024
// bytes, left the rest of the block uninitialized, and then mismatched the
// trailing ready byte -- failing the download.
//
// hw_ostc3_read is static, so this test #includes the translation unit to reach
// it. A mock custom iostream serves a scripted payload one 16-byte
// "notification" per read, reproducing the BLE transport. The fix makes
// hw_ostc3_read accumulate the bytes actually returned, filling the whole block
// across however many reads it takes.

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/context.h>
#include <libdivecomputer/custom.h>

#include "hw_ostc3.c"  // for the static hw_ostc3_read + hw_ostc3_device_t

// hw_ostc3.c replaced its HDR_FULL_* offset macros with a struct-based layout
// table (upstream frog/ostc3 integration). build_dive() below still constructs
// a "full" DIVE header, whose pointer field remains at byte offset 2 (see the
// full-header layout entry, pointers = 2). Define the offset locally now that
// the driver no longer exposes it as a macro.
#define HDR_FULL_POINTERS 2

#include "ostc_nano_dive_394.h"  // real OSTC nano DIVE capture from issue #394

// Stubs for the device-private symbols that the #included hw_ostc3.c
// references only from functions this test never calls (device open/close/
// foreach/firmware). Their real definitions live in device.c, which cannot be
// linked here: its dc_device_open switch-dispatches to ~40 driver
// *_device_open functions and would drag in the whole library. hw_ostc3_read
// (the function under test, called with progress == NULL) invokes none of
// these, so trivial stubs satisfy the linker without affecting the test.
int dc_device_isinstance(dc_device_t *device, const dc_device_vtable_t *vtable) {
  (void)device;
  (void)vtable;
  return 0;
}
dc_device_t *dc_device_allocate(dc_context_t *context,
                                const dc_device_vtable_t *vtable) {
  (void)context;
  (void)vtable;
  return NULL;
}
void dc_device_deallocate(dc_device_t *device) { (void)device; }
void device_event_emit(dc_device_t *device, dc_event_type_t event,
                       const void *data) {
  (void)device;
  (void)event;
  (void)data;
}
// Controllable so a retry test can exercise the cancellation path. Defaults to
// 0 (not cancelled) for every other test.
static int g_cancelled = 0;
int device_is_cancelled(dc_device_t *device) {
  (void)device;
  return g_cancelled;
}

// One GATT notification carries up to 16 bytes in this mock, matching the
// OSTC nano debug logs from the issue (mostly 16-byte notifications).
#define MOCK_CHUNK 16

typedef struct {
  const unsigned char *data;
  size_t size;
  size_t offset;
  int read_calls;
} mock_stream_t;

// Serves at most one notification (MOCK_CHUNK bytes) per read, regardless of
// how many bytes the caller requested -- exactly what the BLE transport does.
static dc_status_t mock_read(void *userdata, void *data, size_t size,
                             size_t *actual) {
  mock_stream_t *m = (mock_stream_t *)userdata;
  size_t remaining = m->size - m->offset;
  size_t n = size < MOCK_CHUNK ? size : MOCK_CHUNK;
  if (n > remaining) n = remaining;
  memcpy(data, m->data + m->offset, n);
  m->offset += n;
  m->read_calls++;
  if (actual) *actual = n;
  return DC_STATUS_SUCCESS;
}

static dc_status_t mock_close(void *userdata) {
  (void)userdata;
  return DC_STATUS_SUCCESS;
}

static int failures = 0;

// Reads `total` bytes through hw_ostc3_read against the chunked mock transport
// and verifies every byte was filled with the scripted payload.
static void check_fill(size_t total) {
  unsigned char *payload = (unsigned char *)malloc(total);
  for (size_t i = 0; i < total; i++) payload[i] = (unsigned char)(i & 0xFF);

  dc_context_t *ctx = NULL;
  assert(dc_context_new(&ctx) == DC_STATUS_SUCCESS);

  mock_stream_t mock = {payload, total, 0, 0};
  dc_custom_cbs_t cbs;
  memset(&cbs, 0, sizeof(cbs));
  cbs.read = mock_read;
  cbs.close = mock_close;

  dc_iostream_t *iostream = NULL;
  assert(dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, &mock) ==
         DC_STATUS_SUCCESS);

  hw_ostc3_device_t dev;
  memset(&dev, 0, sizeof(dev));
  dev.base.context = ctx;
  dev.iostream = iostream;

  unsigned char *out = (unsigned char *)malloc(total);
  memset(out, 0xEE, total);  // sentinel: unfilled bytes stay 0xEE

  dc_status_t rc = hw_ostc3_read(&dev, NULL, out, total);

  if (rc == DC_STATUS_SUCCESS && memcmp(out, payload, total) == 0) {
    printf("PASS: hw_ostc3_read fills %zu bytes across %d one-notification reads\n",
           total, mock.read_calls);
  } else {
    size_t bad = 0;
    while (bad < total && out[bad] == payload[bad]) bad++;
    printf("FAIL: hw_ostc3_read(%zu) rc=%d, first mismatch at byte %zu "
           "(got 0x%02x want 0x%02x) after %d reads\n",
           total, (int)rc, bad, bad < total ? out[bad] : 0,
           bad < total ? payload[bad] : 0, mock.read_calls);
    failures++;
  }

  dc_iostream_close(iostream);
  dc_context_free(ctx);
  free(payload);
  free(out);
}

// ---------------------------------------------------------------------------
// Issue #394: per-transfer retry (hw_ostc3_transfer_retry).
//
// On iOS/macOS the OSTC nano's BLE link intermittently drops a few bytes during
// the large logbook/profile transfers, so a read stalls short and the transfer
// times out. The device stays idle and responsive afterwards, so re-issuing the
// command recovers. These tests drive the real hw_ostc3_transfer through a mock
// that speaks the OSTC command/echo/data/ready protocol and can fail the first
// N attempts, verifying the wrapper recovers, resets progress, honors the
// attempt cap, and does NOT retry a non-transient (UNSUPPORTED) result.
// ---------------------------------------------------------------------------

enum { PH_ECHO = 0, PH_DATA = 1, PH_READY = 2, PH_DONE = 3 };

typedef struct {
  const unsigned char *payload;
  size_t size;
  int phase;        // PH_* state within the current attempt
  size_t offset;    // bytes of payload served this attempt
  unsigned char cmd;
  int attempt;      // command writes seen (== transfer attempts)
  int fail_attempts;     // the first N attempts stall (lose bytes)
  size_t fail_after;     // bytes served before the stall, on a failing attempt
  unsigned char echo_byte;  // byte returned for the echo (cmd, or a wrong byte)
  int purge_calls;
} proto_mock_t;

// Every write in the COMPACT flow is the 1-byte command (COMPACT has no input
// payload), so each write begins a fresh attempt.
static dc_status_t proto_write(void *userdata, const void *data, size_t size,
                               size_t *actual) {
  proto_mock_t *m = (proto_mock_t *)userdata;
  m->cmd = ((const unsigned char *)data)[0];
  m->phase = PH_ECHO;
  m->offset = 0;
  m->attempt++;
  if (actual) *actual = size;
  return DC_STATUS_SUCCESS;
}

static dc_status_t proto_read(void *userdata, void *data, size_t size,
                              size_t *actual) {
  proto_mock_t *m = (proto_mock_t *)userdata;
  unsigned char *out = (unsigned char *)data;
  switch (m->phase) {
    case PH_ECHO:
      out[0] = m->echo_byte ? m->echo_byte : m->cmd;
      if (actual) *actual = 1;
      m->phase = PH_DATA;
      return DC_STATUS_SUCCESS;
    case PH_DATA: {
      // Simulate lost bytes: a failing attempt stalls once it has served
      // fail_after bytes, exactly as a read does when the tail never arrives.
      if (m->attempt <= m->fail_attempts && m->offset >= m->fail_after) {
        if (actual) *actual = 0;
        return DC_STATUS_TIMEOUT;
      }
      size_t remaining = m->size - m->offset;
      size_t n = size < MOCK_CHUNK ? size : MOCK_CHUNK;
      if (n > remaining) n = remaining;
      memcpy(out, m->payload + m->offset, n);
      m->offset += n;
      if (actual) *actual = n;
      if (m->offset == m->size) m->phase = PH_READY;
      return DC_STATUS_SUCCESS;
    }
    case PH_READY:
      out[0] = READY;  // 0x4D, the ready byte for state == DOWNLOAD
      if (actual) *actual = 1;
      m->phase = PH_DONE;
      return DC_STATUS_SUCCESS;
    default:
      if (actual) *actual = 0;
      return DC_STATUS_TIMEOUT;
  }
}

static dc_status_t proto_purge(void *userdata, dc_direction_t direction) {
  proto_mock_t *m = (proto_mock_t *)userdata;
  (void)direction;
  m->purge_calls++;
  return DC_STATUS_SUCCESS;
}

static dc_status_t proto_sleep(void *userdata, unsigned int ms) {
  (void)userdata;
  (void)ms;  // no-op: keep the test fast
  return DC_STATUS_SUCCESS;
}

// Runs one COMPACT transfer through hw_ostc3_transfer_retry against a mock that
// fails `fail_attempts` times. Returns the transfer status and reports details
// via the out-params so each test can assert what it cares about.
static dc_status_t run_retry(size_t total, int fail_attempts,
                             unsigned char echo_byte,
                             unsigned int progress_start, int *attempts,
                             int *purges, unsigned int *progress_end,
                             int *data_ok) {
  unsigned char *payload = (unsigned char *)malloc(total);
  for (size_t i = 0; i < total; i++) payload[i] = (unsigned char)((i * 7) & 0xFF);

  dc_context_t *ctx = NULL;
  assert(dc_context_new(&ctx) == DC_STATUS_SUCCESS);

  proto_mock_t mock;
  memset(&mock, 0, sizeof(mock));
  mock.payload = payload;
  mock.size = total;
  mock.fail_attempts = fail_attempts;
  mock.fail_after = total / 2;  // stall halfway: clearly short
  mock.echo_byte = echo_byte;

  dc_custom_cbs_t cbs;
  memset(&cbs, 0, sizeof(cbs));
  cbs.read = proto_read;
  cbs.write = proto_write;
  cbs.purge = proto_purge;
  cbs.sleep = proto_sleep;
  cbs.close = mock_close;

  dc_iostream_t *iostream = NULL;
  assert(dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, &mock) ==
         DC_STATUS_SUCCESS);

  hw_ostc3_device_t dev;
  memset(&dev, 0, sizeof(dev));
  dev.base.context = ctx;
  dev.iostream = iostream;
  dev.state = DOWNLOAD;  // ready byte is READY (0x4D)

  dc_event_progress_t progress;
  memset(&progress, 0, sizeof(progress));
  progress.current = progress_start;
  progress.maximum = progress_start + (unsigned int)total;

  unsigned char *out = (unsigned char *)malloc(total);
  memset(out, 0xEE, total);

  dc_status_t rc = hw_ostc3_transfer_retry(&dev, &progress, COMPACT, NULL, 0,
                                           out, (unsigned int)total, NULL,
                                           NODELAY);

  if (attempts) *attempts = mock.attempt;
  if (purges) *purges = mock.purge_calls;
  if (progress_end) *progress_end = progress.current;
  if (data_ok) *data_ok = (rc == DC_STATUS_SUCCESS) &&
                          (memcmp(out, payload, total) == 0);

  dc_iostream_close(iostream);
  dc_context_free(ctx);
  free(payload);
  free(out);
  return rc;
}

static void expect(int cond, const char *label) {
  if (cond) {
    printf("PASS: %s\n", label);
  } else {
    printf("FAIL: %s\n", label);
    failures++;
  }
}

static void check_retry(void) {
  const size_t total = 4096;  // the COMPACT logbook size from the issue
  int attempts, purges, data_ok;
  unsigned int progress_end;
  dc_status_t rc;

  // Recovery: one failing attempt, then success on the retry.
  rc = run_retry(total, 1, 0, 1000, &attempts, &purges, &progress_end, &data_ok);
  expect(rc == DC_STATUS_SUCCESS, "retry recovers a transient transfer timeout");
  expect(data_ok, "recovered transfer fills the whole buffer correctly");
  expect(attempts == 2, "recovery takes exactly two attempts");
  expect(purges >= 1, "the link is purged before the retry");
  // Progress must count only the successful attempt, not the failed partial.
  expect(progress_end == 1000 + (unsigned int)total,
         "progress is reset between attempts (no double counting)");

  // Happy path: no failures, no retry, no purge.
  rc = run_retry(total, 0, 0, 0, &attempts, &purges, NULL, &data_ok);
  expect(rc == DC_STATUS_SUCCESS && data_ok && attempts == 1 && purges == 0,
         "a clean transfer succeeds on the first attempt with no purge");

  // Attempt cap: a persistently lossy link fails after the bounded attempts.
  rc = run_retry(total, 999, 0, 0, &attempts, &purges, NULL, NULL);
  expect(rc == DC_STATUS_TIMEOUT, "a persistent failure returns the error");
  expect(attempts == HW_OSTC3_DOWNLOAD_ATTEMPTS,
         "retries are capped at HW_OSTC3_DOWNLOAD_ATTEMPTS");

  // Non-transient result (UNSUPPORTED via a ready-byte echo) is not retried:
  // this preserves the COMPACT -> HEADER fallback for older firmware.
  rc = run_retry(total, 0, READY, 0, &attempts, &purges, NULL, NULL);
  expect(rc == DC_STATUS_UNSUPPORTED, "an unsupported command is reported");
  expect(attempts == 1, "an unsupported command is not retried");
}

// Opens a custom BLE iostream backed by `mock` driven by the proto_* callbacks,
// wired into a minimal DOWNLOAD-state device. The caller runs a transfer and
// closes via the returned context.
static dc_iostream_t *open_proto(dc_context_t **ctx_out, proto_mock_t *mock,
                                 hw_ostc3_device_t *dev) {
  assert(dc_context_new(ctx_out) == DC_STATUS_SUCCESS);
  dc_custom_cbs_t cbs;
  memset(&cbs, 0, sizeof(cbs));
  cbs.read = proto_read;
  cbs.write = proto_write;
  cbs.purge = proto_purge;
  cbs.sleep = proto_sleep;
  cbs.close = mock_close;
  dc_iostream_t *iostream = NULL;
  assert(dc_custom_open(&iostream, *ctx_out, DC_TRANSPORT_BLE, &cbs, mock) ==
         DC_STATUS_SUCCESS);
  memset(dev, 0, sizeof(*dev));
  dev->base.context = *ctx_out;
  dev->iostream = iostream;
  dev->state = DOWNLOAD;
  return iostream;
}

// Terminal (non-retried) outcomes: a cancellation and a deterministic error
// must both return immediately. Uses progress == NULL, which also covers the
// wrapper's no-progress branch.
static void check_retry_terminal(void) {
  unsigned char payload[64], out[300];

  // Cancellation: hw_ostc3_transfer sees the cancel flag and returns CANCELLED,
  // which the wrapper propagates without retrying.
  {
    proto_mock_t mock;
    memset(&mock, 0, sizeof(mock));
    mock.payload = payload;
    mock.size = sizeof(payload);
    dc_context_t *ctx = NULL;
    hw_ostc3_device_t dev;
    dc_iostream_t *io = open_proto(&ctx, &mock, &dev);
    g_cancelled = 1;
    dc_status_t rc = hw_ostc3_transfer_retry(&dev, NULL, COMPACT, NULL, 0, out,
                                             sizeof(payload), NULL, NODELAY);
    g_cancelled = 0;
    expect(rc == DC_STATUS_CANCELLED, "a cancelled transfer is not retried");
    dc_iostream_close(io);
    dc_context_free(ctx);
  }

  // Non-transient error: a DIVE transfer with osize < the full-header size is
  // rejected as INVALIDARGS, which the wrapper must return without retrying.
  {
    proto_mock_t mock;
    memset(&mock, 0, sizeof(mock));
    mock.payload = payload;
    mock.size = sizeof(payload);
    dc_context_t *ctx = NULL;
    hw_ostc3_device_t dev;
    dc_iostream_t *io = open_proto(&ctx, &mock, &dev);
    unsigned char number[1] = {0};
    dc_status_t rc = hw_ostc3_transfer_retry(&dev, NULL, DIVE, number, 1, out,
                                             100, NULL, NODELAY);
    expect(rc == DC_STATUS_INVALIDARGS,
           "a non-transient error is returned without retrying");
    dc_iostream_close(io);
    dc_context_free(ctx);
  }
}

// ---------------------------------------------------------------------------
// foreach call-site coverage: hw_ostc3_device_foreach must route its three
// download transfers (COMPACT, the HEADER fallback, and each DIVE) through the
// retry wrapper. This command-aware mock answers the COMPACT/HEADER handshake,
// can report COMPACT as unsupported, and times out the DIVE read -- enough to
// drive foreach through every call site without a full valid dive profile.
// ---------------------------------------------------------------------------

enum { FM_ECHO = 0, FM_DATA = 1, FM_READY = 2, FM_DONE = 3 };

typedef struct {
  const unsigned char *logbook;  // COMPACT/HEADER table to serve
  size_t logbook_size;
  int compact_unsupported;  // COMPACT echo returns READY -> DC_STATUS_UNSUPPORTED
  int read_phase;
  unsigned char cmd;
  size_t offset;
  int expect_input;  // next write is a DIVE number, not a new command
} foreach_mock_t;

static dc_status_t fm_write(void *userdata, const void *data, size_t size,
                            size_t *actual) {
  foreach_mock_t *m = (foreach_mock_t *)userdata;
  if (m->expect_input) {
    m->expect_input = 0;  // consume the DIVE number
  } else {
    m->cmd = ((const unsigned char *)data)[0];
    m->read_phase = FM_ECHO;
    m->offset = 0;
  }
  if (actual) *actual = size;
  return DC_STATUS_SUCCESS;
}

static dc_status_t fm_read(void *userdata, void *data, size_t size,
                           size_t *actual) {
  foreach_mock_t *m = (foreach_mock_t *)userdata;
  unsigned char *out = (unsigned char *)data;
  switch (m->read_phase) {
    case FM_ECHO:
      out[0] = (m->cmd == COMPACT && m->compact_unsupported) ? READY : m->cmd;
      if (actual) *actual = 1;
      if (m->cmd == DIVE) m->expect_input = 1;  // a number write follows
      m->read_phase = FM_DATA;
      return DC_STATUS_SUCCESS;
    case FM_DATA:
      if (m->cmd == DIVE) {
        if (actual) *actual = 0;  // stall the dive read; the call site is covered
        return DC_STATUS_TIMEOUT;
      }
      {
        size_t remaining = m->logbook_size - m->offset;
        size_t n = size < MOCK_CHUNK ? size : MOCK_CHUNK;
        if (n > remaining) n = remaining;
        memcpy(out, m->logbook + m->offset, n);
        m->offset += n;
        if (actual) *actual = n;
        if (m->offset == m->logbook_size) m->read_phase = FM_READY;
        return DC_STATUS_SUCCESS;
      }
    case FM_READY:
      out[0] = READY;
      if (actual) *actual = 1;
      m->read_phase = FM_DONE;
      return DC_STATUS_SUCCESS;
    default:
      if (actual) *actual = 0;
      return DC_STATUS_TIMEOUT;
  }
}

static dc_status_t fm_purge(void *userdata, dc_direction_t direction) {
  (void)userdata;
  (void)direction;
  return DC_STATUS_SUCCESS;
}

static int fm_dive_cb(const unsigned char *data, unsigned int size,
                      const unsigned char *fingerprint, unsigned int fsize,
                      void *userdata) {
  (void)data;
  (void)size;
  (void)fingerprint;
  (void)fsize;
  (void)userdata;
  return 1;
}

static dc_status_t run_foreach(const unsigned char *logbook, size_t logbook_size,
                               int compact_unsupported) {
  dc_context_t *ctx = NULL;
  assert(dc_context_new(&ctx) == DC_STATUS_SUCCESS);
  foreach_mock_t mock;
  memset(&mock, 0, sizeof(mock));
  mock.logbook = logbook;
  mock.logbook_size = logbook_size;
  mock.compact_unsupported = compact_unsupported;
  dc_custom_cbs_t cbs;
  memset(&cbs, 0, sizeof(cbs));
  cbs.read = fm_read;
  cbs.write = fm_write;
  cbs.purge = fm_purge;
  cbs.sleep = proto_sleep;
  cbs.close = mock_close;
  dc_iostream_t *iostream = NULL;
  assert(dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, &mock) ==
         DC_STATUS_SUCCESS);
  hw_ostc3_device_t dev;
  memset(&dev, 0, sizeof(dev));
  dev.base.context = ctx;
  dev.iostream = iostream;
  dev.state = DOWNLOAD;
  dc_status_t rc = hw_ostc3_device_foreach(&dev.base, fm_dive_cb, NULL);
  dc_iostream_close(iostream);
  dc_context_free(ctx);
  return rc;
}

static void check_foreach_call_sites(void) {
  // COMPACT succeeds with one dive header -> covers the COMPACT call site and
  // the DIVE call site. The dive read times out, so foreach reports an error.
  unsigned char *lb = (unsigned char *)malloc(4096);
  memset(lb, 0xFF, 4096);
  // length field -> profile length 269 (>= the 256-byte full header); a
  // non-zero summary so the entry does not match the all-zero fingerprint.
  unsigned char entry[16] = {0x10, 0x00, 0x00, 1, 2, 3, 4, 5,
                             6,    7,    8,    9, 10, 1, 0, 0x24};
  memcpy(lb, entry, sizeof(entry));
  dc_status_t rc1 = run_foreach(lb, 4096, 0);
  free(lb);
  expect(rc1 != DC_STATUS_SUCCESS,
         "foreach drives the COMPACT and DIVE retry call sites");

  // COMPACT unsupported -> HEADER fallback call site; an all-empty header
  // table yields no dives, so foreach completes successfully.
  size_t hb_size = 256 * 256;  // RB_LOGBOOK_SIZE_FULL * RB_LOGBOOK_COUNT
  unsigned char *hb = (unsigned char *)malloc(hb_size);
  memset(hb, 0xFF, hb_size);
  dc_status_t rc2 = run_foreach(hb, hb_size, 1);
  free(hb);
  expect(rc2 == DC_STATUS_SUCCESS,
         "foreach falls back to the HEADER retry call site when COMPACT is unsupported");
}

// ---------------------------------------------------------------------------
// Issue #394: a DIVE transfer whose firmware over-declares the profile length.
//
// Some OSTC nano (hwOS) firmware declares a profile a few bytes longer than the
// data it actually streams. It terminates the profile with the 0xFD 0xFD marker
// and the trailing ready byte, then idles. The old fixed-length profile read
// waited forever for the missing bytes and the whole download aborted (-7).
//
// This mock speaks the DIVE handshake (command, echo, dive-number input) and
// then serves a scripted dive response one notification at a time, going quiet
// once the payload is exhausted -- exactly what the device does after the end
// of the profile. The payload itself decides the scenario: it may carry the
// trailing ready byte (the device idles afterwards), omit it (lost), or stop
// before the end marker (a genuine mid-profile truncation).
// ---------------------------------------------------------------------------

typedef struct {
  const unsigned char *payload;  // dive header + profile (+ optional ready byte)
  size_t size;
  size_t offset;
  unsigned char cmd;
  int saw_echo;        // the echo was returned; the next write is the DIVE number
  int input_consumed;  // the DIVE number input write was consumed
} dive_mock_t;

static dc_status_t dive_write(void *userdata, const void *data, size_t size,
                              size_t *actual) {
  dive_mock_t *m = (dive_mock_t *)userdata;
  if (m->saw_echo && !m->input_consumed) {
    m->input_consumed = 1;  // the DIVE number that follows the command echo
  } else {
    m->cmd = ((const unsigned char *)data)[0];
    m->saw_echo = 0;
    m->input_consumed = 0;
    m->offset = 0;
  }
  if (actual) *actual = size;
  return DC_STATUS_SUCCESS;
}

static dc_status_t dive_read(void *userdata, void *data, size_t size,
                             size_t *actual) {
  dive_mock_t *m = (dive_mock_t *)userdata;
  unsigned char *out = (unsigned char *)data;
  if (!m->saw_echo) {
    out[0] = m->cmd;  // echo the command byte back
    m->saw_echo = 1;
    if (actual) *actual = 1;
    return DC_STATUS_SUCCESS;
  }
  // Data phase: serve the scripted dive response one notification at a time.
  size_t remaining = m->size - m->offset;
  if (remaining == 0) {
    if (actual) *actual = 0;  // payload exhausted: the device has gone idle
    return DC_STATUS_TIMEOUT;
  }
  size_t n = size < MOCK_CHUNK ? size : MOCK_CHUNK;
  if (n > remaining) n = remaining;
  memcpy(out, m->payload + m->offset, n);
  m->offset += n;
  if (actual) *actual = n;
  return DC_STATUS_SUCCESS;
}

// Runs one DIVE transfer (dive number 4) against a mock serving `payload`, with
// the caller-declared transfer length `osize`. Reports the status, the length
// hw_ostc3_transfer returns, and the downloaded bytes via out-params.
static dc_status_t run_dive(const unsigned char *payload, size_t size,
                            unsigned int osize, unsigned int *out_len,
                            unsigned char *dst, size_t dst_size) {
  dc_context_t *ctx = NULL;
  assert(dc_context_new(&ctx) == DC_STATUS_SUCCESS);

  dive_mock_t mock;
  memset(&mock, 0, sizeof(mock));
  mock.payload = payload;
  mock.size = size;

  dc_custom_cbs_t cbs;
  memset(&cbs, 0, sizeof(cbs));
  cbs.read = dive_read;
  cbs.write = dive_write;
  cbs.sleep = proto_sleep;
  cbs.close = mock_close;

  dc_iostream_t *iostream = NULL;
  assert(dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, &mock) ==
         DC_STATUS_SUCCESS);

  hw_ostc3_device_t dev;
  memset(&dev, 0, sizeof(dev));
  dev.base.context = ctx;
  dev.iostream = iostream;
  dev.state = DOWNLOAD;  // ready byte is READY (0x4D)

  unsigned char number[1] = {4};
  unsigned int length = 0;
  memset(dst, 0xEE, dst_size);
  dc_status_t rc = hw_ostc3_transfer(&dev, NULL, DIVE, number, sizeof(number),
                                     dst, osize, &length, NODELAY);
  if (out_len) *out_len = length;

  dc_iostream_close(iostream);
  dc_context_free(ctx);
  return rc;
}

// Builds a minimal DIVE response into `buf`: a 256-byte header (version 0x24,
// non-zero pointer fields so the empty-profile path is not taken) followed by
// `nsamples` sample bytes (kept < 0xFD so the only 0xFD 0xFD is the marker), an
// optional end-of-profile marker, and an optional trailing ready byte. Returns
// the number of bytes written.
static size_t build_dive(unsigned char *buf, size_t nsamples, int terminate,
                         int with_ready) {
  size_t total = 256 + nsamples + 3;
  memset(buf, 0x12, total);
  buf[0] = 0xFA;
  buf[1] = 0xFA;
  memset(buf + HDR_FULL_POINTERS, 0x11, 6);  // non-zero: not an empty profile
  buf[8] = 0x24;                             // ostc3 profile version
  buf[9] = 0x00;
  buf[10] = 0x10;
  buf[11] = 0x00;  // a length field other than 8
  size_t off = 256;
  for (size_t i = 0; i < nsamples; i++) buf[off++] = (unsigned char)(i & 0x7F);
  if (terminate) {
    buf[off++] = 0xFD;
    buf[off++] = 0xFD;
  }
  if (with_ready) buf[off++] = READY;
  return off;
}

static void check_dive_profile_terminated(void) {
  // Headline regression: the real OSTC nano (TechOS v3.37) capture from the
  // issue. The header declares 12383 bytes; the device streams a complete
  // 12365-byte FD FD-terminated dive plus the ready byte, then idles.
  {
    unsigned char *out = (unsigned char *)malloc(OSTC_NANO_394_DECLARED_LEN);
    unsigned int len = 0;
    dc_status_t rc = run_dive(ostc_nano_394_stream, OSTC_NANO_394_STREAM_SIZE,
                              OSTC_NANO_394_DECLARED_LEN, &len, out,
                              OSTC_NANO_394_DECLARED_LEN);
    expect(rc == DC_STATUS_SUCCESS,
           "issue #394: the over-declared OSTC nano dive downloads");
    expect(len == OSTC_NANO_394_DIVE_SIZE,
           "the dive length is what the device sent, not the declared length");
    expect(len >= 2 && out[len - 2] == 0xFD && out[len - 1] == 0xFD,
           "the downloaded dive ends exactly at the FD FD end-of-profile marker");
    expect(memcmp(out, ostc_nano_394_stream, OSTC_NANO_394_DIVE_SIZE) == 0,
           "every captured profile byte is delivered intact");
    free(out);
  }

  // Synthetic over-declared dive, ready byte present (the common case): the
  // read stops on the FD FD + ready-byte signature without waiting out a
  // timeout, and the ready byte is not read a second time.
  {
    unsigned char buf[256 + 100 + 4];
    size_t dive = build_dive(buf, 100, 1, 1);  // 256 + 100 + FD FD + ready
    unsigned char out[512];
    unsigned int len = 0;
    dc_status_t rc = run_dive(buf, dive, 380, &len, out, sizeof(out));
    expect(rc == DC_STATUS_SUCCESS,
           "an over-declared profile with a trailing ready byte succeeds");
    expect(len == 256 + 100 + 2,
           "the returned length stops at the end-of-profile marker");
    expect(out[len - 2] == 0xFD && out[len - 1] == 0xFD,
           "the synthetic dive ends at the FD FD marker (ready byte excluded)");
  }

  // Over-declared dive whose trailing ready byte was lost: the read goes quiet
  // after the FD FD marker, which is still accepted as a complete profile.
  {
    unsigned char buf[256 + 100 + 4];
    size_t dive = build_dive(buf, 100, 1, 0);  // 256 + 100 + FD FD, no ready
    unsigned char out[512];
    unsigned int len = 0;
    dc_status_t rc = run_dive(buf, dive, 380, &len, out, sizeof(out));
    expect(rc == DC_STATUS_SUCCESS,
           "an over-declared profile accepts the FD FD marker at silence");
    expect(len == 256 + 100 + 2, "the returned length still stops at the marker");
  }

  // Correctly-declared profile (the unchanged path): the data fills the whole
  // declared length and the ready byte is read separately afterwards.
  {
    unsigned char buf[256 + 100 + 4];
    size_t dive = build_dive(buf, 100, 1, 1);   // FD FD, then a separate ready
    unsigned int declared = 256 + 100 + 2;      // exactly the profile length
    unsigned char out[512];
    unsigned int len = 0;
    dc_status_t rc = run_dive(buf, dive, declared, &len, out, sizeof(out));
    expect(rc == DC_STATUS_SUCCESS,
           "a correctly-declared profile still downloads unchanged");
    expect(len == declared, "the returned length equals the declared length");
  }

  // Genuine mid-profile truncation (a notification lost before the end marker):
  // there is no FD FD tail, so the transfer still fails and the retry fires.
  {
    unsigned char buf[256 + 100 + 4];
    size_t dive = build_dive(buf, 100, 0, 0);  // no end marker at all
    unsigned char out[512];
    unsigned int len = 0;
    dc_status_t rc = run_dive(buf, dive, 380, &len, out, sizeof(out));
    expect(rc == DC_STATUS_TIMEOUT,
           "a profile truncated before the end marker still fails (and retries)");
  }

  // Documents a KNOWN LIMITATION (issue #394 review): a notification dropped
  // mid-profile while the final FD FD marker still arrives leaves a buffer that
  // ends in the marker but is missing interior bytes. read_profile cannot tell
  // this from a legitimate over-declare, so it accepts the short profile and the
  // dive is stored corrupt -- hw_ostc3_device_foreach does not catch it (its
  // checks compare the two declared length fields to each other, not to the
  // received count) and the hwOS profile has no CRC. Asserted here so the
  // behavior is explicit and the suite does not imply this case is rejected; the
  // retry narrows the window, only a less lossy link closes it.
  {
    unsigned char buf[256 + 100 + 4];
    size_t full = build_dive(buf, 100, 1, 1);  // header + 100 samples + FD FD + ready
    // Drop one whole mock notification (MOCK_CHUNK bytes), aligned to a
    // notification boundary inside the sample stream, while keeping the FD FD +
    // ready tail intact -- the device's BLE bridge losing a single notification.
    const size_t cut = 256 + 2 * MOCK_CHUNK;  // a notification boundary in the samples
    memmove(buf + cut, buf + cut + MOCK_CHUNK, full - (cut + MOCK_CHUNK));
    size_t lossy = full - MOCK_CHUNK;
    unsigned char out[512];
    unsigned int len = 0;
    dc_status_t rc = run_dive(buf, lossy, 380, &len, out, sizeof(out));
    expect(rc == DC_STATUS_SUCCESS,
           "lost-middle-with-FD-FD-tail is accepted as complete (known limitation)");
    expect(len == 256 + 100 + 2 - MOCK_CHUNK,
           "the corrupt short profile is accepted at its received length");
  }
}

int main(void) {
  check_fill(64);    // exact multiple of the 16-byte notification size
  check_fill(40);    // non-multiple: the final read is a partial (8 bytes)
  check_fill(4096);  // the real COMPACT logbook size from issue #280
  check_retry();     // issue #394: per-transfer retry recovers from byte loss
  check_retry_terminal();      // cancelled + non-transient: returned, not retried
  check_foreach_call_sites();  // foreach routes COMPACT/HEADER/DIVE through retry
  check_dive_profile_terminated();  // issue #394: device-terminated DIVE profile

  if (failures == 0) {
    printf("All hw_ostc3_read tests passed.\n");
    return 0;
  }
  printf("%d hw_ostc3_read test(s) FAILED.\n", failures);
  return 1;
}
