#include "include/submersion_ocr/submersion_ocr_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "submersion_ocr_plugin.h"

void SubmersionOcrPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  submersion_ocr::SubmersionOcrPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
