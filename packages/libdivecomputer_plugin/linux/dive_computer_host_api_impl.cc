#include "dive_computer_host_api_impl.h"

#include <string.h>

extern "C" {
#include "ble_io_stream.h"
#include "ble_scanner.h"
#include "dive_converter.h"
#include "libdc_wrapper.h"
#include "serial_io_stream.h"
#include "serial_scanner.h"
}

// Context passed as user_data through the VTable.
struct HostApiContext {
  FlBinaryMessenger* messenger;
  LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
  BleScanner* ble_scanner;
  SerialScanner* serial_scanner;
  BleIoStream* ble_stream;
  SerialIoStream* serial_stream;
  libdc_download_session_t* session;
  GThread* download_thread;
  // When true, on_dive_downloaded buffers dives instead of dispatching them
  // immediately. Used during multi-port probing to avoid leaking phantom
  // dives from a wrong port to Flutter.
  gboolean buffer_dives;
  GList* buffered_dives;  // list of LibdivecomputerPluginParsedDive*
};

static void host_api_context_free(gpointer data) {
  auto* ctx = static_cast<HostApiContext*>(data);
  if (ctx->ble_scanner != nullptr) {
    ble_scanner_free(ctx->ble_scanner);
  }
  if (ctx->serial_scanner != nullptr) {
    serial_scanner_free(ctx->serial_scanner);
  }
  if (ctx->ble_stream != nullptr) {
    ble_io_stream_free(ctx->ble_stream);
  }
  if (ctx->serial_stream != nullptr) {
    serial_io_stream_free(ctx->serial_stream);
  }
  if (ctx->session != nullptr) {
    libdc_download_session_free(ctx->session);
  }
  if (ctx->buffered_dives != nullptr) {
    g_list_free_full(ctx->buffered_dives, g_object_unref);
  }
  if (ctx->flutter_api != nullptr) {
    g_object_unref(ctx->flutter_api);
  }
  delete ctx;
}

// Converts a libdivecomputer transport bitmask to a Pigeon-compatible FlValue
// list of TransportType enum values.
static FlValue* transports_to_fl_value(unsigned int transports) {
  FlValue* list = fl_value_new_list();
  if (transports & LIBDC_TRANSPORT_BLE) {
    fl_value_append_take(
        list,
        fl_value_new_custom(
            129, fl_value_new_int(LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_BLE),
            (GDestroyNotify)fl_value_unref));
  }
  if (transports & (LIBDC_TRANSPORT_USB | LIBDC_TRANSPORT_USBHID)) {
    fl_value_append_take(
        list,
        fl_value_new_custom(
            129, fl_value_new_int(LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_USB),
            (GDestroyNotify)fl_value_unref));
  }
  if (transports & LIBDC_TRANSPORT_SERIAL) {
    fl_value_append_take(
        list,
        fl_value_new_custom(
            129,
            fl_value_new_int(LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_SERIAL),
            (GDestroyNotify)fl_value_unref));
  }
  if (transports & LIBDC_TRANSPORT_IRDA) {
    fl_value_append_take(
        list,
        fl_value_new_custom(
            129,
            fl_value_new_int(LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_INFRARED),
            (GDestroyNotify)fl_value_unref));
  }
  return list;
}

// --- BLE scanner callbacks ---

static void on_ble_device_discovered(
    LibdivecomputerPluginDiscoveredDevice* device, gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);
  libdivecomputer_plugin_dive_computer_flutter_api_on_device_discovered(
      ctx->flutter_api, device, nullptr, nullptr, nullptr);
}

static void on_ble_scan_complete(gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);
  libdivecomputer_plugin_dive_computer_flutter_api_on_discovery_complete(
      ctx->flutter_api, nullptr, nullptr, nullptr);
}

// --- Serial scanner callbacks ---

static void on_serial_device_discovered(
    LibdivecomputerPluginDiscoveredDevice* device, gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);
  libdivecomputer_plugin_dive_computer_flutter_api_on_device_discovered(
      ctx->flutter_api, device, nullptr, nullptr, nullptr);
}

static void on_serial_scan_complete(gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);
  libdivecomputer_plugin_dive_computer_flutter_api_on_discovery_complete(
      ctx->flutter_api, nullptr, nullptr, nullptr);
}

// --- Download thread data ---

