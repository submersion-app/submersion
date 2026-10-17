// Issue #2902: the Halcyon Symbios backend over a scripted BLE iostream.
// Every failed Symbios transfer in the reporter's iOS log stops right after
// an ACK: the next block never arrives, the read times out after 3 s, and the
// driver aborted the whole download, leaving the device stuck mid-transfer
// for the next session too. The fake below speaks the Symbios block protocol
// (status, logbook and dive requests, ACK to advance, NAK to re-send the
// current block) and can lose one block, deliver it late, or go silent.
//
// Every check here is an assert, so a build that defines NDEBUG would pass
// without checking anything.
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "array.h"
#include "checksum.h"
#include "libdc_wrapper.h"

#define MAX_QUEUE 8
#define MAX_PACKET 260
#define BLOCK_SIZE 200
#define LOGBOOK_ENTRY 32
#define LOGBOOK_ENTRIES 13  // 416 bytes: three blocks
#define DIVE_SIZE 450       // three blocks

#define CMD_ACK 0x06
#define CMD_NAK 0x15

typedef enum { FAULT_NONE, FAULT_LOST, FAULT_LATE, FAULT_SILENT } fault_t;

typedef struct {
    // Notifications waiting to be read, one packet each.
    unsigned char queue[MAX_QUEUE][MAX_PACKET];
    size_t queue_len[MAX_QUEUE];
    unsigned int queue_head;
    unsigned int queue_count;

    // The file being streamed.
    unsigned char block_rsp;  // 0x88 logbook, 0x89 dive
    const unsigned char *file;
    size_t file_size;
    size_t offset;       // start of the current block
    size_t block_bytes;  // size of the current block
    unsigned int seq;
    int streaming;

    // The fault hits the block that answers the ACK of block fault_after_seq
    // in file fault_file (0 is the logbook, 1 the first dive).
    fault_t fault;
    int fault_file;
    unsigned int fault_after_seq;
    int fault_done;
    int silent;
    unsigned char late[MAX_PACKET];
    size_t late_len;

    unsigned int dive_requested;  // dive number of the last 0x05 request
    int files_started;
    int files_completed;
    int naks;
    int timeouts;
    int timeout_ms;
    unsigned int last_sleep_ms;
    char trace[64];  // T read timeout, S sleep, P input purge, N NAK
} fake_symbios_t;

static unsigned char g_logbook[LOGBOOK_ENTRY * LOGBOOK_ENTRIES];
static unsigned char g_dive[DIVE_SIZE];

static void build_fixtures(void) {
    memset(g_logbook, 0, sizeof(g_logbook));
    for (unsigned int i = 0; i < LOGBOOK_ENTRIES; i++) {
        unsigned char *entry = g_logbook + i * LOGBOOK_ENTRY;
        entry[16] = (unsigned char)(i + 1);  // dive number, LE
        entry[20] = (unsigned char)(0xA0 + i);  // fingerprint
        entry[21] = 0xB0;
        entry[22] = 0xC0;
        entry[23] = 0xD0;
    }
    for (unsigned int i = 0; i < DIVE_SIZE; i++) {
        g_dive[i] = (unsigned char)i;
    }
}

static const unsigned char *entry_fingerprint(unsigned int index) {
    return g_logbook + index * LOGBOOK_ENTRY + 20;
}

static void trace(fake_symbios_t *io, char c) {
    size_t n = strlen(io->trace);
    if (n + 1 < sizeof(io->trace)) {
        io->trace[n] = c;
        io->trace[n + 1] = '\0';
    }
}

static void enqueue(fake_symbios_t *io, const unsigned char *packet,
                    size_t len) {
    assert(io->queue_count < MAX_QUEUE);
    unsigned int slot = (io->queue_head + io->queue_count) % MAX_QUEUE;
    memcpy(io->queue[slot], packet, len);
    io->queue_len[slot] = len;
    io->queue_count++;
}

// [response, ACK, payload..., crc8 over ACK and payload]
static size_t build_packet(unsigned char *out, unsigned char rsp,
                           const unsigned char *payload, size_t n) {
    out[0] = rsp;
    out[1] = CMD_ACK;
    memcpy(out + 2, payload, n);
    out[2 + n] = checksum_crc8(out + 1, (unsigned int)(n + 1), 0x00, 0x00);
    return n + 3;
}

static void reply(fake_symbios_t *io, unsigned char rsp,
                  const unsigned char *payload, size_t n) {
    unsigned char packet[MAX_PACKET];
    enqueue(io, packet, build_packet(packet, rsp, payload, n));
}

static void reply_length(fake_symbios_t *io, unsigned char rsp,
                         size_t length) {
    unsigned char le[4];
    array_uint32_le_set(le, (unsigned int)length);
    reply(io, rsp, le, sizeof(le));
}

