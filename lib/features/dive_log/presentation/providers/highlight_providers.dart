import 'package:submersion/core/providers/provider.dart';

/// Currently highlighted dive ID in the list view.
///
/// Set on single-tap, cleared when entering bulk selection mode.
/// Watched by [DiveProfilePanel] to auto-update the chart preview.
final highlightedDiveIdProvider = StateProvider<String?>((ref) => null);

/// Whether the profile chart preview panel is visible above the dive list.
///
/// Defaults to true. Initialized from persisted settings in
/// [_DiveListContentState.initState] via [initProfilePanelFromSettings].
/// Can be toggled at runtime via the toolbar button.
final showProfilePanelProvider = StateProvider<bool>((ref) => true);
