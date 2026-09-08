import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

enum QualityChip { all, time, profile, gas, tanks, duplicates, sources }

Set<QualityCategory> categoriesFor(QualityChip chip) => switch (chip) {
  QualityChip.all => QualityCategory.values.toSet(),
  QualityChip.time => {QualityCategory.time},
  QualityChip.profile => {QualityCategory.profile, QualityCategory.temperature},
  QualityChip.gas => {QualityCategory.gas},
  QualityChip.tanks => {QualityCategory.tank, QualityCategory.pressure},
  QualityChip.duplicates => {QualityCategory.duplicate},
  QualityChip.sources => {QualityCategory.source},
};

final qualityFindingsStreamProvider =
    StreamProvider.autoDispose<List<QualityFinding>>(
      (ref) => ref.watch(qualityFindingsRepositoryProvider).watchFindings(),
    );

final qualityInboxChipProvider = StateProvider<QualityChip>(
  (_) => QualityChip.all,
);

/// Identities for every dive the current findings name, keyed by dive id.
///
/// Includes each cross-dive finding's `relatedDiveId`, so a duplicate or split
/// row can name the *other* dive it would merge with, not just its anchor.
///
/// One batched slim query for the whole inbox rather than a hydrated
/// `diveProvider` read per row: a header needs a number, a date, and a site,
/// while `getDiveById` also loads tanks, pressures, the profile, and
/// equipment. A dive that no longer exists is simply absent from the map;
/// callers render the "dive is gone" label for it.
final qualityFindingDivesProvider = FutureProvider.autoDispose
    .family<Map<String, DiveSummary>, String>((ref, key) async {
      final ids = key.isEmpty ? const <String>[] : key.split(',');
      if (ids.isEmpty) return const {};
      final repository = ref.watch(diveRepositoryProvider);
      // The dives tick, not the detail tick: this reads the `dives` row and
      // its site join, and the page's own repairs write that table -- a
      // consolidate deletes a dive, so its header must stop naming it. The
      // detail tick would additionally re-run this on every profile-series
      // write, which a name and a date do not depend on. The trade is that a
      // site renamed elsewhere while the inbox is open shows its old name
      // until the next dives write.
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      final summaries = await repository.getSummariesByIds(ids);
      return {for (final s in summaries) s.id: s};
    });

/// Canonical family key for [qualityFindingDivesProvider]: every dive id a
/// finding list names (anchor and related), sorted and comma-joined. Same
/// reasoning as [importedDivesFindingsKey] -- a value-type key collapses
/// equal id sets onto one provider instance instead of re-querying on every
/// rebuild.
String qualityFindingDivesKey(Iterable<QualityFinding> findings) =>
    importedDivesFindingsKey({
      for (final f in findings) ...[f.diveId, ?f.relatedDiveId],
    });

/// Dive computer display names keyed by id, for findings that record which
/// computer produced the data they flag. Watches the saved-computers list
/// once for the whole page instead of a lookup per card.
final qualityComputerNamesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final computers = await ref.watch(allDiveComputersProvider.future);
      return {for (final c in computers) c.id: c.displayName};
    });

final diveOpenFindingsCountProvider = StreamProvider.autoDispose
    .family<int, String>(
      (ref, diveId) => ref
          .watch(qualityFindingsRepositoryProvider)
          .watchOpenCountForDive(diveId),
    );

/// Canonical family key for [importedDivesOpenFindingsCountProvider]: dive ids
/// sorted and comma-joined. A `List` key uses identity equality, so equal id
/// sets across rebuilds would spin up duplicate providers/subscriptions and
/// miss cache hits; a value-type string key collapses them to one instance.
/// Dive ids are UUIDs, so a comma is a safe delimiter.
String importedDivesFindingsKey(Iterable<String> diveIds) =>
    (diveIds.toList()..sort()).join(',');

/// Open-finding count over an import's dive set (for the import summary line).
/// Keyed by [importedDivesFindingsKey] so equal id sets share one provider.
/// Counts in SQL (scoped to the id set) instead of watching the whole findings
/// stream and filtering in Dart, so the update cost stays flat as the library
/// grows rather than being O(findings) per change.
final importedDivesOpenFindingsCountProvider = StreamProvider.autoDispose
    .family<int, String>((ref, key) {
      final ids = key.isEmpty ? const <String>{} : key.split(',').toSet();
      return ref
          .watch(qualityFindingsRepositoryProvider)
          .watchOpenCountForDives(ids);
    });