static void send_block(fake_symbios_t *io, int allow_fault) {
    size_t remaining = io->file_size - io->offset;
    io->block_bytes = remaining < BLOCK_SIZE ? remaining : BLOCK_SIZE;
    int last = io->offset + io->block_bytes >= io->file_size;
    unsigned int id = io->seq | (last ? 0x8000u : 0u);

    unsigned char payload[2 + BLOCK_SIZE];
    array_uint16_le_set(payload, (unsigned short)id);
    memcpy(payload + 2, io->file + io->offset, io->block_bytes);

    unsigned char packet[MAX_PACKET];
    size_t len = build_packet(packet, io->block_rsp, payload,
                              io->block_bytes + 2);

    if (allow_fault && io->fault != FAULT_NONE && !io->fault_done &&
        io->files_started - 1 == io->fault_file &&
        io->seq == io->fault_after_seq + 1) {
        io->fault_done = 1;
        if (io->fault == FAULT_LATE) {
            memcpy(io->late, packet, len);
            io->late_len = len;
        } else if (io->fault == FAULT_SILENT) {
            io->silent = 1;
        }
        return;  // FAULT_LOST: the notification never arrives
    }
    enqueue(io, packet, len);
}

// The late block reaches the queue: during the driver's wait if it waits,
// otherwise by the time it sends its next command.
static void deliver_late(fake_symbios_t *io) {
    if (io->late_len) {
        enqueue(io, io->late, io->late_len);
        io->late_len = 0;
    }
}

static int fake_write(void *userdata, const void *data, size_t size,
                      size_t *actual) {
    fake_symbios_t *io = (fake_symbios_t *)userdata;
    const unsigned char *cmd = (const unsigned char *)data;
    if (actual) *actual = size;
    if (size == 0) return LIBDC_STATUS_SUCCESS;
    if (cmd[0] == CMD_NAK) {
        io->naks++;
        trace(io, 'N');
    }
    // A late block the driver did not wait for lands now, ahead of
    // whatever this command makes the device send.
    deliver_late(io);
    if (io->silent) return LIBDC_STATUS_SUCCESS;

    switch (cmd[0]) {
    case 0x01: {  // status
        unsigned char info[36] = {0x76, 0xF9, 0x78, 0x8F, 0x0C, 0x07};
        reply(io, 0x81, info, sizeof(info));
        break;
    }
    case 0x04:  // logbook request
        io->file = g_logbook;
        io->file_size = sizeof(g_logbook);
        io->block_rsp = 0x88;
        reply_length(io, 0x84, io->file_size);
        break;
    case 0x05:  // dive request: number + crc
        assert(size == 4);
        assert(cmd[3] == checksum_crc8(cmd + 1, 2, 0x00, 0x00));
        io->dive_requested = array_uint16_le(cmd + 1);
        io->file = g_dive;
        io->file_size = sizeof(g_dive);
        io->block_rsp = 0x89;
        reply_length(io, 0x85, io->file_size);
        break;
    case 0x08:  // first logbook block
    case 0x09:  // first dive block
        io->files_started++;
        io->offset = 0;
        io->seq = 1;
        io->streaming = 1;
        send_block(io, 1);
        break;
    case CMD_ACK:
        if (!io->streaming) break;
        if (io->offset + io->block_bytes >= io->file_size) {
            io->streaming = 0;
            io->files_completed++;
            break;
        }
        io->offset += io->block_bytes;
        io->seq++;
        send_block(io, 1);
        break;
    case CMD_NAK:
        if (io->streaming) send_block(io, 0);
        break;
    default:
        break;
    }
    return LIBDC_STATUS_SUCCESS;
}

static int fake_read(void *userdata, void *data, size_t size,
                     size_t *actual) {
    fake_symbios_t *io = (fake_symbios_t *)userdata;
    if (io->queue_count == 0) {
        io->timeouts++;
        trace(io, 'T');
        if (actual) *actual = 0;
        return LIBDC_STATUS_TIMEOUT;
    }
    unsigned int slot = io->queue_head;
    size_t len = io->queue_len[slot] < size ? io->queue_len[slot] : size;
    memcpy(data, io->queue[slot], len);
    io->queue_head = (io->queue_head + 1) % MAX_QUEUE;
    io->queue_count--;
    if (actual) *actual = len;
    return LIBDC_STATUS_SUCCESS;
}

static int fake_set_timeout(void *userdata, int timeout) {
    ((fake_symbios_t *)userdata)->timeout_ms = timeout;
    return LIBDC_STATUS_SUCCESS;
}

static int fake_purge(void *userdata, unsigned int direction) {
    fake_symbios_t *io = (fake_symbios_t *)userdata;
    if (direction & 1u) {
        io->queue_head = 0;
        io->queue_count = 0;
        trace(io, 'P');
    }
    return LIBDC_STATUS_SUCCESS;
}

static int fake_sleep(void *userdata, unsigned int milliseconds) {
    fake_symbios_t *io = (fake_symbios_t *)userdata;
    io->last_sleep_ms = milliseconds;
    trace(io, 'S');
    deliver_late(io);
    return LIBDC_STATUS_SUCCESS;
}

