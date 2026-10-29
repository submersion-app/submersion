import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Where a sealed screen sends the user while demo mode is on.
const demoUnavailableLocation = '/demo-unavailable';

/// Screens demo mode seals, by the route that opens them (a `:param`
/// segment matches any value). A location under one of these routes opens
/// the "unavailable in demo mode" page instead, so the feature stays visible
/// and says why it cannot be used. The engine refuses the work as well; this
/// is the explanation, not the seal.
const demoSealedRoutePrefixes = <String, DemoSealedFeature>{
  '/transfer': DemoSealedFeature.fileImport,
  '/dives/scan': DemoSealedFeature.fileImport,
  '/sites/import': DemoSealedFeature.fileImport,
  '/dive-centers/import': DemoSealedFeature.fileImport,
  '/dive-computers/discover': DemoSealedFeature.diveComputerDownload,
  '/dive-computers/:computerId/download':
      DemoSealedFeature.diveComputerDownload,
  '/settings/backup': DemoSealedFeature.backup,
  '/settings/cloud-sync': DemoSealedFeature.sync,
  '/settings/connected-accounts': DemoSealedFeature.sync,
  '/settings/shared-libraries': DemoSealedFeature.sharedLibrary,
  '/settings/storage': DemoSealedFeature.databaseFile,
  '/settings/setup-assistant': DemoSealedFeature.databaseFile,
  '/settings/setup': DemoSealedFeature.databaseFile,
  '/settings/wearable-import': DemoSealedFeature.cloudImport,
  '/settings/photos-media': DemoSealedFeature.mediaImport,
  '/settings/media-storage': DemoSealedFeature.mediaImport,
  '/settings/lightroom': DemoSealedFeature.mediaImport,
};

/// The feature [location] belongs to when it is sealed in demo mode, or null.
DemoSealedFeature? demoSealedFeatureFor(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  for (final MapEntry(key: route, value: feature)
      in demoSealedRoutePrefixes.entries) {
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

/// The router redirect for demo mode: a sealed location goes to the
/// unavailable page while demo mode is on, and nothing changes otherwise.
String? demoRedirect(String location) {
  if (!DemoModeGate.instance.isActive) return null;
  final feature = demoSealedFeatureFor(location);
  if (feature == null) return null;
  return '$demoUnavailableLocation?feature=${feature.name}';
}
