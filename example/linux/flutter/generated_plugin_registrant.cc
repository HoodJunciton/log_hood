//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <log_hood/log_hood_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) log_hood_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "LogHoodPlugin");
  log_hood_plugin_register_with_registrar(log_hood_registrar);
}
