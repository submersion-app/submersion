import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';

/// Language-neutral fallback labels for [resolveSourceName] used off the
/// widget tree (providers cannot read context.l10n). Comparison labels favor
/// the computer model/serial, which are language-neutral, so this only
/// affects the rare fully-unidentified source.
const _neutralLabels = SourceNameLabels(
  unknownComputer: 'Computer',
  manualEntry: 'Manual entry',
  importedFile: 'Imported file',
  editedSuffix: ' (edited)',
);

/// The fewest points a profile needs to be drawn at all.
const int _minProfilePoints = 2;

/// The dive-computer sources of a single dive, as comparison profiles. The
/// primary source is placed first so it is the reference (index 0). Sources
/// without usable depth samples are skipped. The full comparable set is
/// returned; the view caps how many it renders and notes the remainder.
final computerComparisonProfilesProvider =
    FutureProvider.family<List<ComparisonProfile>, String>((ref, diveId) async {
      final sources = await ref.watch(diveDataSourcesProvider(diveId).future);
      final profilesBySource = await ref.watch(
        sourceProfilesProvider(diveId).future,
      );

      // Primary first (reference index 0), then the rest in their original
      // order. An explicit partition keeps ordering -- and thus per-source
      // color assignment -- deterministic; List.sort is not stable when the
      // comparator returns 0 for two non-primary sources.
      final ordered = [
        ...sources.where((s) => s.isPrimary),
        ...sources.where((s) => !s.isPrimary),
      ];

      final out = <ComparisonProfile>[];
      for (final source in ordered) {
        final sp = profilesBySource[source.id];
        // Metadata-only.
        if (sp == null || sp.points.length < _minProfilePoints) continue;
        final times = [for (final p in sp.points) p.timestamp.toDouble()];
        final depths = [for (final p in sp.points) p.depth];
        out.add(
          ComparisonProfile(
            id: source.id,
            label: resolveSourceName(
              source,
              _neutralLabels,
              edited: sp.isEdited,
            ),
            color: sourceColorAt(out.length),
            times: times,
            depths: depths,
            maxDepthMeters: depths.fold(0.0, (a, b) => b > a ? b : a),
          ),
        );
      }
      return out;
    });

/// Equatable key for a fixed, ordered set of dive ids, so the multi-dive
/// comparison provider can be a proper `family`.
class DiveIdSet {
  final List<String> ids;

  // Defensive copy to an unmodifiable list: this is a Provider family key, so
  // it must stay immutable even if the caller later mutates the list it passed
  // (e.g. reused/modified route extras), which would otherwise change
  // ==/hashCode and silently break provider caching.
  DiveIdSet(List<String> ids) : ids = List.unmodifiable(ids);

  @override
  bool operator ==(Object other) =>
      other is DiveIdSet &&
      other.ids.length == ids.length &&
      _eq(other.ids, ids);

  @override
  int get hashCode => Object.hashAll(ids);

  static bool _eq(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Several dives' primary profiles, as a comparison in selection order. The
/// first usable dive is the reference (index 0); dives without a usable
/// profile (manual logs) are skipped.
///
/// A selection can hold the whole logbook and the view shows
/// [kMaxComparisonProfiles], so stored sample counts pick the dives and only
/// those are loaded, one at a time and no further once the page is left. The
/// profiles are read here rather than through [sourceProfilesProvider], whose
/// entries outlive this page: leaving the comparison releases its samples.
final diveComparisonProfilesProvider = FutureProvider.autoDispose
    .family<DiveComparison, DiveIdSet>((ref, key) async {
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(
        repository.watchTables(DiveRepository.comparisonTickTables),
      );

      final sampleCounts = await repository.getPrimarySourceSampleCounts(
        key.ids,
      );
      final candidates = [
        for (final diveId in key.ids)
          if ((sampleCounts[diveId] ?? 0) >= _minProfilePoints) diveId,
      ];

      final shown = <(String, SourceProfile)>[];
      // A stored count cannot see a blob that no longer decodes, so a
      // candidate can still come back empty. The next one takes its place and
      // the total stops counting it.
      var unusable = 0;
      for (final diveId in candidates) {
        if (shown.length == kMaxComparisonProfiles) break;
        // Nothing reads the result of a walk the diver has left.
        if (!ref.mounted) {
          return const DiveComparison(profiles: [], comparableCount: 0);
        }
        final profilesBySource = await repository.getProfilesByDataSource(
          diveId,
        );
        final sp = profilesBySource.values.firstOrNull; // primary is first
        if (sp == null || sp.points.length < _minProfilePoints) {
          unusable++;
        } else {
          shown.add((diveId, sp));
        }
      }

      final summaries = {
        for (final summary in await repository.getSummariesByIds([
          for (final (diveId, _) in shown) diveId,
        ]))
          summary.id: summary,
      };
      return DiveComparison(
        profiles: [
          for (final (index, (diveId, sp)) in shown.indexed)
            _diveProfile(diveId, sp, summaries[diveId], index),
        ],
        comparableCount: candidates.length - unusable,
      );
    });

ComparisonProfile _diveProfile(
  String diveId,
  SourceProfile sp,
  DiveSummary? summary,
  int index,
) {
  final depths = [for (final p in sp.points) p.depth];
  final diveNumber = summary?.diveNumber;
  return ComparisonProfile(
    id: diveId,
    // Site name when known, else the language-neutral dive number (avoids
    // embedding an English label in a provider).
    label: summary?.siteName ?? (diveNumber != null ? '#$diveNumber' : diveId),
    color: sourceColorAt(index),
    times: [for (final p in sp.points) p.timestamp.toDouble()],
    depths: depths,
    maxDepthMeters: depths.fold(0.0, (a, b) => b > a ? b : a),
  );
}
