// Regression test for issue #480: large Shearwater logbook downloads over BLE
// time out and cannot resume, and dives behind deleted records are never
// imported.
//
// Root causes, all in shearwater_petrel_device_foreach:
//
// 1. The profile-download loop walked the manifest front to back, i.e. newest
//    dive first. Submersion persists the newest imported dive's fingerprint as
//    the resume point, so after a partial (timed out or cancelled) run the
//    next attempt's manifest stop-check matched at the newest dive and every
//    older dive was stranded forever. Delivering the dives oldest first makes
//    a partial run leave a contiguous oldest prefix, so the newest imported
//    fingerprint is a correct high-water mark and resume works.
// 2. The manifest phase appended only count * RECORD_SIZE bytes per page, but
//    the record walk advances past deleted (0x5A23) records without counting
//    them into count. A deleted dive interspersed among not-yet-downloaded
//    dives pushed the trailing valid record(s) past the appended prefix; those
//    dives were silently never downloaded.
// 3. Deleted records were counted into the progress maximum but never credited
//    to current, so progress never reached 100% on devices with deleted dives.
//
// shearwater_petrel_device_foreach is static, so this test #includes the
// translation unit. The shearwater_common_* transport layer is mocked here
// (shearwater_common.c is not linked): the mock serves scripted manifest pages
// and dive payloads by address, and can fail a specific dive to simulate the
// BLE timeouts from the issue.

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/context.h>

#include "shearwater_petrel.c"  // for the static foreach + device struct

// ---------------------------------------------------------------------------
// Stubs for the device.c symbols the #included TU references. device.c cannot
// be linked (its dc_device_open switch-dispatches to every driver). The
// progress stub records the most recent DC_EVENT_PROGRESS so the tests can
// assert the final accounting.
// ---------------------------------------------------------------------------

static dc_event_progress_t g_last_progress;

int dc_device_isinstance(dc_device_t *device, const dc_device_vtable_t *vtable) {
  (void)device;
  (void)vtable;
  return 1;
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
  if (event == DC_EVENT_PROGRESS)
    g_last_progress = *(const dc_event_progress_t *)data;
}

// ---------------------------------------------------------------------------
// Scripted mock of the shearwater_common transport layer.
//
// A manifest record is 32 bytes: header (0xA5C4 valid / 0x5A23 deleted) at
// offset 0, the 4-byte fingerprint at offset 4, and the dive's storage address
// at offset 20. Dives are identified by a one-byte id: the fingerprint is
// {0xF0, 0, 0, id}, the storage address is id * 0x1000, and the served payload
// carries the id at byte 0 and the fingerprint at bytes 12..15 (the foreach
// callback contract points the fingerprint at buf + 12).
// ---------------------------------------------------------------------------

#define BASE_ADDR 0x80000000  // Petrel Native Format, reported via ID_LOGUPLOAD
#define MAX_PAGES 3
#define MAX_DIVES 64
#define DIVE_PAYLOAD_SIZE 32

typedef struct {
  unsigned char pages[MAX_PAGES][MANIFEST_SIZE];
  int npages;
  int next_page;
  struct {
    unsigned char id;
    int fail;  // serve DC_STATUS_TIMEOUT instead of the payload
  } dives[MAX_DIVES];
  int ndives;
} script_t;

static script_t g_script;

static void script_reset(void) {
  memset(&g_script, 0, sizeof(g_script));
  // 0xFF-fill the pages: an 0xFFFF header is neither valid nor deleted, so an
  // untouched slot terminates the manifest walk, like a real device's blank
  // flash.
  memset(g_script.pages, 0xFF, sizeof(g_script.pages));
  memset(&g_last_progress, 0, sizeof(g_last_progress));
}

static void script_add_dive(unsigned char id, int fail) {
  assert(g_script.ndives < MAX_DIVES);  // fail fast on script overflow
  g_script.dives[g_script.ndives].id = id;
  g_script.dives[g_script.ndives].fail = fail;
  g_script.ndives++;
}

