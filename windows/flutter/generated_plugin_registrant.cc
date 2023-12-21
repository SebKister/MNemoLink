//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <disks_desktop/disks_desktop_plugin.h>
#include <flutter_libserialport/flutter_libserialport_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  DisksDesktopPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DisksDesktopPlugin"));
  FlutterLibserialportPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterLibserialportPlugin"));
}
