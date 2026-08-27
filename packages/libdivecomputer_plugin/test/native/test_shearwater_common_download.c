// Regression test for issue #766: the Shearwater Petrel 3 / Nerd 2 answer the
// download init request (0x35) for certain manifest records with a NAK packet
// (0x7F 0x35 <code>) instead of an init response (0x75). On the wire that NAK
// is a 10-byte BLE notification -- the same length as a valid init response --
// and shearwater_common_download() treated it as a generic "Unexpected
// response packet" and returned DC_STATUS_PROTOCOL, which the petrel foreach
// loop escalated into aborting the whole download with zero dives.
//
// A NAK is a well-formed, deterministic refusal by the device, not line noise.
// shearwater_common_download() must decode it and return DC_STATUS_UNSUPPORTED
// (the same contract shearwater_common_rdbi/wdbi already follow), so callers
// can skip the refused record instead of aborting the pass. A genuinely
// malformed response must keep returning DC_STATUS_PROTOCOL.
//
// shearwater_common.c is #included so the test drives the real
// slip_read/slip_write framing over a mock BLE iostream that serves scripted
// notifications one per read (the BLE packet-boundary contract). The scripted
// frames use the V1 BLE encoding observed in the issue's debug logs: a 2-byte
// frame header, the FF 01 / 01 FF packet header, the payload, and the SLIP
// END terminator -- so the NAK frame here is byte-for-byte the 10-byte
// notification from the reporter's log.

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/context.h>
#include <libdivecomputer/custom.h>
#include <libdivecomputer/buffer.h>

#include "shearwater_common.c"  // for the static SLIP framing + V1/V2 macros

// Stubs for the device-private symbols the #included TU references. device.c
// cannot be linked (its dc_device_open switch-dispatches to every driver);
// neither the cancellation path nor progress events are under test here.
int device_is_cancelled(dc_device_t *device) {
  (void)device;
  return 0;
}
void device_event_emit(dc_device_t *device, dc_event_type_t event,
                       const void *data) {
  (void)device;
  (void)event;
  (void)data;
}

// ---------------------------------------------------------------------------
// Mock BLE iostream: serves scripted notifications ONE per read (the BLE
// packet-boundary contract) and records the size of every write so the tests
// can pin the on-wire request sizes against the issue's debug logs.
// ---------------------------------------------------------------------------

#define MAX_NOTIFICATIONS 8
#define MAX_WRITES 16

typedef struct {
  struct {
    unsigned char data[64];
    size_t size;
  } notifications[MAX_NOTIFICATIONS];
  int nnotifications;
  int next;
  size_t write_sizes[MAX_WRITES];
  int nwrites;
} mock_stream_t;

static mock_stream_t g_mock;

static void mock_reset(void) { memset(&g_mock, 0, sizeof(g_mock)); }

static void mock_add_notification(const unsigned char *data, size_t size) {
  assert(g_mock.nnotifications < MAX_NOTIFICATIONS);
  assert(size <= sizeof(g_mock.notifications[0].data));
  memcpy(g_mock.notifications[g_mock.nnotifications].data, data, size);
  g_mock.notifications[g_mock.nnotifications].size = size;
  g_mock.nnotifications++;
}

static dc_status_t mock_read(void *userdata, void *data, size_t size,
                             size_t *actual) {
  (void)userdata;
  if (g_mock.next >= g_mock.nnotifications)
    return DC_STATUS_TIMEOUT;  // nothing more scripted: a dead line
  size_t n = g_mock.notifications[g_mock.next].size;
  if (n > size) n = size;
  memcpy(data, g_mock.notifications[g_mock.next].data, n);
  g_mock.next++;
  if (actual) *actual = n;
  return DC_STATUS_SUCCESS;
}

static dc_status_t mock_write(void *userdata, const void *data, size_t size,
                              size_t *actual) {
  (void)userdata;
  (void)data;
  if (g_mock.nwrites < MAX_WRITES) g_mock.write_sizes[g_mock.nwrites] = size;
  g_mock.nwrites++;
  if (actual) *actual = size;
  return DC_STATUS_SUCCESS;
}

static dc_status_t mock_close(void *userdata) {
  (void)userdata;
  return DC_STATUS_SUCCESS;
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

static int failures = 0;

static void expect(int cond, const char *label) {
  if (cond) {
    printf("PASS: %s\n", label);
  } else {
    printf("FAIL: %s\n", label);
    failures++;
  }
}

// Runs shearwater_common_download(address=0x80001000, size, compression=0)
// against the scripted notifications and returns the status. The downloaded
// bytes land in *buffer when the caller passes one.
static dc_status_t run_download(unsigned int size, dc_buffer_t *buffer) {
  dc_context_t *ctx = NULL;
  assert(dc_context_new(&ctx) == DC_STATUS_SUCCESS);

  dc_custom_cbs_t cbs;
  memset(&cbs, 0, sizeof(cbs));
  cbs.read = mock_read;
  cbs.write = mock_write;
  cbs.close = mock_close;

  dc_iostream_t *iostream = NULL;
  assert(dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, NULL) ==
         DC_STATUS_SUCCESS);

  shearwater_common_device_t dev;
  memset(&dev, 0, sizeof(dev));
  dev.base.context = ctx;
  dev.iostream = iostream;
  dev.protocol = V1;  // Petrel 3 / Nerd 2 speak the V1 protocol

  dc_status_t rc = shearwater_common_download(&dev, buffer, 0x80001000, size,
                                              0, NULL);

  dc_iostream_close(iostream);
  dc_context_free(ctx);
  return rc;
}

