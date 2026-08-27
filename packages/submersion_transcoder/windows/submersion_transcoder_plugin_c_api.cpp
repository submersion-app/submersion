#include "include/submersion_transcoder/submersion_transcoder_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "submersion_transcoder_plugin.h"

void SubmersionTranscoderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  submersion_transcoder::SubmersionTranscoderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
