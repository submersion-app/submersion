import 'dart:async';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Incident;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/pages/incident_edit_page.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A repository whose read of one report fails, as a closed database would.
class _FailingReadRepository extends IncidentRepository {
  @override
  Future<Incident?> getIncidentById(String id) =>
      Future.error(StateError('database closed'));
}

/// A repository whose create fails, as a locked database would.
class _FailingWriteRepository extends IncidentRepository {
  @override
  Future<Incident> createIncident({
    String? id,
    required DateTime occurredAt,
    required IncidentCategory category,
    required IncidentSeverity severity,
    required String narrative,
    String? contributingFactors,
    String? lessonsLearned,
    String? diveId,
    String? diverId,
    String? equipmentId,
    String? observationId,
  }) => Future.error(Exception('database is locked'));
}

/// The near-miss editor on the shared Cancel and Save bar (issue #4527,
/// phase 4, plan 4).
void main() {
  late AppDatabase db;
  late IncidentRepository incidents;
  late EquipmentObservationRepository observations;
  late ProviderContainer container;
  late List<Set<String>> refreshes;

  setUp(() async {
    db = await setUpTestDatabase();
    incidents = IncidentRepository();
    observations = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    for (final diver in ['me', 'b']) {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$diver', '$diver', 1, 1)",
      );
    }
    for (final (id, name) in [('reg', 'Apeks XTX'), ('bcd', 'Halcyon')]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: name,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diverId: const Value('me'),
            diveDateTime: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    refreshes = [];
    SensorSummaryScheduler.instance.findingsRequestListener = refreshes.add;
  });
  tearDown(() async {
    SensorSummaryScheduler.instance.findingsRequestListener = null;
    await tearDownTestDatabase();
  });

  /// A stored report on the regulator.
  Future<Incident> stored() => incidents.createIncident(
    occurredAt: DateTime.utc(2026, 3, 1),
    category: IncidentCategory.gasSupply,
    severity: IncidentSeverity.moderate,
    narrative: 'Free-flow at 18 m.',
    lessonsLearned: 'Service the reg.',
    diverId: 'me',
    equipmentId: 'reg',
  );

  /// The editor pushed over a stand-in near-miss list, on routes with the
  /// app's leave check, as the app's are.
  Future<void> pump(
    WidgetTester tester,
    String location, {
    IncidentRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/incidents',
      routes: [
        GoRoute(
          path: '/incidents',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(
              path: 'new',
              onExit: confirmLeaveRecordSitting,
              builder: (_, state) => IncidentEditPage(
                diveId: state.uri.queryParameters['diveId'],
                observationId: state.uri.queryParameters['observationId'],
              ),
            ),
            GoRoute(
              path: ':incidentId',
              onExit: confirmLeaveRecordSitting,
              builder: (_, state) => IncidentEditPage(
                incidentId: state.pathParameters['incidentId'],
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
          equipmentObservationRepositoryProvider.overrideWithValue(
            observations,
          ),
          if (repository != null)
            incidentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('me');
    await tester.pumpAndSettle();
    unawaited(router.push(location));
    await tester.pumpAndSettle();
  }

  Finder saveFinder() => find.widgetWithText(AppBarTextAction, 'Save');

  AppBarTextAction save(WidgetTester tester) =>
      tester.widget<AppBarTextAction>(saveFinder());

  Future<void> tapSave(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(saveFinder());
    await tester.pumpAndSettle();
  }

  Future<void> cancel(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('recordEditorMenu')));
    await tester.pumpAndSettle();
  }

  Future<List<String?>> labels(String like) async {
    final rows = await db
        .customSelect(
          'SELECT label FROM change_log_operations WHERE label LIKE ?',
          variables: [Variable.withString(like)],
        )
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  testWidgets('the bar is the tinted Cancel and Save bar, with no Save at '
      'the bottom', (tester) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('a stored report opened and left alone is unchanged', (
    tester,
  ) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');

    await cancel(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a new report from a dive opens with Save enabled', (
    tester,
  ) async {
    await pump(tester, '/incidents/new?diveId=d1');

    expect(save(tester).onPressed, isNotNull);
    await cancel(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a new report from a check-in opens with Save enabled', (
    tester,
  ) async {
    final checkIn = await observations.create(
      equipmentId: 'reg',
      diveId: 'd1',
      diverId: 'me',
      observedAt: DateTime.utc(2026, 3, 1, 11),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow],
      note: 'Second stage at 28 m',
    );
    await pump(tester, '/incidents/new?observationId=${checkIn.id}');

    expect(save(tester).onPressed, isNotNull);
    await cancel(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a check-in gone before the form opened leaves a clean form', (
    tester,
  ) async {
    await pump(tester, '/incidents/new?observationId=gone');

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(save(tester).onPressed, isNull);
    await cancel(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a plain new report is clean until something is entered', (
    tester,
  ) async {
    await pump(tester, '/incidents/new');

    expect(save(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextFormField).first, 'Lost my buddy');
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('Save writes one change log operation labelled with the '
      'report', (tester) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');
    await tester.tap(find.text('Serious'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(find.text('LIST'), findsOneWidget);
    expect(
      (await incidents.getIncidentById(incident.id))!.severity,
      IncidentSeverity.serious,
    );
    final sittings = await labels('record_edit:%');
    expect(sittings, hasLength(1));
    final label = RecordEditLabel.decode(sittings.single!)!;
    expect(label.table, 'incidents');
    expect(label.id, incident.id);
  });

  testWidgets('a new report is created under the page id', (tester) async {
    await pump(tester, '/incidents/new?diveId=d1');
    final state = tester.state<State>(find.byType(IncidentEditPage));
    final pageId = (state as dynamic).newEditorRecordId as String;
    await tester.enterText(find.byType(TextFormField).first, 'Lost my buddy');

    await tapSave(tester);

    final created = await incidents.getIncidentById(pageId);
    expect(created, isNotNull);
    expect(created!.diverId, 'me');
    expect(created.diveId, 'd1');
    expect(created.narrative, 'Lost my buddy');
  });

  testWidgets('a severity change keeps lessons synced in meanwhile', (
    tester,
  ) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');
    await (db.update(db.incidents)..where((t) => t.id.equals(incident.id)))
        .write(const IncidentsCompanion(lessonsLearned: Value('From a peer.')));

    await tester.tap(find.text('Serious'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    final back = (await incidents.getIncidentById(incident.id))!;
    expect(back.severity, IncidentSeverity.serious);
    expect(back.lessonsLearned, 'From a peer.');
  });

  testWidgets('a report deleted while open is refused and not brought back', (
    tester,
  ) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');
    await incidents.deleteIncident(incident.id);

    await tester.tap(find.text('Serious'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Near-miss report not found'), findsOneWidget);
    expect(await incidents.getIncidentById(incident.id), isNull);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('a save that fails is logged', (tester) async {
    final logged = <LogEntry>[];
    final subscription = LoggerService.logStream.listen(logged.add);
    addTearDown(subscription.cancel);
    await pump(tester, '/incidents/new', repository: _FailingWriteRepository());
    await tester.enterText(find.byType(TextFormField).first, 'Lost a fin');

    await tapSave(tester);

    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
    expect(
      logged.where((e) => e.message.contains('database is locked')),
      isNotEmpty,
    );
  });

  testWidgets('a refused save is not logged as a failure', (tester) async {
    final logged = <LogEntry>[];
    final subscription = LoggerService.logStream.listen(logged.add);
    addTearDown(subscription.cancel);
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');
    await incidents.deleteIncident(incident.id);

    await tester.tap(find.text('Serious'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Near-miss report not found'), findsOneWidget);
    expect(
      logged.where((e) => e.message.contains('Could not save a near-miss')),
      isEmpty,
    );
  });

  testWidgets('Delete is in the menu, disabled while there are changes', (
    tester,
  ) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');
    await tester.tap(find.text('Serious'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    final item = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(find.text('Save or cancel your changes first'), findsOneWidget);
  });

  testWidgets('a new report has no menu', (tester) async {
    await pump(tester, '/incidents/new?diveId=d1');

    expect(find.byKey(const ValueKey('recordEditorMenu')), findsNothing);
  });

  testWidgets('Delete asks, removes the report in its own History entry, '
      'and leaves', (tester) async {
    final incident = await stored();
    await pump(tester, '/incidents/${incident.id}');

    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this near-miss report?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(await incidents.getIncidentById(incident.id), isNull);
    expect(await labels(ChangeLogLabels.deletedRecord), hasLength(1));
    expect(refreshes, [
      {'reg'},
    ]);
  });

  testWidgets('a new report typed in closes on a diver switch, writing '
      'nothing', (tester) async {
    await pump(tester, '/incidents/new');
    await tester.enterText(find.byType(TextFormField).first, 'Half typed');
    await tester.pumpAndSettle();

    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
    expect(await incidents.getIncidents(), isEmpty);
  });

  testWidgets('a report that will not load keeps the error page with no '
      'tinted bar', (tester) async {
    await pump(tester, '/incidents/i1', repository: _FailingReadRepository());

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Edit near-miss'), findsOneWidget);
  });
}
