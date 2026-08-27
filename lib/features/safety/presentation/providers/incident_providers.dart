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
  final diverId = ref.watch(currentDiverIdProvider);
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
