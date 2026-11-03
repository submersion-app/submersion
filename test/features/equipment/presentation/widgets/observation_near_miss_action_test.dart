import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiversCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_near_miss_action.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late EquipmentItem reg;

  setUp(() async {
    final db = await setUpTestDatabase();
    for (final id in ['me', 'someone-else']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentObservation> checkIn({
    ObservationStatus status = ObservationStatus.issue,
  }) => EquipmentObservationRepository().create(
    equipmentId: reg.id,
    observedAt: DateTime.utc(2026, 3, 1),
    status: status,
    issueTags: [if (status == ObservationStatus.issue) ObservationTag.leak],
  );

  Future<Incident> report(EquipmentObservation on, {String? diverId}) =>
      IncidentRepository().createIncident(
        occurredAt: DateTime.utc(2026, 3, 1),
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'Leak',
        equipmentId: reg.id,
        observationId: on.id,
        diverId: diverId,
      );

  /// A router with the action on '/' and a stand-in for every near-miss
  /// route, showing where a tap went.
  Future<void> pump(
    WidgetTester tester,
    EquipmentObservation observation, {
    String? activeDiver = 'me',
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ObservationNearMissAction(observation: observation),
          ),
        ),
        GoRoute(
          path: '/incidents',
          builder: (_, _) => const Text('log'),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, state) =>
                  Text('new ${state.uri.queryParameters['observationId']}'),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => Text('open ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => activeDiver,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an issue with no report offers to log one from the check-in', (
    tester,
  ) async {
    final observation = await checkIn();
    await pump(tester, observation);

    await tester.tap(find.text('Log near-miss'));
    await tester.pumpAndSettle();

    expect(find.text('new ${observation.id}'), findsOneWidget);
  });

  testWidgets('an issue with one report says so and opens it', (tester) async {
    final observation = await checkIn();
    final incident = await report(observation, diverId: 'me');
    await pump(tester, observation);

    await tester.tap(find.text('Near-miss linked'));
    await tester.pumpAndSettle();

    expect(find.text('open ${incident.id}'), findsOneWidget);
  });

  testWidgets('several reports show a count and open the log', (tester) async {
    final observation = await checkIn();
    await report(observation, diverId: 'me');
    await report(observation);
    await pump(tester, observation);

    await tester.tap(find.text('2 near-misses linked'));
    await tester.pumpAndSettle();

    expect(find.text('log'), findsOneWidget);
  });

  testWidgets('an OK check offers nothing', (tester) async {
    final observation = await checkIn(status: ObservationStatus.ok);
    await pump(tester, observation);

    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('with no active diver every report shows, as in the log', (
    tester,
  ) async {
    final observation = await checkIn();
    await report(observation, diverId: 'someone-else');
    await pump(tester, observation, activeDiver: null);

    expect(find.text('Near-miss linked'), findsOneWidget);
  });

  testWidgets("another diver's report stays private on shared gear", (
    tester,
  ) async {
    final observation = await checkIn();
    await report(observation, diverId: 'someone-else');
    await pump(tester, observation);

    expect(find.text('Near-miss linked'), findsNothing);
    expect(find.text('Log near-miss'), findsOneWidget);
  });
}
