#include "dive_computer_host_api_impl.h"

extern "C" {
#include "ble_io_stream.h"
#include "ble_scanner.h"
#include "dive_converter.h"
#include "libdc_download.h"
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
  LibdivecomputerPluginTransportType transport;
};

static void download_thread_data_free(DownloadThreadData* data) {
  g_free(data->vendor);
  g_free(data->product);
  g_free(data->address);
  delete data;
}

static void on_download_progress(unsigned int current, unsigned int maximum,
                                 void* userdata) {
  auto* ctx = static_cast<HostApiContext*>(userdata);
  LibdivecomputerPluginDownloadProgress* progress =
      libdivecomputer_plugin_download_progress_new(
          (int64_t)current, (int64_t)maximum, "downloading");
  libdivecomputer_plugin_dive_computer_flutter_api_on_download_progress(
      ctx->flutter_api, progress, nullptr, nullptr, nullptr);
  g_object_unref(progress);
}

static void on_dive_downloaded(const libdc_parsed_dive_t* dive,
                               void* userdata) {
  auto* ctx = static_cast<HostApiContext*>(userdata);
  LibdivecomputerPluginParsedDive* parsed = convert_parsed_dive(dive);
  if (parsed != nullptr) {
    libdivecomputer_plugin_dive_computer_flutter_api_on_dive_downloaded(
        ctx->flutter_api, parsed, nullptr, nullptr, nullptr);
    g_object_unref(parsed);
  }
}

static gpointer download_thread_func(gpointer data) {
  auto* td = static_cast<DownloadThreadData*>(data);
  HostApiContext* ctx = td->ctx;

  // Create download session.
  ctx->session = libdc_download_session_new();
  if (ctx->session == nullptr) {
    LibdivecomputerPluginDiveComputerError* error =
        libdivecomputer_plugin_dive_computer_error_new(
            "session_error", "Failed to create download session");
    libdivecomputer_plugin_dive_computer_flutter_api_on_error(
        ctx->flutter_api, error, nullptr, nullptr, nullptr);
    g_object_unref(error);
    download_thread_data_free(td);
    return nullptr;
  }

  // Set up I/O based on transport type.
  libdc_io_callbacks_t io_callbacks = {0};
  unsigned int transport_flag = 0;

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
    if (!ble_io_stream_connect(ctx->ble_stream, device_path)) {
      LibdivecomputerPluginDiveComputerError* error =
          libdivecomputer_plugin_dive_computer_error_new(
              "connect_failed", "Failed to connect to BLE device");
      libdivecomputer_plugin_dive_computer_flutter_api_on_error(
          ctx->flutter_api, error, nullptr, nullptr, nullptr);
      g_object_unref(error);
      ble_io_stream_free(ctx->ble_stream);
      ctx->ble_stream = nullptr;
      libdc_download_session_free(ctx->session);
      ctx->session = nullptr;
      download_thread_data_free(td);
      return nullptr;
    }
    io_callbacks = ble_io_stream_make_callbacks(ctx->ble_stream);
  } else {
    // Serial or USB transport.
    transport_flag = LIBDC_TRANSPORT_SERIAL;
    ctx->serial_stream = serial_io_stream_new();
    if (!serial_io_stream_open(ctx->serial_stream, td->address)) {
      LibdivecomputerPluginDiveComputerError* error =
          libdivecomputer_plugin_dive_computer_error_new(
              "connect_failed", "Failed to open serial port");
      libdivecomputer_plugin_dive_computer_flutter_api_on_error(
          ctx->flutter_api, error, nullptr, nullptr, nullptr);
      g_object_unref(error);
      serial_io_stream_free(ctx->serial_stream);
      ctx->serial_stream = nullptr;
      libdc_download_session_free(ctx->session);
      ctx->session = nullptr;
      download_thread_data_free(td);
      return nullptr;
    }
    io_callbacks = serial_io_stream_make_callbacks(ctx->serial_stream);
  }

  // Set up download callbacks.
  libdc_download_callbacks_t dl_callbacks = {0};
  dl_callbacks.on_progress = on_download_progress;
  dl_callbacks.on_dive = on_dive_downloaded;
  dl_callbacks.userdata = ctx;

  unsigned int serial_number = 0;
  unsigned int firmware_version = 0;
  char error_buf[256] = {0};

  int rc = libdc_download_run(
      ctx->session,
      td->vendor, td->product, td->model,
      transport_flag,
      &io_callbacks,
      nullptr, 0,  // fingerprint (none for full download)
      &dl_callbacks,
      &serial_number, &firmware_version,
      error_buf, sizeof(error_buf));

  if (rc != 0) {
    gchar* msg = (error_buf[0] != '\0')
        ? g_strdup(error_buf)
        : g_strdup_printf("Download failed with code %d", rc);
    LibdivecomputerPluginDiveComputerError* error =
        libdivecomputer_plugin_dive_computer_error_new("download_error", msg);
    libdivecomputer_plugin_dive_computer_flutter_api_on_error(
        ctx->flutter_api, error, nullptr, nullptr, nullptr);
    g_object_unref(error);
    g_free(msg);
  } else {
    // Report completion with device info.
    gchar* serial_str = (serial_number != 0)
        ? g_strdup_printf("%u", serial_number) : nullptr;
    gchar* firmware_str = (firmware_version != 0)
        ? g_strdup_printf("%u", firmware_version) : nullptr;

    libdivecomputer_plugin_dive_computer_flutter_api_on_download_complete(
        ctx->flutter_api, 0, serial_str, firmware_str,
        nullptr, nullptr, nullptr);

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
      .get_libdivecomputer_version = handle_get_libdivecomputer_version,
  };

  libdivecomputer_plugin_dive_computer_host_api_set_method_handlers(
      messenger, nullptr, &vtable, ctx, host_api_context_free);
}