// Writes one manifest record. deleted records get the 0x5A23 header and no
// payload fields, matching what the device leaves behind after a delete.
static void set_record(int page, int slot, int deleted, unsigned char id) {
  assert(page >= 0 && page < MAX_PAGES);
  assert(slot >= 0 && slot < (int)RECORD_COUNT);
  unsigned char *r = g_script.pages[page] + slot * RECORD_SIZE;
  memset(r, 0, RECORD_SIZE);
  if (deleted) {
    r[0] = 0x5A;
    r[1] = 0x23;
    return;
  }
  r[0] = 0xA5;
  r[1] = 0xC4;
  r[4] = 0xF0;
  r[7] = id;  // fingerprint {0xF0, 0, 0, id}
  unsigned int address = (unsigned int)id * 0x1000;
  r[20] = (address >> 24) & 0xFF;
  r[21] = (address >> 16) & 0xFF;
  r[22] = (address >> 8) & 0xFF;
  r[23] = address & 0xFF;
}

dc_status_t shearwater_common_setup(shearwater_common_device_t *device,
                                    dc_context_t *context,
                                    dc_iostream_t *iostream) {
  (void)device;
  (void)context;
  (void)iostream;
  return DC_STATUS_SUCCESS;
}

dc_status_t shearwater_common_transfer(shearwater_common_device_t *device,
                                       const unsigned char input[],
                                       unsigned int isize,
                                       unsigned char output[],
                                       unsigned int osize,
                                       unsigned int *actual) {
  (void)device;
  (void)input;
  (void)isize;
  (void)output;
  (void)osize;
  if (actual) *actual = 0;
  return DC_STATUS_SUCCESS;
}

dc_status_t shearwater_common_rdbi(shearwater_common_device_t *device,
                                   unsigned int id, unsigned char data[],
                                   unsigned int size, unsigned int *actual) {
  (void)device;
  memset(data, 0, size);
  switch (id) {
    case ID_SERIAL:
      memcpy(data, "0000ABCD", 8);  // hex string, converted by the driver
      break;
    case ID_FIRMWARE:
      memcpy(data, "V37", 3);
      if (actual) *actual = 3;
      return DC_STATUS_SUCCESS;
    case ID_MODEL:
      data[0] = TERIC;
      break;
    case ID_LOGUPLOAD:
      data[1] = (BASE_ADDR >> 24) & 0xFF;  // base address at bytes 1..4
      break;
    default:
      break;
  }
  if (actual) *actual = size;
  return DC_STATUS_SUCCESS;
}

dc_status_t shearwater_common_timesync_local(shearwater_common_device_t *device,
                                             const dc_datetime_t *datetime) {
  (void)device;
  (void)datetime;
  return DC_STATUS_SUCCESS;
}

dc_status_t shearwater_common_timesync_utc(shearwater_common_device_t *device,
                                           const dc_datetime_t *datetime) {
  (void)device;
  (void)datetime;
  return DC_STATUS_SUCCESS;
}

