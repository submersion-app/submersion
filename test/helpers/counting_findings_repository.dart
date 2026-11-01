import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';

/// Counts the whole-list findings reads, to pin how often a provider reloads.
class CountingFindingsRepository extends EquipmentFindingsRepository {
  CountingFindingsRepository({super.db});

  int reads = 0;

  @override
  Future<List<FindingSummary>> getUndismissedSummaries() {
    reads++;
    return super.getUndismissedSummaries();
  }
}