struct DownloadThreadData {
  HostApiContext* ctx;
  gchar* vendor;
  gchar* product;
  guint32 model;
  gchar* address;
  gchar* fingerprint;
  LibdivecomputerPluginTransportType transport;
};

static void download_thread_data_free(DownloadThreadData* data) {
  g_free(data->vendor);
  g_free(data->product);
  g_free(data->address);
  g_free(data->fingerprint);
  delete data;
}

// Dispatch download progress to the main thread via g_idle_add.
// Flutter API calls must not be made from the download thread.
struct ProgressCallbackData {
    LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
    int64_t current;
    int64_t maximum;
};

static gboolean progress_callback_idle(gpointer data) {
    auto* cbd = static_cast<ProgressCallbackData*>(data);
    LibdivecomputerPluginDownloadProgress* progress =
        libdivecomputer_plugin_download_progress_new(
            cbd->current, cbd->maximum, "downloading");
    libdivecomputer_plugin_dive_computer_flutter_api_on_download_progress(
        cbd->flutter_api, progress, nullptr, nullptr, nullptr);
    g_object_unref(progress);
    delete cbd;
    return G_SOURCE_REMOVE;
}

static void on_download_progress(unsigned int current, unsigned int maximum,
                                 void* userdata) {
  auto* ctx = static_cast<HostApiContext*>(userdata);
  auto* cbd = new ProgressCallbackData();
  cbd->flutter_api = ctx->flutter_api;
  cbd->current = (int64_t)current;
  cbd->maximum = (int64_t)maximum;
  g_idle_add(progress_callback_idle, cbd);
}

// Dispatch downloaded dive to the main thread via g_idle_add.
struct DiveCallbackData {
    LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
    LibdivecomputerPluginParsedDive* parsed;
};

static gboolean dive_callback_idle(gpointer data) {
    auto* cbd = static_cast<DiveCallbackData*>(data);
    libdivecomputer_plugin_dive_computer_flutter_api_on_dive_downloaded(
        cbd->flutter_api, cbd->parsed, nullptr, nullptr, nullptr);
    g_object_unref(cbd->parsed);
    delete cbd;
    return G_SOURCE_REMOVE;
}

static void on_dive_downloaded(const libdc_parsed_dive_t* dive,
                               void* userdata) {
  auto* ctx = static_cast<HostApiContext*>(userdata);
  LibdivecomputerPluginParsedDive* parsed = convert_parsed_dive(dive);
  if (parsed != nullptr) {
    if (ctx->buffer_dives) {
      // During multi-port probing, buffer dives until we confirm the port
      // is correct. This prevents phantom dives from wrong ports leaking
      // to Flutter.
      ctx->buffered_dives = g_list_append(ctx->buffered_dives, parsed);
    } else {
      auto* cbd = new DiveCallbackData();
      cbd->flutter_api = ctx->flutter_api;
      cbd->parsed = parsed;
      g_idle_add(dive_callback_idle, cbd);
    }
  }
}

// Flush buffered dives to Flutter via g_idle_add. Called after a successful
// download during multi-port probing.
static void flush_buffered_dives(HostApiContext* ctx) {
    for (GList* l = ctx->buffered_dives; l != NULL; l = l->next) {
        auto* parsed = static_cast<LibdivecomputerPluginParsedDive*>(l->data);
        auto* cbd = new DiveCallbackData();
        cbd->flutter_api = ctx->flutter_api;
        cbd->parsed = parsed;
        g_object_ref(parsed);
        g_idle_add(dive_callback_idle, cbd);
    }
    g_list_free_full(ctx->buffered_dives, g_object_unref);
    ctx->buffered_dives = nullptr;
}

// Discard buffered dives from a failed probe attempt.
static void clear_buffered_dives(HostApiContext* ctx) {
    if (ctx->buffered_dives != nullptr) {
        g_list_free_full(ctx->buffered_dives, g_object_unref);
        ctx->buffered_dives = nullptr;
    }
}

struct PinCallbackData {
    LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
    gchar* address;
};

static gboolean pin_callback_idle(gpointer data) {
    auto* cbd = static_cast<PinCallbackData*>(data);
    libdivecomputer_plugin_dive_computer_flutter_api_on_pin_code_required(
        cbd->flutter_api, cbd->address, nullptr, nullptr, nullptr);
    g_free(cbd->address);
    delete cbd;
    return G_SOURCE_REMOVE;
}

