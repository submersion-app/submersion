import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/insights/data/repositories/deco_classification_cache.dart';

/// Fingerprint of every input that can change a computed classification.
///
/// [settingsFingerprint] is the [AnalysisSettings.fingerprint] of the
/// diver's own settings ([diverAnalysisSettingsProvider]): the gradient factors, but also the ppO2
/// limits, ascent gases, deco stop increments and metric sources, any of which
/// can move the NDL curve (issue #2592; this used to name only the GF).
/// Per-dive inputs (the dive's stored GF, altitude, water type, and the
/// profile samples themselves) are all covered by [diveUpdatedAt], which moves
/// whenever the dive row or its profile is written.
///
/// That makes the fingerprint computable from the statistics scan alone, with
/// no dive hydration, which is what lets a warm library skip loading profiles
/// entirely. A dive that does carry its own GF is invalidated needlessly when
/// the global setting changes; that costs one recompute and never a wrong
/// answer, which is the right direction to err.
///
/// The separators matter, so a shifted digit in one field cannot impersonate
/// its neighbour.
String decoInputsHash({
  required int engineVersion,
  required String settingsFingerprint,
  required int diveUpdatedAt,
}) => 'v$engineVersion|$diveUpdatedAt|$settingsFingerprint';

/// Classifies dives that carry no recorded deco signal by running the same
/// analysis the dive detail page runs (#623).
///
/// Reading [profileAnalysisProvider] rather than reimplementing the deco test
/// is the point of the exercise: the bug was the statistics card and the dive
/// page answering the same question from different layers, and a second
/// implementation would let them drift apart again.
class DecoClassificationService {
  const DecoClassificationService();

  static final _log = LoggerService.forClass(DecoClassificationService);

  /// Returns `diveId -> hadDeco` for every dive in [revisions] that could be
  /// classified. [revisions] maps dive id to that dive's `dives.updated_at`,
  /// as returned by `InsightsRepository.scanRecordedDecoSignals`.
  ///
  /// Dives whose analysis yields nothing (no usable profile) are absent from
  /// the result and stay unclassified rather than defaulting to no-deco.
  ///
  /// The whole cache is read in one query up front, so a warm library performs
  /// a single SELECT and hydrates no profiles at all. Only genuine misses are
  /// analyzed, in chunks, with their analysis invalidated afterwards:
  /// [profileAnalysisProvider] and [analysisDiveProvider] are keepAlive
  /// families, so a library-wide pass would otherwise retain every profile's
  /// curves for the whole session.
  Future<Map<String, bool>> classify(
    Ref ref,
    Map<String, int> revisions, {
    int chunkSize = 25,
  }) async {
    if (revisions.isEmpty) return const {};

    // The active diver's settings, once loaded: during a diver switch the
    // previous diver's are still in state (#2564).
    await awaitActiveDiverSettings(ref);
    final settingsFingerprint = ref
        .read(diverAnalysisSettingsProvider)
        .fingerprint;

    final hashes = <String, String>{
      for (final entry in revisions.entries)
        entry.key: decoInputsHash(
          engineVersion: analysisEngineVersion,
          settingsFingerprint: settingsFingerprint,
          diveUpdatedAt: entry.value,
        ),
    };

    final cache = DecoClassificationCacheRepository();
    final results = <String, bool>{};
    final misses = <String>[];

    try {
      final stored = await cache.getEntries(revisions.keys.toSet());
      for (final diveId in revisions.keys) {
        final entry = stored[diveId];
        if (entry != null && entry.inputsHash == hashes[diveId]) {
          results[diveId] = entry.hadDeco;
        } else {
          misses.add(diveId);
        }
      }
    } catch (e, stackTrace) {
      // A cache failure must not lose the statistic: fall back to computing
      // everything rather than reporting the whole library as unclassified.
      _log.error(
        'Failed to read the deco classification cache',
        error: e,
        stackTrace: stackTrace,
      );
      misses
        ..clear()
        ..addAll(revisions.keys);
    }

    for (var start = 0; start < misses.length; start += chunkSize) {
      final end = start + chunkSize < misses.length
          ? start + chunkSize
          : misses.length;
      for (final diveId in misses.sublist(start, end)) {
        try {
          final analysis = await ref.read(
            profileAnalysisProvider(diveId).future,
          );
          if (analysis == null || analysis.ndlCurve.isEmpty) continue;

          final hadDeco = analysis.hadDecoObligation;
          results[diveId] = hadDeco;
          // Cached only when the analysis ran on the diver's own settings.
          // One drawn on a chart source toggle, or on settings that moved
          // since the hashes above were taken, still answers this pass but
          // is not kept under a fingerprint it does not match.
          final ranOn = analysis.inputsFingerprint;
          if (ranOn == null || ranOn == settingsFingerprint) {
            await cache.put(
              diveId,
              hadDeco: hadDeco,
              inputsHash: hashes[diveId]!,
            );
          }
        } catch (e, stackTrace) {
          _log.error(
            'Failed to classify deco obligation for dive $diveId',
            error: e,
            stackTrace: stackTrace,
          );
        } finally {
          ref.invalidate(profileAnalysisProvider(diveId));
          ref.invalidate(analysisDiveProvider(diveId));
        }
      }
    }
    return results;
  }
}
