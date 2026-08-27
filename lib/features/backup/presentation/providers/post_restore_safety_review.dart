import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// One sweep pass: the dives owned by [diverId], graded with that diver's
/// settings. A null [diverId] is the leftover set of dives with no owner.
typedef _SweepPass = ({String? diverId, List<String> diveIds});

/// Runs the whole-library safety sweep that follows a database restore.
///
/// Two things make this more than a loop over every dive.
///
/// 1. It runs in short-lived [ProviderContainer]s, not the live one. After a
///    restore the live container still holds values built against the REPLACED
///    database -- settingsProvider (and so the gradient factors that shape the
///    ceiling curve the missedDecoStop and highSurfaceGf rules grade against),
///    ProfileLegend's metric-source defaults, and cached
///    analysisDiveProvider/profileAnalysisProvider entries. Computing findings
///    from that state would persist the old device's settings into the restored
///    library, and because saveReview stamps the current engineVersion they
///    would never be recomputed.
///
/// 2. It sweeps ONE DIVER AT A TIME, each in a container whose settingsProvider
///    is pinned to that diver. Decompression settings are per-diver
///    (`diver_settings.gf_low` / `gf_high`, ppO2 ceilings, deco stop
///    increment), and `computeAnalysisForProfile` falls back to
///    gfLowProvider/gfHighProvider whenever a dive carries no dive-specific
///    GFs. A single all-divers pass would therefore grade every non-active
///    diver's dives with the ACTIVE diver's gradient factors and persist the
///    result -- stamped current, so never corrected.
///
/// The live container is left untouched; restartApp() rebuilds the root
/// ProviderScope under a new key moments later and discards it anyway.
class PostRestoreSafetyReview {
  final Ref _ref;

  const PostRestoreSafetyReview(this._ref);

  Future<SafetyReviewSweepResult> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final diveRepo = _ref.read(diveRepositoryProvider);
    final allIds = await diveRepo.getOrderedDiveIds(
      sort: SafetyReviewSweep.oldestFirstSort,
    );
    final total = allIds.length;
    onProgress?.call(0, total);
    if (total == 0) return SafetyReviewSweepResult.empty;

    final passes = await _buildPasses(allIds);
    final settingsRepo = _ref.read(diverSettingsRepositoryProvider);

    var swept = 0;
    var failed = 0;
    for (final pass in passes) {
      if (isCancelled?.call() ?? false) {
        return SafetyReviewSweepResult(
          swept: swept,
          failed: failed,
          cancelled: true,
        );
      }
      // Progress is reported across the whole library, not per pass, so the
      // barrier's bar advances once from 0 to N rather than restarting per
      // diver.
      final base = swept;
      final result = await _runPass(
        pass,
        settingsRepo,
        onProgress: (done, _) => onProgress?.call(base + done, total),
        isCancelled: isCancelled,
      );
      swept += result.swept;
      failed += result.failed;
      if (result.cancelled) {
        return SafetyReviewSweepResult(
          swept: swept,
          failed: failed,
          cancelled: true,
        );
      }
    }

    return SafetyReviewSweepResult(
      swept: swept,
      failed: failed,
      cancelled: false,
    );
  }

  /// Groups [allIds] by owning diver, plus a trailing pass for dives whose
  /// `diver_id` is null (the column is nullable; pre-multi-diver rows have no
  /// owner). Divers with no dives are skipped so no empty container is built.
  Future<List<_SweepPass>> _buildPasses(List<String> allIds) async {
    final diveRepo = _ref.read(diveRepositoryProvider);
    final divers = await _ref.read(diverRepositoryProvider).getAllDivers();

    final passes = <_SweepPass>[];
    final owned = <String>{};
    for (final diver in divers) {
      final ids = await diveRepo.getOrderedDiveIds(
        diverId: diver.id,
        sort: SafetyReviewSweep.oldestFirstSort,
      );
      if (ids.isEmpty) continue;
      owned.addAll(ids);
      passes.add((diverId: diver.id, diveIds: ids));
    }

    final unowned = allIds.where((id) => !owned.contains(id)).toList();
    if (unowned.isNotEmpty) {
      passes.add((diverId: null, diveIds: unowned));
    }
    return passes;
  }

  Future<SafetyReviewSweepResult> _runPass(
    _SweepPass pass,
    DiverSettingsRepository settingsRepo, {
    required void Function(int done, int total) onProgress,
    bool Function()? isCancelled,
  }) async {
    final overrides = rootProviderOverrides(
      prefs: _ref.read(sharedPreferencesProvider),
      logFileService: _ref.read(logFileServiceProvider),
    );

    final diverId = pass.diverId;
    if (diverId != null) {
      // Read-only on purpose: getOrCreateSettingsForDiver WRITES a defaults row
      // when none exists, and a restore must not mint rows (they would sync out
      // as real edits). A diver with no settings row falls back to the same
      // defaults the app itself would show them.
      final settings =
          await settingsRepo.getSettingsForDiver(diverId) ??
          const AppSettings();
      overrides.add(
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier.preloaded(
            settingsRepo,
            ref,
            settings: settings,
            diverId: diverId,
          ),
        ),
      );
    }

    final container = ProviderContainer(overrides: overrides.cast());
    try {
      // For an owner-less pass this awaits the real async load of the active
      // diver's settings (state starts at the AppSettings DEFAULTS until it
      // completes). For a pinned pass it is already complete. A failed load is
      // not fatal -- the sweep then runs on the defaults, as everywhere else.
      try {
        await container.read(settingsProvider.notifier).initialLoad;
      } catch (_) {
        // Intentionally ignored; see above.
      }
      return await container
          .read(safetyReviewSweepProvider)
          .run(
            diveIds: pass.diveIds,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
    } finally {
      container.dispose();
    }
  }
}

final postRestoreSafetyReviewProvider = Provider<PostRestoreSafetyReview>(
  (ref) => PostRestoreSafetyReview(ref),
);
