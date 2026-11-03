import 'package:submersion/core/platform/device_capabilities.dart';

/// Where a browser sends the user for a screen it cannot serve.
const String webUnavailableLocation = '/unavailable-in-browser';

/// Why a feature is missing in a browser, which is what the page explains.
enum WebUnavailableReason { hardware, background, files, icloud, git }

/// Features whose screens a browser cannot serve, each with its reason.
enum WebUnavailableFeature {
  diveComputers(WebUnavailableReason.hardware),
  paperScan(WebUnavailableReason.hardware),
  wearableImport(WebUnavailableReason.hardware),
  nearby(WebUnavailableReason.hardware),
  offlineMaps(WebUnavailableReason.files),
  agentAccess(WebUnavailableReason.background);

  const WebUnavailableFeature(this.reason);

  final WebUnavailableReason reason;
}

/// Screens a browser cannot serve, by the route that opens them (a `:param`
/// segment matches any value). A location under one of these routes opens
/// the "not available in a browser" page instead, so a bookmark or a deep
/// link says why rather than failing on a missing plugin.
const webUnavailableRoutePrefixes = <String, WebUnavailableFeature>{
  '/dive-computers': WebUnavailableFeature.diveComputers,
  '/dives/scan': WebUnavailableFeature.paperScan,
  '/settings/wearable-import': WebUnavailableFeature.wearableImport,
  '/settings/cloud-sync/nearby-pair': WebUnavailableFeature.nearby,
  '/buddies/swap': WebUnavailableFeature.nearby,
  '/settings/offline-maps': WebUnavailableFeature.offlineMaps,
  '/settings/agent-access': WebUnavailableFeature.agentAccess,
};

/// Sections a browser cannot serve on a page it can, by the page's route and
/// the `?selected=` value that opens each one. The page's own list leaves
/// them out; this covers a bookmark or a typed link to one.
const webUnavailableSections = <String, Map<String, WebUnavailableFeature>>{
  // The section's auto-connect starts a Bluetooth scan as it opens.
  '/transfer': {'computers': WebUnavailableFeature.diveComputers},
};

/// The feature [location] belongs to when a browser cannot serve it, or null.
WebUnavailableFeature? webUnavailableFeatureFor(String location) {
  final uri = Uri.tryParse(location);
  final path = uri?.path ?? location;
  final section = uri?.queryParameters['selected'];
  if (section != null) {
    final feature = webUnavailableSections[path]?[section];
    if (feature != null) return feature;
  }
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  for (final MapEntry(key: route, value: feature)
      in webUnavailableRoutePrefixes.entries) {
    final parts = route.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length > segments.length) continue;
    var matches = true;
    for (var i = 0; i < parts.length; i++) {
      if (!parts[i].startsWith(':') && parts[i] != segments[i]) {
        matches = false;
        break;
      }
    }
    if (matches) return feature;
  }
  return null;
}

/// The router redirect for the browser: a location the browser cannot serve
/// goes to the unavailable page; anywhere else, and on a native build,
/// nothing changes.
String? webUnavailableRedirect(DeviceCapabilities caps, String location) {
  if (!caps.isBrowser) return null;
  final feature = webUnavailableFeatureFor(location);
  if (feature == null) return null;
  return '$webUnavailableLocation?feature=${feature.name}';
}
