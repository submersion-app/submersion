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

final qualityFindingsStreamProvider = StreamProvider<List<QualityFinding>>(
  (ref) => ref.watch(qualityFindingsRepositoryProvider).watchFindings(),
);

final qualityInboxChipProvider = StateProvider<QualityChip>(
  (_) => QualityChip.all,
);

final diveOpenFindingsCountProvider = StreamProvider.family<int, String>(
  (ref, diveId) => ref
      .watch(qualityFindingsRepositoryProvider)
      .watchOpenCountForDive(diveId),
);

/// Open-finding count over an import's dive set (for the import summary line).
/// List-keyed families need a stable key; callers pass a fixed list instance.
final importedDivesOpenFindingsCountProvider =
    StreamProvider.family<int, List<String>>((ref, diveIds) {
      final repo = ref.watch(qualityFindingsRepositoryProvider);
      return repo.watchFindings().map(
        (all) => all
            .where(
              (f) =>
                  f.status == QualityStatus.open &&
                  (diveIds.contains(f.diveId) ||
                      diveIds.contains(f.relatedDiveId)),
            )
            .length,
      );
    });
