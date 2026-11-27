import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_client.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The provider overrides of a profile pop-out window's root (issue #5078).
///
/// The app's own root overrides, plus what keeps the pop-out a viewer that
/// writes nothing: settings and the active diver read without writing, and
/// safety reviews shown as stored instead of recomputed and saved. Returns
/// `List<dynamic>` for the same reason as [rootProviderOverrides].
List<dynamic> popOutProviderOverrides({
  required SharedPreferences prefs,
  required LogFileService logFileService,
  required PopOutChannel channel,
  required PopOutLaunch launch,
}) {
  return [
    ...rootProviderOverrides(prefs: prefs, logFileService: logFileService),
    popOutLaunchProvider.overrideWithValue(launch),
    popOutChannelProvider.overrideWithValue(channel),
    // A pop-out opens no pop-outs of its own.
    popOutAvailableProvider.overrideWithValue(false),
    currentDiverIdProvider.overrideWith(
      (ref) => CurrentDiverIdNotifier.readOnly(
        ref.watch(sharedPreferencesProvider),
        ref.watch(diverRepositoryProvider),
      ),
    ),
    settingsProvider.overrideWith(
      (ref) => SettingsNotifier.readOnly(
        ref.watch(diverSettingsRepositoryProvider),
        ref,
      ),
    ),
    // The main window computes and saves reviews; this one shows them.
    safetyReviewProvider.overrideWith((ref, diveId) async {
      retainDiveData(ref);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return ref.watch(safetyFindingsRepositoryProvider).getReview(diveId);
    }),
  ];
}
