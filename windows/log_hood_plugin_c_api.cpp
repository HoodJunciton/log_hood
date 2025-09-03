#include "include/log_hood/log_hood_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "log_hood_plugin.h"

void LogHoodPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  log_hood::LogHoodPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