dc_status_t shearwater_common_download(shearwater_common_device_t *device,
                                       dc_buffer_t *buffer,
                                       unsigned int address, unsigned int size,
                                       unsigned int compression,
                                       dc_event_progress_t *progress) {
  (void)device;
  (void)size;
  (void)compression;
  (void)progress;
  dc_buffer_clear(buffer);

  if (address == MANIFEST_ADDR) {
    if (g_script.next_page >= g_script.npages)
      return DC_STATUS_IO;  // the driver asked for more pages than scripted
    if (!dc_buffer_append(buffer, g_script.pages[g_script.next_page],
                          MANIFEST_SIZE))
      return DC_STATUS_NOMEMORY;
    g_script.next_page++;
    return DC_STATUS_SUCCESS;
  }

  for (int i = 0; i < g_script.ndives; i++) {
    unsigned char id = g_script.dives[i].id;
    if (BASE_ADDR + (unsigned int)id * 0x1000 != address) continue;
    if (g_script.dives[i].fail) return DC_STATUS_TIMEOUT;
    unsigned char payload[DIVE_PAYLOAD_SIZE];
    memset(payload, 0xAB, sizeof(payload));
    payload[0] = id;
    payload[12] = 0xF0;
    payload[13] = 0;
    payload[14] = 0;
    payload[15] = id;  // fingerprint {0xF0, 0, 0, id} at buf + 12
    if (!dc_buffer_append(buffer, payload, sizeof(payload)))
      return DC_STATUS_NOMEMORY;
    return DC_STATUS_SUCCESS;
  }

  return DC_STATUS_IO;  // unknown address: the script has no such dive
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

typedef struct {
  unsigned char order[MAX_DIVES];  // dive ids in delivery order
  int n;
  int contract_ok;  // fsize == 4, fingerprint == data + 12, value matches
} cb_state_t;

static int dive_cb(const unsigned char *data, unsigned int size,
                   const unsigned char *fingerprint, unsigned int fsize,
                   void *userdata) {
  cb_state_t *s = (cb_state_t *)userdata;
  (void)size;
  if (fsize != 4 || fingerprint != data + 12 || fingerprint[0] != 0xF0 ||
      fingerprint[3] != data[0])
    s->contract_ok = 0;
  if (s->n < MAX_DIVES) s->order[s->n] = data[0];
  s->n++;
  return 1;
}

// Runs foreach against the current script with an optional resume fingerprint.
static dc_status_t run_foreach(const unsigned char *fingerprint,
                               cb_state_t *state) {
  dc_context_t *ctx = NULL;
  assert(dc_context_new(&ctx) == DC_STATUS_SUCCESS);

  shearwater_petrel_device_t dev;
  memset(&dev, 0, sizeof(dev));
  dev.base.base.context = ctx;
  if (fingerprint) memcpy(dev.fingerprint, fingerprint, 4);

  memset(state, 0, sizeof(*state));
  state->contract_ok = 1;

  dc_status_t rc =
      shearwater_petrel_device_foreach(&dev.base.base, dive_cb, state);

  dc_context_free(ctx);
  return rc;
}

static int failures = 0;

static void expect(int cond, const char *label) {
  if (cond) {
    printf("PASS: %s\n", label);
  } else {
    printf("FAIL: %s\n", label);
    failures++;
  }
}

static int order_is(const cb_state_t *s, const unsigned char *want, int n) {
  if (s->n != n) return 0;
  return memcmp(s->order, want, (size_t)n) == 0;
}

static void print_order(const cb_state_t *s) {
  printf("  delivered %d dive(s):", s->n);
  for (int i = 0; i < s->n && i < MAX_DIVES; i++) printf(" %u", s->order[i]);
  printf("\n");
}

// The manifest lists dives newest first (slot 0 is the newest); delivery must
// be oldest first so a partial run leaves a resumable oldest prefix.
static void check_oldest_first(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 3);  // newest
  set_record(0, 1, 0, 2);
  set_record(0, 2, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 0);
  script_add_dive(3, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {1, 2, 3};
  expect(rc == DC_STATUS_SUCCESS, "a full download succeeds");
  expect(order_is(&s, want, 3), "dives are delivered oldest first");
  if (s.n != 3 || memcmp(s.order, want, 3) != 0) print_order(&s);
  expect(s.contract_ok, "the fingerprint is buf + 12 of each dive's data");
}

// Valid records behind deleted (0x5A23) records must still be downloaded: the
// manifest phase must preserve every walked record, not a count-sized prefix.
static void check_deleted_records_preserved(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 4);  // newest
  set_record(0, 1, 1, 0);  // deleted
  set_record(0, 2, 0, 3);
  set_record(0, 3, 1, 0);  // deleted
  set_record(0, 4, 0, 2);
  set_record(0, 5, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 0);
  script_add_dive(3, 0);
  script_add_dive(4, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {1, 2, 3, 4};
  expect(rc == DC_STATUS_SUCCESS,
         "a download with deleted records succeeds");
  expect(order_is(&s, want, 4),
         "dives behind deleted records are still delivered, oldest first");
  if (s.n != 4 || memcmp(s.order, want, 4) != 0) print_order(&s);
}

// A failed dive download aborts the pass; everything delivered before it must
// be a contiguous oldest prefix so the newest imported fingerprint resumes
// correctly on the next attempt.
static void check_stop_on_failure(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 3);  // newest
  set_record(0, 1, 0, 2);  // this download fails (BLE timeout)
  set_record(0, 2, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 1);
  script_add_dive(3, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {1};
  expect(rc == DC_STATUS_TIMEOUT, "the dive failure is propagated");
  expect(order_is(&s, want, 1),
         "a failed download leaves a contiguous oldest prefix");
  if (s.n != 1 || s.order[0] != 1) print_order(&s);
}

// Resume: with the newest imported dive's fingerprint set, only newer dives
// are downloaded, oldest first, even across interspersed deleted records.
static void check_fingerprint_resume(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 4);  // newest
  set_record(0, 1, 0, 3);
  set_record(0, 2, 1, 0);  // deleted
  set_record(0, 3, 0, 2);  // resume point: already imported
  set_record(0, 4, 0, 1);
  script_add_dive(3, 0);
  script_add_dive(4, 0);

  const unsigned char resume[4] = {0xF0, 0, 0, 2};
  cb_state_t s;
  dc_status_t rc = run_foreach(resume, &s);
  const unsigned char want[] = {3, 4};
  expect(rc == DC_STATUS_SUCCESS, "a resumed download succeeds");
  expect(order_is(&s, want, 2),
         "resume downloads only the dives newer than the fingerprint, oldest first");
  if (s.n != 2 || memcmp(s.order, want, 2) != 0) print_order(&s);
}

