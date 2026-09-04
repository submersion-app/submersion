import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Progress of the bulk location-details backfill (issue #1187).
sealed class BackfillState {
  const BackfillState();
}

class BackfillIdle extends BackfillState {
  const BackfillIdle();
}

class BackfillRunning extends BackfillState {
  const BackfillRunning({
    required this.mode,
    required this.done,
    required this.total,
  });

  /// Carried on the state, not passed to the dialog, so a progress dialog
  /// reopened from the other menu entry still describes the run underway.
  final SiteLocationLookupMode mode;
  final int done;
  final int total;
}

class BackfillFinished extends BackfillState {
  const BackfillFinished(this.summary);
  final BackfillSummary summary;
}

/// Owns one backfill run at a time so the progress dialog can be rebuilt,
/// dismissed and reopened without losing the run.
class SiteLocationBackfillNotifier extends StateNotifier<BackfillState> {
  SiteLocationBackfillNotifier(this._ref) : super(const BackfillIdle());

  final Ref _ref;
  bool _cancelRequested = false;

  SiteLocationBackfillService _service(SiteLocationLookupMode mode) =>
      SiteLocationBackfillService(
        sites: _ref.read(siteRepositoryProvider),
        location: _ref.read(locationServiceProvider),
        languageCode: _ref.read(placeNameLanguageProvider),
        mode: mode,
      );

  Future<String?> _diverId() =>
      _ref.read(validatedCurrentDiverIdProvider.future);

  /// How many sites a run in [mode] would look up.
  Future<int> countCandidates(SiteLocationLookupMode mode) async =>
      (await _service(mode).candidates(diverId: await _diverId())).length;

  /// Starts a run unless one is already running.
  Future<void> start(SiteLocationLookupMode mode) async {
    if (state is BackfillRunning) return;
    _cancelRequested = false;
    state = BackfillRunning(mode: mode, done: 0, total: 0);
    final summary = await _service(mode).run(
      diverId: await _diverId(),
      onProgress: (done, total) {
        if (mounted) {
          state = BackfillRunning(mode: mode, done: done, total: total);
        }
      },
      isCancelled: () => _cancelRequested,
    );
    if (!mounted) return;
    state = BackfillFinished(summary);
    if (summary.updated > 0) {
      await _ref.read(siteListNotifierProvider.notifier).refresh();
    }
  }

  void cancel() => _cancelRequested = true;

  void reset() => state = const BackfillIdle();
}

final siteLocationBackfillProvider =
    StateNotifierProvider<SiteLocationBackfillNotifier, BackfillState>(
      (ref) => SiteLocationBackfillNotifier(ref),
    );
