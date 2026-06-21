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
int device_is_cancelled(dc_device_t *device) {
  (void)device;
  return 0;
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

int main(void) {
  check_fill(64);    // exact multiple of the 16-byte notification size
  check_fill(40);    // non-multiple: the final read is a partial (8 bytes)
  check_fill(4096);  // the real COMPACT logbook size from issue #280

  if (failures == 0) {
    printf("All hw_ostc3_read tests passed.\n");
    return 0;
  }
  printf("%d hw_ostc3_read test(s) FAILED.\n", failures);
  return 1;
}
