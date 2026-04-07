import 'package:submersion/core/providers/provider.dart';

/// Per-section toggle for showing the details pane in table mode.
/// Keyed by section name (e.g., 'dives', 'sites', 'buddies').
/// Defaults to false (details pane hidden). Initialized from persisted
/// settings in each section's list page initState.
final tableDetailsPaneProvider = StateProvider.family<bool, String>(
  (ref, sectionKey) => false,
);
