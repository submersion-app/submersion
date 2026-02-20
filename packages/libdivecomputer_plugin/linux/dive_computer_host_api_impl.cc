#include "dive_computer_host_api_impl.h"

#include <cmath>
#include <cstdio>
#include <cstring>

extern "C" {
#include "libdc_wrapper.h"
}

// Context passed as user_data through the VTable.
struct HostApiContext {
  FlBinaryMessenger* messenger;
  LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
};

static void host_api_context_free(gpointer data) {
  auto* ctx = static_cast<HostApiContext*>(data);
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

// Converts a fingerprint byte array to a hex string.
static gchar* fingerprint_to_hex(const unsigned char* fp, unsigned int size) {
  if (size == 0) {
    return g_strdup("");
  }
  gchar* hex = static_cast<gchar*>(g_malloc(size * 2 + 1));
  for (unsigned int i = 0; i < size; i++) {
    snprintf(hex + i * 2, 3, "%02x", fp[i]);
  }
  return hex;
}

// Returns a human-readable dive mode string.
static const char* dive_mode_string(unsigned int mode) {
  switch (mode) {
    case 0:
      return "freedive";
    case 1:
      return "gauge";
    case 2:
      return "opencircuit";
    case 3:
      return "closedcircuit";
    case 4:
      return "semiclosedcircuit";
    default:
      return nullptr;
  }
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
                         fl_value_new_custom_object(G_OBJECT(desc)));
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
  // Linux BLE discovery requires BlueZ D-Bus integration.
  // This is stubbed for now - will be implemented when a Linux build
  // environment is available.
  libdivecomputer_plugin_dive_computer_host_api_respond_error_start_discovery(
      response_handle, "not_implemented",
      "BLE discovery is not yet implemented on Linux", nullptr);
}

static LibdivecomputerPluginDiveComputerHostApiStopDiscoveryResponse*
handle_stop_discovery(gpointer user_data) {
  return libdivecomputer_plugin_dive_computer_host_api_stop_discovery_response_new();
}

static void handle_start_download(
    LibdivecomputerPluginDiscoveredDevice* device,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  // Linux download requires BlueZ BLE I/O or serial transport.
  // This is stubbed for now.
  libdivecomputer_plugin_dive_computer_host_api_respond_error_start_download(
      response_handle, "not_implemented",
      "Download is not yet implemented on Linux", nullptr);
}

static LibdivecomputerPluginDiveComputerHostApiCancelDownloadResponse*
handle_cancel_download(gpointer user_data) {
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
