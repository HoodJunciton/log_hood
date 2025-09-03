#ifndef FLUTTER_PLUGIN_LOG_HOOD_PLUGIN_H_
#define FLUTTER_PLUGIN_LOG_HOOD_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace log_hood {

class LogHoodPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  LogHoodPlugin();

  virtual ~LogHoodPlugin();

  // Disallow copy and assign.
  LogHoodPlugin(const LogHoodPlugin&) = delete;
  LogHoodPlugin& operator=(const LogHoodPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace log_hood

#endif  // FLUTTER_PLUGIN_LOG_HOOD_PLUGIN_H_