static int fake_close(void *userdata) { (void)userdata; return 0; }

static void on_dive(const libdc_parsed_dive_t *dive, void *userdata) {
    (void)dive; (void)userdata;
}

static int run(fake_symbios_t *io, const unsigned char *fingerprint) {
    libdc_io_callbacks_t cbs;
    memset(&cbs, 0, sizeof(cbs));
    cbs.set_timeout = fake_set_timeout;
    cbs.read = fake_read;
    cbs.write = fake_write;
    cbs.purge = fake_purge;
    cbs.sleep = fake_sleep;
    cbs.close = fake_close;
    cbs.userdata = io;
    libdc_download_callbacks_t dl;
    memset(&dl, 0, sizeof(dl));
    dl.on_dive = on_dive;

    libdc_download_session_t *session = libdc_download_session_new();
    assert(session != NULL);
    unsigned int serial = 0, firmware = 0;
    libdc_clock_sync_status_t clock = LIBDC_CLOCK_SYNC_NOT_REQUESTED;
    char error[256] = {0};
    int rc = libdc_download_run(session, "Halcyon", "Symbios Handset", 7,
                                LIBDC_TRANSPORT_BLE, &cbs, fingerprint,
                                fingerprint ? 4 : 0, 0, &dl, &serial,
                                &firmware, &clock, error, sizeof(error));
    libdc_download_session_free(session);
    return rc;
}

static void init(fake_symbios_t *io, fault_t fault, int file,
                 unsigned int after_seq) {
    memset(io, 0, sizeof(*io));
    io->fault = fault;
    io->fault_file = file;
    io->fault_after_seq = after_seq;
}

static void test_clean_transfer_uses_a_five_second_timeout(void) {
    fake_symbios_t io;
    init(&io, FAULT_NONE, 0, 0);
    int rc = run(&io, entry_fingerprint(LOGBOOK_ENTRIES - 1));
    assert(rc == LIBDC_STATUS_SUCCESS);
    assert(io.timeout_ms == 5000);
    assert(io.files_completed == 1);
    assert(io.naks == 0);
    assert(io.timeouts == 0);
    printf("PASS: test_clean_transfer_uses_a_five_second_timeout\n");
}

static void test_lost_logbook_block_is_requested_again(void) {
    fake_symbios_t io;
    init(&io, FAULT_LOST, 0, 1);
    int rc = run(&io, entry_fingerprint(LOGBOOK_ENTRIES - 1));
    assert(rc == LIBDC_STATUS_SUCCESS);
    assert(io.files_completed == 1);
    assert(io.naks == 1);
    assert(strstr(io.trace, "TSPN") != NULL);
    printf("PASS: test_lost_logbook_block_is_requested_again\n");
}

static void test_lost_dive_block_is_requested_again(void) {
    fake_symbios_t io;
    init(&io, FAULT_LOST, 1, 1);
    // One dive newer than the fingerprint: the logbook, then that dive.
    int rc = run(&io, entry_fingerprint(LOGBOOK_ENTRIES - 2));
    assert(rc == LIBDC_STATUS_SUCCESS);
    assert(io.dive_requested == LOGBOOK_ENTRIES);  // the newest entry
    assert(io.files_started == 2);
    assert(io.files_completed == 2);
    assert(io.naks == 1);
    printf("PASS: test_lost_dive_block_is_requested_again\n");
}

static void test_late_block_is_purged_before_the_nak(void) {
    fake_symbios_t io;
    init(&io, FAULT_LATE, 0, 1);
    int rc = run(&io, entry_fingerprint(LOGBOOK_ENTRIES - 1));
    // The late copy lands during the 300 ms wait. Without the wait, or
    // without the purge after it, that copy is read as the re-sent block,
    // and the real re-sent copy then arrives where the next block should be.
    assert(rc == LIBDC_STATUS_SUCCESS);
    assert(io.files_completed == 1);
    assert(io.naks == 1);
    assert(io.last_sleep_ms == 300);
    assert(strstr(io.trace, "TSPN") != NULL);
    printf("PASS: test_late_block_is_purged_before_the_nak\n");
}

static void test_silent_device_still_fails_after_the_retries(void) {
    fake_symbios_t io;
    init(&io, FAULT_SILENT, 0, 1);
    int rc = run(&io, entry_fingerprint(LOGBOOK_ENTRIES - 1));
    assert(rc == LIBDC_STATUS_TIMEOUT);
    assert(io.files_completed == 0);
    assert(io.naks == 3);
    assert(io.timeouts == 4);
    printf("PASS: test_silent_device_still_fails_after_the_retries\n");
}

int main(void) {
    build_fixtures();
    test_clean_transfer_uses_a_five_second_timeout();
    test_lost_logbook_block_is_requested_again();
    test_lost_dive_block_is_requested_again();
    test_late_block_is_purged_before_the_nak();
    test_silent_device_still_fails_after_the_retries();
    printf("All Halcyon Symbios BLE download tests passed.\n");
    return 0;
}