static void on_pin_code_required(const gchar* address, gpointer user_data) {
    auto* ctx = static_cast<HostApiContext*>(user_data);
    auto* cbd = new PinCallbackData();
    cbd->flutter_api = ctx->flutter_api;
    cbd->address = g_strdup(address);
    g_idle_add(pin_callback_idle, cbd);
}

// Helper to send error events from the download thread to the main thread.
struct ErrorCallbackData {
    LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
    gchar* code;
    gchar* message;
};

static gboolean error_callback_idle(gpointer data) {
    auto* cbd = static_cast<ErrorCallbackData*>(data);
    LibdivecomputerPluginDiveComputerError* error =
        libdivecomputer_plugin_dive_computer_error_new(cbd->code, cbd->message);
    libdivecomputer_plugin_dive_computer_flutter_api_on_error(
        cbd->flutter_api, error, nullptr, nullptr, nullptr);
    g_object_unref(error);
    g_free(cbd->code);
    g_free(cbd->message);
    delete cbd;
    return G_SOURCE_REMOVE;
}

static void send_error_from_thread(HostApiContext* ctx,
                                   const gchar* code,
                                   const gchar* message) {
    auto* cbd = new ErrorCallbackData();
    cbd->flutter_api = ctx->flutter_api;
    cbd->code = g_strdup(code);
    cbd->message = g_strdup(message);
    g_idle_add(error_callback_idle, cbd);
}