// Deleted records must not be counted into the progress maximum: the final
// progress event has to reach exactly 100%.
static void check_progress_accounting(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 2);  // newest
  set_record(0, 1, 1, 0);  // deleted
  set_record(0, 2, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  expect(rc == DC_STATUS_SUCCESS, "a download with a deleted record succeeds");
  expect(g_last_progress.maximum != 0, "a final progress event was emitted");
  expect(g_last_progress.current == g_last_progress.maximum,
         "final progress reaches 100% despite deleted records");
  // 1 manifest page + 2 dives, NSTEPS each; the deleted record contributes
  // nothing to either side.
  expect(g_last_progress.maximum == 3 * NSTEPS,
         "the progress maximum counts only the page and the real dives");
  if (g_last_progress.current != g_last_progress.maximum ||
      g_last_progress.maximum != 3 * NSTEPS)
    printf("  final progress %u / %u\n", g_last_progress.current,
           g_last_progress.maximum);
}

// A full first manifest page (48 valid records) makes the driver fetch a
// second page; ordering must hold across the page boundary: the oldest dive
// lives on the LAST page.
static void check_multi_page(void) {
  script_reset();
  g_script.npages = 2;
  for (int slot = 0; slot < (int)RECORD_COUNT; slot++) {
    unsigned char id = (unsigned char)(49 - slot);  // page 0: ids 49..2
    set_record(0, slot, 0, id);
    script_add_dive(id, 0);
  }
  set_record(1, 0, 0, 1);  // page 1: the single oldest dive
  script_add_dive(1, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  unsigned char want[49];
  for (int i = 0; i < 49; i++) want[i] = (unsigned char)(i + 1);
  expect(rc == DC_STATUS_SUCCESS, "a two-page download succeeds");
  expect(order_is(&s, want, 49),
         "oldest-first ordering holds across manifest pages");
  if (s.n != 49 || memcmp(s.order, want, 49) != 0) print_order(&s);
}

int main(void) {
  check_oldest_first();
  check_deleted_records_preserved();
  check_stop_on_failure();
  check_fingerprint_resume();
  check_progress_accounting();
  check_multi_page();

  if (failures == 0) {
    printf("All shearwater_petrel_foreach tests passed.\n");
    return 0;
  }
  printf("%d shearwater_petrel_foreach test(s) FAILED.\n", failures);
  return 1;
}
