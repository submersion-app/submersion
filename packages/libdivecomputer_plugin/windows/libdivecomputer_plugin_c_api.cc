#include "include/libdivecomputer_plugin/libdivecomputer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dive_computer_api.g.h"
#include "dive_computer_host_api_impl.h"

void LibdivecomputerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* plugin_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);

  auto host_api =
      std::make_unique<libdivecomputer_plugin::DiveComputerHostApiImpl>(
          plugin_registrar->messenger());

  libdivecomputer_plugin::DiveComputerHostApi::SetUp(
      plugin_registrar->messenger(), host_api.get());

  // Transfer ownership. The registrar will clean up on shutdown.
  plugin_registrar->AddPlugin(std::move(host_api));
}