static gpointer download_thread_func(gpointer data) {
  auto* td = static_cast<DownloadThreadData*>(data);
  HostApiContext* ctx = td->ctx;

  // Create download session. The session holds a dc_context_t (logging) and a
  // cancelled flag. It is intentionally reused across multiple libdc_download_run
  // calls during multi-port probing — each call creates its own internal state.
  ctx->session = libdc_download_session_new();
  if (ctx->session == nullptr) {
    send_error_from_thread(ctx, "session_error",
                           "Failed to create download session");
    download_thread_data_free(td);
    return nullptr;
  }

  // Set up download callbacks.
  libdc_download_callbacks_t dl_callbacks = {0};
  dl_callbacks.on_progress = on_download_progress;
  dl_callbacks.on_dive = on_dive_downloaded;
  dl_callbacks.userdata = ctx;

  unsigned int serial_number = 0;
  unsigned int firmware_version = 0;
  char error_buf[256] = {0};

  // Decode fingerprint from hex string.
  unsigned char* fp_data = NULL;
  unsigned int fp_size = 0;
  if (td->fingerprint != NULL && td->fingerprint[0] != '\0') {
      size_t hex_len = strlen(td->fingerprint);
      fp_size = (unsigned int)(hex_len / 2);
      fp_data = (unsigned char*)g_malloc(fp_size);
      for (unsigned int i = 0; i < fp_size; i++) {
          char byte_str[3] = { td->fingerprint[i*2], td->fingerprint[i*2+1], '\0' };
          fp_data[i] = (unsigned char)strtol(byte_str, NULL, 16);
      }
  }

  // Set up I/O based on transport type.
  libdc_io_callbacks_t io_callbacks = {0};
  unsigned int transport_flag = 0;
  int rc = -1;

  if (td->transport == LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_BLE) {
    transport_flag = LIBDC_TRANSPORT_BLE;

    // Convert BLE address (AA:BB:CC:DD:EE:FF) to D-Bus object path
    // (/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF).
    g_autofree gchar* addr_underscored = g_strdup(td->address);
    for (gchar* p = addr_underscored; *p; p++) {
      if (*p == ':') *p = '_';
    }
    g_autofree gchar* device_path =
        g_strdup_printf("/org/bluez/hci0/dev_%s", addr_underscored);

    ctx->ble_stream = ble_io_stream_new();
    ble_io_stream_set_device_address(ctx->ble_stream, td->address);
    ble_io_stream_set_pin_callback(ctx->ble_stream, on_pin_code_required, ctx);
    if (!ble_io_stream_connect(ctx->ble_stream, device_path)) {
      send_error_from_thread(ctx, "connect_failed",
                             "Failed to connect to BLE device");
      ble_io_stream_free(ctx->ble_stream);
      ctx->ble_stream = nullptr;
      libdc_download_session_free(ctx->session);
      ctx->session = nullptr;
      g_free(fp_data);
      download_thread_data_free(td);
      return nullptr;
    }
    io_callbacks = ble_io_stream_make_callbacks(ctx->ble_stream);

    rc = libdc_download_run(
        ctx->session,
        td->vendor, td->product, td->model,
        transport_flag,
        &io_callbacks,
        fp_data, fp_size,
        &dl_callbacks,
        &serial_number, &firmware_version,
        error_buf, sizeof(error_buf));
  } else {
    // Serial or USB transport.
    transport_flag = LIBDC_TRANSPORT_SERIAL;

    // Build list of candidate ports. If the address is a device path, use it
    // directly. Otherwise (manual model selection), enumerate available ports.
    // We attempt a full download per port because many serial devices are
    // openable but are not the target dive computer.
    gboolean found = FALSE;
    gchar* probe_msg = NULL;
    if (g_str_has_prefix(td->address, "/dev/")) {
      ctx->serial_stream = serial_io_stream_new();
      if (serial_io_stream_open(ctx->serial_stream, td->address)) {
        io_callbacks = serial_io_stream_make_callbacks(ctx->serial_stream);
        rc = libdc_download_run(
            ctx->session,
            td->vendor, td->product, td->model,
            transport_flag,
            &io_callbacks,
            fp_data, fp_size,
            &dl_callbacks,
            &serial_number, &firmware_version,
            error_buf, sizeof(error_buf));
        found = TRUE;
      } else {
        probe_msg = g_strdup_printf(
            "Failed to open serial port %s", td->address);
      }
      serial_io_stream_free(ctx->serial_stream);
      ctx->serial_stream = nullptr;
    } else {
      g_auto(GStrv) ports = serial_enumerate_ports();
      g_autoptr(GString) probe_log = g_string_new(NULL);
      int port_count = 0;
      // Buffer dives during multi-port probing so phantom dives from a
      // wrong port are not dispatched to Flutter.
      ctx->buffer_dives = TRUE;
      if (ports) {
        for (int i = 0; ports[i] != NULL; i++) {
          port_count++;
          clear_buffered_dives(ctx);
          ctx->serial_stream = serial_io_stream_new();
          if (!serial_io_stream_open(ctx->serial_stream, ports[i])) {
            g_string_append_printf(probe_log, "  %s: failed to open\n", ports[i]);
            serial_io_stream_free(ctx->serial_stream);
            ctx->serial_stream = nullptr;
            continue;
          }

          io_callbacks = serial_io_stream_make_callbacks(ctx->serial_stream);
          serial_number = 0;
          firmware_version = 0;
          memset(error_buf, 0, sizeof(error_buf));

          rc = libdc_download_run(
              ctx->session,
              td->vendor, td->product, td->model,
              transport_flag,
              &io_callbacks,
              fp_data, fp_size,
              &dl_callbacks,
              &serial_number, &firmware_version,
              error_buf, sizeof(error_buf));

          serial_io_stream_free(ctx->serial_stream);
          ctx->serial_stream = nullptr;
          found = TRUE;

          if (rc == 0 || rc == LIBDC_STATUS_CANCELLED) {
            break;
          }
          g_string_append_printf(probe_log, "  %s: download failed (rc=%d)\n", ports[i], rc);
        }
      }

      // Flush or discard buffered dives based on result.
      if (rc == 0) {
        flush_buffered_dives(ctx);
      } else {
        clear_buffered_dives(ctx);
      }
      ctx->buffer_dives = FALSE;

      if (!found) {
        if (port_count == 0) {
          send_error_from_thread(ctx, "no_serial_ports",
              "No USB serial ports found. Is the dive computer connected and powered on?");
          libdc_download_session_free(ctx->session);
          ctx->session = nullptr;
          g_free(fp_data);
          download_thread_data_free(td);
          return nullptr;
        } else {
          probe_msg = g_strdup_printf(
              "No dive computer found. Ports tried:\n%s", probe_log->str);
        }
      } else if (rc != 0 && probe_log->len > 0) {
        probe_msg = g_strdup_printf(
            "No dive computer found. Ports tried:\n%s", probe_log->str);
      }
    }

    if (probe_msg != NULL) {
      send_error_from_thread(ctx, "connect_failed", probe_msg);
      g_free(probe_msg);
      libdc_download_session_free(ctx->session);
      ctx->session = nullptr;
      g_free(fp_data);
      download_thread_data_free(td);
      return nullptr;
    }
  }

  g_free(fp_data);

  if (rc != 0) {
    gchar* msg = (error_buf[0] != '\0')
        ? g_strdup(error_buf)
        : g_strdup_printf("Download failed with code %d", rc);
    send_error_from_thread(ctx, "download_error", msg);
    g_free(msg);
  } else {
    // Report completion with device info.
    gchar* serial_str = (serial_number != 0)
        ? g_strdup_printf("%u", serial_number) : nullptr;
    gchar* firmware_str = (firmware_version != 0)
        ? g_strdup_printf("%u", firmware_version) : nullptr;

    struct CompleteData {
        LibdivecomputerPluginDiveComputerFlutterApi* api;
        gchar* serial;
        gchar* firmware;
    };
    auto* cd = new CompleteData{ctx->flutter_api,
                                g_strdup(serial_str), g_strdup(firmware_str)};
    g_idle_add([](gpointer data) -> gboolean {
        auto* d = static_cast<CompleteData*>(data);
        libdivecomputer_plugin_dive_computer_flutter_api_on_download_complete(
            d->api, 0, d->serial, d->firmware,
            nullptr, nullptr, nullptr);
        g_free(d->serial);
        g_free(d->firmware);
        delete d;
        return G_SOURCE_REMOVE;
    }, cd);

    g_free(serial_str);
    g_free(firmware_str);
  }

  // Cleanup transport.
  if (ctx->ble_stream != nullptr) {
    ble_io_stream_free(ctx->ble_stream);
    ctx->ble_stream = nullptr;
  }
  if (ctx->serial_stream != nullptr) {
    serial_io_stream_free(ctx->serial_stream);
    ctx->serial_stream = nullptr;
  }
  libdc_download_session_free(ctx->session);
  ctx->session = nullptr;

  download_thread_data_free(td);
  return nullptr;
}

