import 'package:collection/collection.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository();
});

final incidentsProvider = FutureProvider<List<Incident>>((ref) async {
  final repo = ref.watch(incidentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  // The validated id, which new incidents are saved under: a stale raw id
  // would hide the incident just saved.
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repo.getIncidents(diverId: diverId);
});

final incidentsForDiveProvider = FutureProvider.family<List<Incident>, String>((
  ref,
  diveId,
) async {
  final repo = ref.watch(incidentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  return repo.getIncidentsForDive(diveId);
});

/// The active diver's near-misses on [equipmentId] that name a check-in, keyed
/// by check-in id, in one read for an item's whole list of check-in rows. A
/// report without a diver reads as the active diver's and no active diver
/// reads every report, as [incidentsProvider] has it; another profile's report
/// on shared gear is left out.
final nearMissesByCheckInProvider =
    FutureProvider.family<Map<String, List<Incident>>, String>((
      ref,
      equipmentId,
    ) async {
      final repo = ref.watch(incidentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final reports = await repo.getIncidentsForEquipment(equipmentId);
      return groupBy(
        reports.where(
          (r) =>
              r.observationId != null &&
              (diverId == null || r.diverId == null || r.diverId == diverId),
        ),
        (r) => r.observationId!,
      );
    });
