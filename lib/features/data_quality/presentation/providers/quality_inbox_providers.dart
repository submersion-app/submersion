import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';

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
