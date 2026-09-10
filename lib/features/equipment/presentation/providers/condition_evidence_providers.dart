import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';

typedef ConditionEvidenceKey = ({String equipmentId, String findingId});

/// The dives behind one finding, most recent first, as slim summaries.
/// Keyed by the finding id so the family key stays a plain record; the
/// dive ids are read from the findings provider. A dive that no longer
/// exists is simply absent (a deleted dive is not an error).
final conditionEvidenceDivesProvider =
    FutureProvider.family<List<DiveSummary>, ConditionEvidenceKey>((
      ref,
      key,
    ) async {
      final findings = await ref.watch(
        equipmentConditionProvider(key.equipmentId).future,
      );
      final finding = findings?.where((f) => f.id == key.findingId).firstOrNull;
      if (finding == null) return const [];
      return ref
          .watch(diveRepositoryProvider)
          .getSummariesByIds(finding.evidence.diveIds);
    });
