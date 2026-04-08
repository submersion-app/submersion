import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Per-section toggle for showing the details pane in table mode.
/// Keyed by section name (e.g., 'dives', 'sites', 'buddies').
/// Initializes from the persisted per-section setting in [AppSettings].
final tableDetailsPaneProvider = StateProvider.family<bool, String>((
  ref,
  sectionKey,
) {
  final settings = ref.read(settingsProvider);
  return switch (sectionKey) {
    'dives' => settings.showDetailsPaneDives,
    'sites' => settings.showDetailsPaneSites,
    'buddies' => settings.showDetailsPaneBuddies,
    'trips' => settings.showDetailsPaneTrips,
    'equipment' => settings.showDetailsPaneEquipment,
    'diveCenters' => settings.showDetailsPaneDiveCenters,
    'certifications' => settings.showDetailsPaneCertifications,
    'courses' => settings.showDetailsPaneCourses,
    _ => false,
  };
});
