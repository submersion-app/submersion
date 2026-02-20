#include "include/libdivecomputer_plugin/libdivecomputer_plugin.h"

#include <flutter_linux/flutter_linux.h>

#include "dive_computer_host_api_impl.h"

void libdivecomputer_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlBinaryMessenger* messenger =
      fl_plugin_registrar_get_messenger(registrar);

  dive_computer_host_api_impl_register(messenger);
}
