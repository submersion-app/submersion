import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Currently highlighted dive ID in the list view.
///
/// Set on single-tap, cleared when entering bulk selection mode.
/// Watched by [DiveProfilePanel] to auto-update the chart preview.
final highlightedDiveIdProvider = StateProvider<String?>((ref) => null);

/// Whether the profile chart preview panel is visible above the dive list.
///
/// Initialized from [AppSettings.showProfilePanelInTableView] on first use.
/// Can be toggled at runtime via the toolbar button.
final showProfilePanelProvider = StateProvider<bool>((ref) => true);

/// Tracks whether [showProfilePanelProvider] has been initialized from
/// persisted settings yet. Prevents re-initialization on rebuilds.
final _profilePanelInitializedProvider = StateProvider<bool>((ref) => false);

/// Initialize [showProfilePanelProvider] from the persisted setting,
/// but only once per session. Safe to call on every build.
void initProfilePanelFromSettings(WidgetRef ref) {
  if (ref.read(_profilePanelInitializedProvider)) return;
  ref.read(_profilePanelInitializedProvider.notifier).state = true;

  final settings = ref.read(settingsProvider);
  ref.read(showProfilePanelProvider.notifier).state =
      settings.showProfilePanelInTableView;
}
