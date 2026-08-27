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
int device_is_cancelled(dc_device_t *device) {
  (void)device;
  return 0;
}
// The retry path (#759) sleeps and purges the iostream between attempts;
// the mock transport has no iostream, so both are no-ops here.
dc_status_t dc_iostream_sleep(dc_iostream_t *iostream, unsigned int ms) {
  (void)iostream;
  (void)ms;
  return DC_STATUS_SUCCESS;
}
dc_status_t dc_iostream_purge(dc_iostream_t *iostream,
                              dc_direction_t direction) {
  (void)iostream;
  (void)direction;
  return DC_STATUS_SUCCESS;
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
  int manifest_nak;  // NAK (DC_STATUS_UNSUPPORTED) any page past the scripted ones
  struct {
    unsigned char id;
    int fail;  // serve DC_STATUS_TIMEOUT this many more times, then succeed
    int nak;   // device refuses this dive outright (DC_STATUS_UNSUPPORTED)
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
  g_script.dives[g_script.ndives].nak = 0;
  g_script.ndives++;
}

// The device refuses this dive's download init outright, the way a real unit
// NAKs a manifest record whose dive data it can no longer serve (issue #766).
static void script_add_dive_nak(unsigned char id) {
  assert(g_script.ndives < MAX_DIVES);
  g_script.dives[g_script.ndives].id = id;
  g_script.dives[g_script.ndives].fail = 0;
  g_script.dives[g_script.ndives].nak = 1;
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

// Writes one manifest record with an explicit big-endian ticks value at
// offset +4, instead of the {0xF0, 0, 0, id} pattern set_record() uses. The
// real Petrel fingerprint IS the dive start time (big-endian ticks) mirrored
// at this offset, so the timestamp-floor tests need to control that value
// directly rather than deriving it from the dive id. The storage address
// (offset +20) is still keyed off id, matching the mock's download lookup.
static void set_record_ticks(int page, int slot, int deleted,
                             unsigned int ticks, unsigned char id) {
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
  r[4] = (ticks >> 24) & 0xFF;
  r[5] = (ticks >> 16) & 0xFF;
  r[6] = (ticks >> 8) & 0xFF;
  r[7] = ticks & 0xFF;
  unsigned int address = (unsigned int)id * 0x1000;
  r[20] = (address >> 24) & 0xFF;
  r[21] = (address >> 16) & 0xFF;
  r[22] = (address >> 8) & 0xFF;
  r[23] = address & 0xFF;
}

// Encodes a ticks value as the big-endian 4-byte fingerprint device->fingerprint
// expects, so a test can set the resume/floor fingerprint directly from ticks.
static void ticks_to_fingerprint(unsigned int ticks, unsigned char fp[4]) {
  fp[0] = (ticks >> 24) & 0xFF;
  fp[1] = (ticks >> 16) & 0xFF;
  fp[2] = (ticks >> 8) & 0xFF;
  fp[3] = ticks & 0xFF;
}

dc_status_t shearwater_common_setup(shearwater_common_device_t *device,
                                    dc_context_t *context,
                                    dc_iostream_t *iostream,
                                    unsigned int model) {
  (void)device;
  (void)context;
  (void)iostream;
  (void)model;
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
      // Past the scripted pages: a real device NAKs the request when the
      // record area ends exactly on a page boundary (manifest_nak); an
      // unscripted request in any other test is still a script error (IO).
      return g_script.manifest_nak ? DC_STATUS_UNSUPPORTED : DC_STATUS_IO;
    if (!dc_buffer_append(buffer, g_script.pages[g_script.next_page],
                          MANIFEST_SIZE))
      return DC_STATUS_NOMEMORY;
    g_script.next_page++;
    return DC_STATUS_SUCCESS;
  }

  for (int i = 0; i < g_script.ndives; i++) {
    unsigned char id = g_script.dives[i].id;
    if (BASE_ADDR + (unsigned int)id * 0x1000 != address) continue;
    if (g_script.dives[i].nak)
      return DC_STATUS_UNSUPPORTED;
    if (g_script.dives[i].fail > 0) {
      g_script.dives[i].fail--;
      return DC_STATUS_TIMEOUT;
    }
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

// A persistently failed dive download ends the pass early; everything
// delivered before it must be a contiguous oldest prefix so the newest imported fingerprint resumes
// correctly on the next attempt.
static void check_partial_after_persistent_failure(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 3);  // newest
  set_record(0, 1, 0, 2);  // this download fails on every attempt
  set_record(0, 2, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 99);
  script_add_dive(3, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {1};
  expect(rc == DC_STATUS_SUCCESS,
         "a mid-pass persistent failure keeps the delivered dives (#759)");
  expect(order_is(&s, want, 1),
         "a failed download leaves a contiguous oldest prefix");
  if (s.n != 1 || s.order[0] != 1) print_order(&s);
}

// A transient failure (one lost BLE notification) must be retried and the
// pass completed in full (#759).
static void check_retry_recovers(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 3);  // newest
  set_record(0, 1, 0, 2);  // fails twice, succeeds on the third attempt
  set_record(0, 2, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 2);
  script_add_dive(3, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {1, 2, 3};
  expect(rc == DC_STATUS_SUCCESS, "a transient failure is retried");
  expect(order_is(&s, want, 3), "all dives delivered after the retry");
  if (s.n != 3) print_order(&s);
}

// With NOTHING delivered yet, a persistent failure is still a real error:
// zero dives plus DC_STATUS_SUCCESS would look like an empty computer.
static void check_total_failure_still_errors(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 2);  // newest
  set_record(0, 1, 0, 1);  // oldest; fails on every attempt
  script_add_dive(1, 99);
  script_add_dive(2, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  expect(rc == DC_STATUS_TIMEOUT,
         "a failure before any delivery propagates the error");
  expect(s.n == 0, "no dives delivered");
  if (s.n != 0) print_order(&s);
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

// ---------------------------------------------------------------------------
// Fingerprint timestamp floor: a resume fingerprint that matches NO manifest
// record (because the local logbook was seeded by an import rather than a
// prior device download) is treated as a timestamp floor instead of being
// ignored. Records at or before the floor are skipped without a download
// request; the floor logic must stay inert whenever the fingerprint matches
// a record exactly, and whenever the fingerprint is all zeros.
// ---------------------------------------------------------------------------

// Manifest listed newest first: ticks 4000, 3000, 2000, 1000. A floor of
// 2500 matches no record, so only the two dives newer than the floor
// (3000, 4000) should be delivered, oldest first, and the two at-or-below
// the floor (1000, 2000) must never be requested: they are deliberately left
// out of the download script below, so a request for either one turns into
// an unscripted-address DC_STATUS_IO and fails the test.
static void test_floor_skips_older_dives(void) {
  script_reset();
  g_script.npages = 1;
  set_record_ticks(0, 0, 0, 4000, 4);  // newest
  set_record_ticks(0, 1, 0, 3000, 3);
  set_record_ticks(0, 2, 0, 2000, 2);  // at/below floor: must not be requested
  set_record_ticks(0, 3, 0, 1000, 1);  // at/below floor: must not be requested
  script_add_dive(3, 0);
  script_add_dive(4, 0);

  unsigned char fp[4];
  ticks_to_fingerprint(2500, fp);  // matches no record

  cb_state_t s;
  dc_status_t rc = run_foreach(fp, &s);
  const unsigned char want[] = {3, 4};
  expect(rc == DC_STATUS_SUCCESS,
         "an unmatched fingerprint floor download succeeds");
  expect(order_is(&s, want, 2),
         "only dives newer than the floor are delivered, oldest first");
  if (s.n != 2 || memcmp(s.order, want, 2) != 0) print_order(&s);
  expect(g_last_progress.maximum != 0, "a final progress event was emitted");
  expect(g_last_progress.current == g_last_progress.maximum,
         "final progress reaches 100% with the floor active");
}

// Same manifest, but the fingerprint is an EXACT match for the ticks-2000
// record. The manifest walk truncates at the match (found = 1), so only
// records newer than the match (3000, 4000) are ever walked/appended, and
// the floor logic must stay inert -- delivery and download requests are
// identical to the pre-patch driver's plain fingerprint-resume behavior.
static void test_exact_match_behavior_unchanged(void) {
  script_reset();
  g_script.npages = 1;
  set_record_ticks(0, 0, 0, 4000, 4);  // newest
  set_record_ticks(0, 1, 0, 3000, 3);
  set_record_ticks(0, 2, 0, 2000, 2);  // exact match: walk stops here
  set_record_ticks(0, 3, 0, 1000, 1);
  script_add_dive(3, 0);
  script_add_dive(4, 0);

  unsigned char fp[4];
  ticks_to_fingerprint(2000, fp);  // exact match

  cb_state_t s;
  dc_status_t rc = run_foreach(fp, &s);
  const unsigned char want[] = {3, 4};
  expect(rc == DC_STATUS_SUCCESS, "an exact-match resume download succeeds");
  expect(order_is(&s, want, 2),
         "exact match delivers only the newer dives, oldest first, "
         "unchanged from pre-floor behavior");
  if (s.n != 2 || memcmp(s.order, want, 2) != 0) print_order(&s);
}

// Same manifest, fingerprint unset (all zeros): the floor must be inert and
// every dive downloaded, oldest first.
static void test_zero_fingerprint_downloads_all(void) {
  script_reset();
  g_script.npages = 1;
  set_record_ticks(0, 0, 0, 4000, 4);  // newest
  set_record_ticks(0, 1, 0, 3000, 3);
  set_record_ticks(0, 2, 0, 2000, 2);
  set_record_ticks(0, 3, 0, 1000, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive(2, 0);
  script_add_dive(3, 0);
  script_add_dive(4, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);  // NULL -> device->fingerprint stays zero
  const unsigned char want[] = {1, 2, 3, 4};
  expect(rc == DC_STATUS_SUCCESS, "a zero-fingerprint download succeeds");
  expect(order_is(&s, want, 4),
         "a zero fingerprint downloads every dive, oldest first");
  if (s.n != 4 || memcmp(s.order, want, 4) != 0) print_order(&s);
}

// A deleted record (0x5A23) interspersed among records at/below the floor
// must not disturb the floor accounting: it contributes nothing to the
// progress maximum (deleted records never did) and is skipped by its own
// deleted-record check before the floor comparison ever runs on it.
static void test_floor_deleted_record_below_floor_unaffected(void) {
  script_reset();
  g_script.npages = 1;
  set_record_ticks(0, 0, 0, 4000, 4);  // newest
  set_record_ticks(0, 1, 0, 3000, 3);
  set_record_ticks(0, 2, 0, 2000, 2);  // at/below floor
  set_record(0, 3, 1, 0);              // deleted, interspersed below the floor
  set_record_ticks(0, 4, 0, 1000, 1);  // at/below floor, oldest
  script_add_dive(3, 0);
  script_add_dive(4, 0);

  unsigned char fp[4];
  ticks_to_fingerprint(2500, fp);  // matches no record

  cb_state_t s;
  dc_status_t rc = run_foreach(fp, &s);
  const unsigned char want[] = {3, 4};
  expect(rc == DC_STATUS_SUCCESS,
         "a floor download with a deleted record below the floor succeeds");
  expect(order_is(&s, want, 2),
         "the deleted record does not change which dives are delivered");
  if (s.n != 2 || memcmp(s.order, want, 2) != 0) print_order(&s);
  expect(g_last_progress.current == g_last_progress.maximum,
         "final progress still reaches 100%");
  // 1 manifest page + 2 delivered dives; the two below-floor records and the
  // deleted record all contribute nothing to the maximum.
  expect(g_last_progress.maximum == 3 * NSTEPS,
         "the deleted record is not double-counted against the floor");
  if (g_last_progress.maximum != 3 * NSTEPS)
    printf("  final progress %u / %u\n", g_last_progress.current,
           g_last_progress.maximum);
}

// ---------------------------------------------------------------------------
// Issue #766: the reporter's Petrel 3 and Nerd 2 NAK the download init for
// the OLDEST manifest record (data the device can no longer serve), and with
// oldest-first delivery that refusal struck before any dive was delivered, so
// every download attempt aborted with zero dives. A refused record must be
// skipped -- it is deterministic, the retry loop cannot help, and the data is
// gone -- while refusal of EVERY record must still surface as an error so a
// wrong logbook base address stays diagnosable.
// ---------------------------------------------------------------------------

// The oldest record is refused: the pass must skip it, deliver everything
// else, and end with exact progress accounting.
static void check_nak_oldest_dive_skipped(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 3);  // newest
  set_record(0, 1, 0, 2);
  set_record(0, 2, 0, 1);  // oldest; the device refuses to serve it
  script_add_dive_nak(1);
  script_add_dive(2, 0);
  script_add_dive(3, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {2, 3};
  expect(rc == DC_STATUS_SUCCESS,
         "a refused oldest dive does not abort the pass (#766)");
  expect(order_is(&s, want, 2),
         "the refused dive is skipped and the rest delivered oldest first");
  if (s.n != 2 || memcmp(s.order, want, 2) != 0) print_order(&s);
  expect(g_last_progress.current == g_last_progress.maximum,
         "final progress reaches 100% despite the skipped dive");
  // 1 manifest page + 2 delivered dives; the refused record is dropped from
  // the maximum like a deleted or below-floor record.
  expect(g_last_progress.maximum == 3 * NSTEPS,
         "the refused dive is dropped from the progress maximum");
  if (g_last_progress.current != g_last_progress.maximum ||
      g_last_progress.maximum != 3 * NSTEPS)
    printf("  final progress %u / %u\n", g_last_progress.current,
           g_last_progress.maximum);
}

// A refusal in the middle of the pass must skip only that dive: everything
// after it (newer) still downloads, unlike the keep-partial path that ends
// the pass at the first persistent TIMEOUT.
static void check_nak_mid_pass_skipped(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 3);  // newest
  set_record(0, 1, 0, 2);  // refused
  set_record(0, 2, 0, 1);  // oldest
  script_add_dive(1, 0);
  script_add_dive_nak(2);
  script_add_dive(3, 0);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  const unsigned char want[] = {1, 3};
  expect(rc == DC_STATUS_SUCCESS, "a mid-pass refusal does not end the pass");
  expect(order_is(&s, want, 2),
         "only the refused dive is skipped; newer dives still download");
  if (s.n != 2 || memcmp(s.order, want, 2) != 0) print_order(&s);
}

// Every record refused and nothing delivered: this is NOT a poisoned oldest
// record but something systemic (e.g. requesting dives at the wrong logbook
// base address), and reporting success with zero dives would make it
// undiagnosable. The error must propagate.
static void check_all_nak_still_errors(void) {
  script_reset();
  g_script.npages = 1;
  set_record(0, 0, 0, 2);  // newest
  set_record(0, 1, 0, 1);  // oldest
  script_add_dive_nak(1);
  script_add_dive_nak(2);

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  expect(rc != DC_STATUS_SUCCESS,
         "refusal of every dive with nothing delivered stays an error");
  expect(s.n == 0, "no dives delivered when every request is refused");
  if (s.n != 0) print_order(&s);
}

// A logbook whose record area ends exactly on a page boundary: the walk
// cannot tell a full final page from a truncated one, so it requests one
// page too many and the device NAKs it. That refusal is the normal end of
// the manifest, not an error (#766).
static void check_manifest_nak_after_full_page_ends_walk(void) {
  script_reset();
  g_script.npages = 1;
  g_script.manifest_nak = 1;
  for (int slot = 0; slot < (int)RECORD_COUNT; slot++) {
    unsigned char id = (unsigned char)(RECORD_COUNT - slot);  // ids 48..1
    set_record(0, slot, 0, id);
    script_add_dive(id, 0);
  }

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  unsigned char want[RECORD_COUNT];
  for (int i = 0; i < (int)RECORD_COUNT; i++) want[i] = (unsigned char)(i + 1);
  expect(rc == DC_STATUS_SUCCESS,
         "a refused page after a full page ends the manifest walk");
  expect(order_is(&s, want, (int)RECORD_COUNT),
         "every dive from the full page is still delivered oldest first");
  if (s.n != (int)RECORD_COUNT) print_order(&s);
  expect(g_last_progress.current == g_last_progress.maximum,
         "final progress reaches 100% after the refused page");
  // 1 delivered page + 48 dives; the refused page contributes nothing.
  expect(g_last_progress.maximum == (1 + RECORD_COUNT) * NSTEPS,
         "the refused page is dropped from the progress maximum");
  if (g_last_progress.current != g_last_progress.maximum ||
      g_last_progress.maximum != (1 + RECORD_COUNT) * NSTEPS)
    printf("  final progress %u / %u\n", g_last_progress.current,
           g_last_progress.maximum);
}

// A refusal of the FIRST page is not an end-of-manifest signal: nothing was
// read yet, so something is wrong with the device or the request, and the
// error must propagate rather than masquerade as an empty logbook.
static void check_manifest_nak_first_page_still_errors(void) {
  script_reset();
  g_script.npages = 0;
  g_script.manifest_nak = 1;

  cb_state_t s;
  dc_status_t rc = run_foreach(NULL, &s);
  expect(rc != DC_STATUS_SUCCESS,
         "a refused first manifest page stays an error");
  expect(s.n == 0, "no dives delivered on a refused first page");
  if (s.n != 0) print_order(&s);
}

int main(void) {
  check_oldest_first();
  check_deleted_records_preserved();
  check_partial_after_persistent_failure();
  check_retry_recovers();
  check_total_failure_still_errors();
  check_fingerprint_resume();
  check_progress_accounting();
  check_multi_page();
  test_floor_skips_older_dives();
  test_exact_match_behavior_unchanged();
  test_zero_fingerprint_downloads_all();
  test_floor_deleted_record_below_floor_unaffected();
  check_nak_oldest_dive_skipped();
  check_nak_mid_pass_skipped();
  check_all_nak_still_errors();
  check_manifest_nak_after_full_page_ends_walk();
  check_manifest_nak_first_page_still_errors();

  if (failures == 0) {
    printf("All shearwater_petrel_foreach tests passed.\n");
    return 0;
  }
  printf("%d shearwater_petrel_foreach test(s) FAILED.\n", failures);
  return 1;
}