// The device refuses the init request: 0x7F 0x35 <code>, framed as the exact
// 10-byte notification from the issue #766 logs. The refusal must surface as
// DC_STATUS_UNSUPPORTED so the caller can skip the record, and the driver
// must stop after the single init write (no block requests, no retry).
static void test_nak_init_returns_unsupported(void) {
  mock_reset();
  const unsigned char nak[] = {0x01, 0x00,              // BLE frame header
                               0x01, 0xFF, 0x04, 0x00,  // packet header
                               0x7F, 0x35, 0x13,        // NAK, init, code
                               0xC0};                   // SLIP END
  mock_add_notification(nak, sizeof(nak));

  dc_buffer_t *buffer = dc_buffer_new(16);
  dc_status_t rc = run_download(4, buffer);
  expect(rc == DC_STATUS_UNSUPPORTED,
         "a NAK'd init returns DC_STATUS_UNSUPPORTED (#766)");
  if (rc != DC_STATUS_UNSUPPORTED) printf("  rc=%d\n", (int)rc);
  expect(g_mock.nwrites == 1 && g_mock.write_sizes[0] == 17,
         "the refusal stops the transfer after the single 17-byte init");
  if (g_mock.nwrites != 1)
    printf("  %d writes\n", g_mock.nwrites);
  dc_buffer_free(buffer);
}

// A complete tiny transfer: init response (block size 0x80), one 4-byte data
// block, and the exit response. Pins the happy path around the NAK decode,
// and pins the request sizes (17-byte init, 9-byte block request, 8-byte
// exit) that identified the protocol phases in the issue's debug logs.
static void test_successful_download_unchanged(void) {
  mock_reset();
  const unsigned char init_ack[] = {0x01, 0x00, 0x01, 0xFF, 0x04, 0x00,
                                    0x75, 0x10, 0x80, 0xC0};
  const unsigned char block[] = {0x01, 0x00, 0x01, 0xFF, 0x07, 0x00,
                                 0x76, 0x01, 0xDE, 0xAD, 0xBE, 0xEF, 0xC0};
  const unsigned char exit_ack[] = {0x01, 0x00, 0x01, 0xFF, 0x03, 0x00,
                                    0x77, 0x00, 0xC0};
  mock_add_notification(init_ack, sizeof(init_ack));
  mock_add_notification(block, sizeof(block));
  mock_add_notification(exit_ack, sizeof(exit_ack));

  dc_buffer_t *buffer = dc_buffer_new(16);
  dc_status_t rc = run_download(4, buffer);
  const unsigned char want[] = {0xDE, 0xAD, 0xBE, 0xEF};
  expect(rc == DC_STATUS_SUCCESS, "a normal download still succeeds");
  if (rc != DC_STATUS_SUCCESS) printf("  rc=%d\n", (int)rc);
  expect(dc_buffer_get_size(buffer) == 4 &&
             memcmp(dc_buffer_get_data(buffer), want, 4) == 0,
         "the downloaded bytes round-trip through the SLIP framing");
  expect(g_mock.nwrites == 3 && g_mock.write_sizes[0] == 17 &&
             g_mock.write_sizes[1] == 9 && g_mock.write_sizes[2] == 8,
         "request sizes stay 17 (init), 9 (block), 8 (exit)");
  if (g_mock.nwrites != 3)
    printf("  %d writes\n", g_mock.nwrites);
  dc_buffer_free(buffer);
}

// A malformed init response (unknown opcode) is line garbage, not a device
// refusal: it must keep returning DC_STATUS_PROTOCOL.
static void test_malformed_init_stays_protocol(void) {
  mock_reset();
  const unsigned char garbage[] = {0x01, 0x00, 0x01, 0xFF, 0x04, 0x00,
                                   0x99, 0x01, 0x02, 0xC0};
  mock_add_notification(garbage, sizeof(garbage));

  dc_buffer_t *buffer = dc_buffer_new(16);
  dc_status_t rc = run_download(4, buffer);
  expect(rc == DC_STATUS_PROTOCOL,
         "a malformed init response still returns DC_STATUS_PROTOCOL");
  if (rc != DC_STATUS_PROTOCOL) printf("  rc=%d\n", (int)rc);
  dc_buffer_free(buffer);
}

int main(void) {
  test_nak_init_returns_unsupported();
  test_successful_download_unchanged();
  test_malformed_init_stays_protocol();

  if (failures == 0) {
    printf("All shearwater_common_download tests passed.\n");
    return 0;
  }
  printf("%d shearwater_common_download test(s) FAILED.\n", failures);
  return 1;
}
