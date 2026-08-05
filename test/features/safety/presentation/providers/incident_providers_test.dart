import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Serves canned incident lists without a database and records the scoping
/// diver id the provider passes through.
class _FakeIncidentRepository extends IncidentRepository {
  _FakeIncidentRepository(this.incidents);

  final List<Incident> incidents;
  String? queriedDiverId;

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<List<Incident>> getIncidents({String? diverId}) async {
    queriedDiverId = diverId;
    return incidents;
  }

  @override
  Future<List<Incident>> getIncidentsForDive(String diveId) async {
    return incidents.where((i) => i.diveId == diveId).toList();
  }
}

void main() {
  Incident incident({String? diveId}) => Incident(
    id: 'i1',
    occurredAt: DateTime.utc(2026, 7, 10),
    category: IncidentCategory.gasSupply,
    severity: IncidentSeverity.moderate,
    narrative: 'Free-flow at 18 m.',
    createdAt: DateTime.utc(2026, 7, 10),
    updatedAt: DateTime.utc(2026, 7, 10),
    diveId: diveId,
  );

  test('incidentsProvider scopes to the active diver', () async {
    final repo = _FakeIncidentRepository([incident()]);
    final diver = MockCurrentDiverIdNotifier();
    await diver.setCurrentDiver('diver-1');

    final container = ProviderContainer(
      overrides: [
        incidentRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => diver),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(incidentsProvider.future);
    expect(result, hasLength(1));
    expect(repo.queriedDiverId, 'diver-1');
  });

  test('incidentsForDiveProvider filters by dive', () async {
    final repo = _FakeIncidentRepository([
      incident(diveId: 'dive-9'),
      incident(diveId: 'other'),
    ]);

    final container = ProviderContainer(
      overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      incidentsForDiveProvider('dive-9').future,
    );
    expect(result, hasLength(1));
    expect(result.single.diveId, 'dive-9');
  });
}