// --- VTable implementations ---

static void handle_get_device_descriptors(
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  libdc_descriptor_iterator_t* iter = libdc_descriptor_iterator_new();
  if (iter == nullptr) {
    libdivecomputer_plugin_dive_computer_host_api_respond_error_get_device_descriptors(
        response_handle, "internal_error",
        "Failed to create descriptor iterator", nullptr);
    return;
  }

  FlValue* descriptors = fl_value_new_list();
  libdc_descriptor_info_t info;
  int rc;
  while ((rc = libdc_descriptor_iterator_next(iter, &info)) == 0) {
    FlValue* transports = transports_to_fl_value(info.transports);
    LibdivecomputerPluginDeviceDescriptor* desc =
        libdivecomputer_plugin_device_descriptor_new(
            info.vendor, info.product,
            static_cast<int64_t>(info.model), transports);
    fl_value_unref(transports);
    fl_value_append_take(descriptors,
                         fl_value_new_custom_object(130, G_OBJECT(desc)));
    g_object_unref(desc);
  }
  libdc_descriptor_iterator_free(iter);

  libdivecomputer_plugin_dive_computer_host_api_respond_get_device_descriptors(
      response_handle, descriptors);
  fl_value_unref(descriptors);
}

static void handle_start_discovery(
    LibdivecomputerPluginTransportType transport,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);

  switch (transport) {
    case LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_BLE: {
      // Clean up any previous scanner.
      if (ctx->ble_scanner != nullptr) {
        ble_scanner_free(ctx->ble_scanner);
      }
      ctx->ble_scanner = ble_scanner_new();
      ble_scanner_set_callbacks(ctx->ble_scanner,
                                on_ble_device_discovered,
                                on_ble_scan_complete,
                                ctx);
      if (!ble_scanner_start(ctx->ble_scanner)) {
        libdivecomputer_plugin_dive_computer_host_api_respond_error_start_discovery(
            response_handle, "ble_error",
            "Failed to start BLE discovery", nullptr);
        return;
      }
      libdivecomputer_plugin_dive_computer_host_api_respond_start_discovery(
          response_handle);
      break;
    }

    case LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_SERIAL:
    case LIBDIVECOMPUTER_PLUGIN_TRANSPORT_TYPE_USB: {
      // Clean up any previous scanner.
      if (ctx->serial_scanner != nullptr) {
        serial_scanner_free(ctx->serial_scanner);
      }
      ctx->serial_scanner = serial_scanner_new();
      serial_scanner_set_callbacks(ctx->serial_scanner,
                                   on_serial_device_discovered,
                                   on_serial_scan_complete,
                                   ctx);
      serial_scanner_start(ctx->serial_scanner);
      libdivecomputer_plugin_dive_computer_host_api_respond_start_discovery(
          response_handle);
      break;
    }

    default:
      libdivecomputer_plugin_dive_computer_host_api_respond_error_start_discovery(
          response_handle, "unsupported_transport",
          "Transport not supported on Linux", nullptr);
      break;
  }
}

