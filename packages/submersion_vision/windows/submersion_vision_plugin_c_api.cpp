#include "include/submersion_vision/submersion_vision_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "submersion_vision_plugin.h"

void SubmersionVisionPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  submersion_vision::SubmersionVisionPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
