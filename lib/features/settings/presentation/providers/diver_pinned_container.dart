import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Runs [body] in a throwaway container whose settings are [diverId]'s, so
/// work keyed on "the diver's settings" (the dive analysis, its gradient
/// factors and thresholds) runs as it would with that diver active, without
/// switching the app's diver. The container carries the app's root
/// overrides and is disposed when [body] completes.
///
/// A null [diverId] leaves the settings to the container's own load, which
/// resolves the active (or default) diver's.
///
/// Read-only on purpose: getOrCreateSettingsForDiver WRITES a defaults row
/// when none exists, and this must not mint rows (they would sync out as
/// real edits). A diver with no settings row falls back to the defaults the
/// app itself would show them.
Future<T> runInDiverContainer<T>(
  Ref ref, {
  required String? diverId,
  required DiverSettingsRepository settingsRepository,
  required Future<T> Function(ProviderContainer container) body,
}) async {
  final overrides = rootProviderOverrides(
    prefs: ref.read(sharedPreferencesProvider),
    logFileService: ref.read(logFileServiceProvider),
  );
  if (diverId != null) {
    final settings =
        await settingsRepository.getSettingsForDiver(diverId) ??
        const AppSettings();
    overrides.add(
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier.preloaded(
          settingsRepository,
          ref,
          settings: settings,
          diverId: diverId,
        ),
      ),
    );
  }

  final container = ProviderContainer(overrides: overrides.cast());
  try {
    // For an unpinned container this awaits the real async load of the
    // active diver's settings (state starts at the AppSettings DEFAULTS
    // until it completes). For a pinned one it is already complete. A failed
    // load is not fatal: the work then runs on the defaults, as everywhere
    // else.
    try {
      await container.read(settingsProvider.notifier).initialLoad;
    } catch (_) {
      // Intentionally ignored; see above.
    }
    return await body(container);
  } finally {
    container.dispose();
  }
}
