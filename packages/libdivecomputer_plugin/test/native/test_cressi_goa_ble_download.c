// Issue #422, end to end: the Cressi Goa BLE backend over a scripted BLE
// iostream. The platform bridges all answer DC_IOCTL_BLE_CHARACTERISTIC_READ
// through libdc_ble_characteristic_read_decode/_fill; this fake does the
// same, so the whole request/reply contract with the real cressi_goa.c is
// exercised here once. Without the ioctl the backend fails with "Failed to
// read the characteristic '6e400003-...'" before emitting DEVINFO.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "libdc_wrapper.h"

typedef struct {
    int ioctl_reads;
    int serve_reads;       // 0 = answer UNSUPPORTED like the old bridges
    size_t short_by;       // bytes to drop from each reply
} fake_io_t;

// Serial 0x00012345 LE, model 4 (Donatello), firmware 300 LE (data format
// v5), then the 2-byte third field. 5 + 2 + 2 bytes, as cressi_goa.c reads.
static const unsigned char kVersion03[5] = {0x45, 0x23, 0x01, 0x00, 0x04};
static const unsigned char kVersion04[2] = {0x2C, 0x01};
static const unsigned char kVersion05[2] = {0x00, 0x00};

static int fake_ioctl(void *userdata, unsigned int request, void *data,
                      size_t size) {
    fake_io_t *io = (fake_io_t *)userdata;
    char uuid[LIBDC_BLE_UUID_STRING_SIZE];
    size_t value_size = 0;
    int decoded = libdc_ble_characteristic_read_decode(request, data, size,
                                                       uuid, &value_size);
    if (decoded != LIBDC_BLE_CHAR_READ_OK || !io->serve_reads) {
        return LIBDC_STATUS_UNSUPPORTED;
    }
    io->ioctl_reads++;
    const unsigned char *value = NULL;
    size_t len = 0;
    if (strcmp(uuid, "6e400003-b5a3-f393-e0a9-e50e24dc10b8") == 0) {
        value = kVersion03; len = sizeof(kVersion03);
    } else if (strcmp(uuid, "6e400004-b5a3-f393-e0a9-e50e24dc10b8") == 0) {
        value = kVersion04; len = sizeof(kVersion04);
    } else if (strcmp(uuid, "6e400005-b5a3-f393-e0a9-e50e24dc10b8") == 0) {
        value = kVersion05; len = sizeof(kVersion05);
    } else {
        return LIBDC_STATUS_NOACCESS;
    }
    return libdc_ble_characteristic_read_fill(data, size, value,
                                              len - io->short_by);
}

static int fake_read(void *userdata, void *data, size_t size,
                     size_t *actual) {
    (void)userdata; (void)data; (void)size;
    if (actual) *actual = 0;
    return LIBDC_STATUS_IO;  // end the run at the logbook command
}

static int fake_write(void *userdata, const void *data, size_t size,
                      size_t *actual) {
    (void)userdata; (void)data;
    if (actual) *actual = size;
    return LIBDC_STATUS_SUCCESS;
}

static int fake_close(void *userdata) { (void)userdata; return 0; }

static void on_dive(const libdc_parsed_dive_t *dive, void *userdata) {
    (void)dive; (void)userdata;
}

typedef struct {
    int rc;
    unsigned int serial;
    unsigned int firmware;
    int has_reported;
    char product[64];
    unsigned int model;
    char error[256];
} run_result_t;

static run_result_t run(fake_io_t *io, const char *product,
                        unsigned int model) {
    run_result_t r;
    memset(&r, 0, sizeof(r));
    libdc_io_callbacks_t cbs;
    memset(&cbs, 0, sizeof(cbs));
    cbs.read = fake_read;
    cbs.write = fake_write;
    cbs.ioctl = fake_ioctl;
    cbs.close = fake_close;
    cbs.userdata = io;
    libdc_download_callbacks_t dl;
    memset(&dl, 0, sizeof(dl));
    dl.on_dive = on_dive;

    libdc_download_session_t *session = libdc_download_session_new();
    assert(session != NULL);
    libdc_clock_sync_status_t clock = LIBDC_CLOCK_SYNC_NOT_REQUESTED;
    r.rc = libdc_download_run(session, "Cressi", product, model,
                              LIBDC_TRANSPORT_BLE, &cbs, NULL, 0, 0, &dl,
                              &r.serial, &r.firmware, &clock, r.error,
                              sizeof(r.error));
    r.has_reported = libdc_download_session_reported_device(
        session, r.product, sizeof(r.product), &r.model);
    libdc_download_session_free(session);
    return r;
}

static void test_unanswered_ioctl_reproduces_the_issue(void) {
    fake_io_t io = {0, 0, 0};
    run_result_t r = run(&io, "Cartesio", 1);
    assert(r.rc != 0);
    assert(strstr(r.error, "Failed to read the characteristic") != NULL);
    assert(r.has_reported == 0);
    printf("PASS: test_unanswered_ioctl_reproduces_the_issue\n");
}

static void test_served_reads_reach_devinfo_and_relabel(void) {
    fake_io_t io = {0, 1, 0};
    run_result_t r = run(&io, "Cartesio", 1);
    assert(io.ioctl_reads == 3);
    assert(r.serial == 0x00012345u);
    assert(r.firmware == 300u);
    assert(strstr(r.error, "Failed to read the characteristic") == NULL);
    assert(r.has_reported == 1);
    assert(strcmp(r.product, "Donatello") == 0);
    assert(r.model == 4);
    printf("PASS: test_served_reads_reach_devinfo_and_relabel\n");
}

static void test_correct_label_reports_nothing(void) {
    fake_io_t io = {0, 1, 0};
    run_result_t r = run(&io, "Donatello", 4);
    assert(r.serial == 0x00012345u);
    assert(r.has_reported == 0);
    printf("PASS: test_correct_label_reports_nothing\n");
}

static void test_short_reply_fails_instead_of_misparsing(void) {
    fake_io_t io = {0, 1, 1};
    run_result_t r = run(&io, "Cartesio", 1);
    assert(r.rc != 0);
    assert(r.serial == 0);
    assert(r.has_reported == 0);
    printf("PASS: test_short_reply_fails_instead_of_misparsing\n");
}

int main(void) {
    test_unanswered_ioctl_reproduces_the_issue();
    test_served_reads_reach_devinfo_and_relabel();
    test_correct_label_reports_nothing();
    test_short_reply_fails_instead_of_misparsing();
    printf("All Cressi Goa BLE download tests passed.\n");
    return 0;
}