static LibdivecomputerPluginDiveComputerHostApiStopDiscoveryResponse*
handle_stop_discovery(gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);

  if (ctx->ble_scanner != nullptr) {
    ble_scanner_stop(ctx->ble_scanner);
    ble_scanner_free(ctx->ble_scanner);
    ctx->ble_scanner = nullptr;
  }
  if (ctx->serial_scanner != nullptr) {
    serial_scanner_stop(ctx->serial_scanner);
    serial_scanner_free(ctx->serial_scanner);
    ctx->serial_scanner = nullptr;
  }

  return libdivecomputer_plugin_dive_computer_host_api_stop_discovery_response_new();
}

static void handle_start_download(
    LibdivecomputerPluginDiscoveredDevice* device,
    const gchar* fingerprint,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);

  // Acknowledge start immediately.
  libdivecomputer_plugin_dive_computer_host_api_respond_start_download(
      response_handle);

  // Build thread data from the discovered device.
  auto* td = new DownloadThreadData();
  td->ctx = ctx;
  td->vendor = g_strdup(
      libdivecomputer_plugin_discovered_device_get_vendor(device));
  td->product = g_strdup(
      libdivecomputer_plugin_discovered_device_get_product(device));
  td->model = static_cast<guint32>(
      libdivecomputer_plugin_discovered_device_get_model(device));
  td->address = g_strdup(
      libdivecomputer_plugin_discovered_device_get_address(device));
  td->transport =
      libdivecomputer_plugin_discovered_device_get_transport(device);
  td->fingerprint = (fingerprint != NULL) ? g_strdup(fingerprint) : NULL;

  // Spawn download thread.
  ctx->download_thread = g_thread_new("dc-download", download_thread_func, td);
}

static LibdivecomputerPluginDiveComputerHostApiCancelDownloadResponse*
handle_cancel_download(gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);

  if (ctx->session != nullptr) {
    libdc_download_cancel(ctx->session);
  }

  return libdivecomputer_plugin_dive_computer_host_api_cancel_download_response_new();
}

static LibdivecomputerPluginDiveComputerHostApiSubmitPinCodeResponse*
handle_submit_pin_code(
    const gchar* pin_code,
    gpointer user_data) {
  auto* ctx = static_cast<HostApiContext*>(user_data);
  if (ctx->ble_stream != nullptr) {
    ble_io_stream_submit_pin(ctx->ble_stream, pin_code);
  }
  return libdivecomputer_plugin_dive_computer_host_api_submit_pin_code_response_new();
}

static LibdivecomputerPluginDiveComputerHostApiGetLibdivecomputerVersionResponse*
handle_get_libdivecomputer_version(gpointer user_data) {
  const char* version = libdc_get_version();
  return libdivecomputer_plugin_dive_computer_host_api_get_libdivecomputer_version_response_new(
      version);
}

// --- Public registration ---

void dive_computer_host_api_impl_register(FlBinaryMessenger* messenger) {
  auto* ctx = new HostApiContext();
  ctx->messenger = messenger;
  ctx->flutter_api =
      libdivecomputer_plugin_dive_computer_flutter_api_new(messenger, nullptr);
  ctx->ble_scanner = nullptr;
  ctx->serial_scanner = nullptr;
  ctx->ble_stream = nullptr;
  ctx->serial_stream = nullptr;
  ctx->session = nullptr;
  ctx->download_thread = nullptr;

  static const LibdivecomputerPluginDiveComputerHostApiVTable vtable = {
      .get_device_descriptors = handle_get_device_descriptors,
      .start_discovery = handle_start_discovery,
      .stop_discovery = handle_stop_discovery,
      .start_download = handle_start_download,
      .cancel_download = handle_cancel_download,
      .submit_pin_code = handle_submit_pin_code,
      .get_libdivecomputer_version = handle_get_libdivecomputer_version,
  };

  libdivecomputer_plugin_dive_computer_host_api_set_method_handlers(
      messenger, nullptr, &vtable, ctx, host_api_context_free);
}
