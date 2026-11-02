import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Incident;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/observations_card.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/pages/incident_edit_page.dart';
import 'package:submersion/features/safety/presentation/pages/incidents_list_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository observations;
  late IncidentRepository incidents;

  setUp(() async {
    db = await setUpTestDatabase();
    observations = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    incidents = IncidentRepository();
    expect(identical(db, DatabaseService.instance.database), isTrue);
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
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
    }
    await db
        .into(db.diveEquipment)
        .insert(
          const DiveEquipmentCompanion(
            diveId: Value('d1'),
            equipmentId: Value('reg'),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentObservation> checkIn({
    String equipmentId = 'reg',
    String? diveId = 'd1',
    ObservationStatus status = ObservationStatus.issue,
    ObservationTag tag = ObservationTag.freeFlow,
    String note = '',
    DateTime? observedAt,
  }) => observations.create(
    equipmentId: equipmentId,
    diveId: diveId,
    observedAt: observedAt ?? DateTime.utc(2026, 3, 1, 11),
    status: status,
    issueTags: [if (status == ObservationStatus.issue) tag],
    note: note,
  );

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(800, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('home'),
          routes: [GoRoute(path: 'page', builder: (_, _) => page)],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentObservationRepositoryProvider.overrideWithValue(
            observations,
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

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  Future<Incident> saved() async => (await incidents.getIncidents()).single;

  Future<void> pickGear(WidgetTester tester, String name) async {
    await tester.tap(find.text('Equipment involved'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SimpleDialogOption, name));
    await tester.pumpAndSettle();
  }

  Future<void> enterNarrative(WidgetTester tester) =>
      tester.enterText(find.byType(TextFormField).first, 'Free flow at 18 m');

  group('logging from a check-in', () {
    testWidgets('prefills the item, category, dive, day and note, then links', (
      tester,
    ) async {
      final observation = await checkIn(note: 'Second stage at 28 m');

      await pumpPage(tester, IncidentEditPage(observationId: observation.id));

      expect(find.text('Apeks XTX'), findsOneWidget);
      final narrative = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(narrative.controller!.text, 'Second stage at 28 m');

      await save(tester);

      final incident = await saved();
      expect(incident.observationId, observation.id);
      expect(incident.equipmentId, 'reg');
      expect(incident.diveId, 'd1');
      expect(incident.category, IncidentCategory.equipment);
      expect(incident.occurredAt, DateTime.utc(2026, 3, 1));
    });

    testWidgets('a check-in dated ahead of today lands on today', (
      tester,
    ) async {
      // A dive holds its own wall clock, so it can read later than this
      // device's clock, and the form's date picker refuses a future day.
      final now = DateTime.now();
      final observation = await checkIn(
        note: 'n',
        observedAt: DateTime.utc(now.year, now.month, now.day + 2),
      );

      await pumpPage(tester, IncidentEditPage(observationId: observation.id));
      await save(tester);

      expect(
        (await saved()).occurredAt,
        DateTime.utc(now.year, now.month, now.day),
      );
    });

    testWidgets('a check-in that has gone leaves a plain new form', (
      tester,
    ) async {
      await pumpPage(tester, const IncidentEditPage(observationId: 'gone'));

      expect(find.text('Log near-miss'), findsOneWidget);
      expect(find.text('Gear check-in'), findsNothing);
    });
  });

  group('the Gear check-in row', () {
    testWidgets('stays away until an item is named', (tester) async {
      await pumpPage(tester, const IncidentEditPage());
      expect(find.text('Gear check-in'), findsNothing);

      await pickGear(tester, 'Apeks XTX');
      expect(find.text('Gear check-in'), findsOneWidget);
    });

    testWidgets('selects the only issue on the dive', (tester) async {
      final observation = await checkIn();
      await checkIn(status: ObservationStatus.ok);

      await pumpPage(tester, const IncidentEditPage(diveId: 'd1'));
      await pickGear(tester, 'Apeks XTX');
      expect(find.textContaining('Free flow'), findsOneWidget);

      await enterNarrative(tester);
      await save(tester);
      expect((await saved()).observationId, observation.id);
    });

    testWidgets('does not guess between two issues on the dive', (
      tester,
    ) async {
      await checkIn();
      await checkIn(tag: ObservationTag.leak);

      await pumpPage(tester, const IncidentEditPage(diveId: 'd1'));
      await pickGear(tester, 'Apeks XTX');
      await enterNarrative(tester);
      await save(tester);

      expect((await saved()).observationId, isNull);
    });

    testWidgets('does not match an issue from another dive', (tester) async {
      await checkIn(diveId: 'd2');

      await pumpPage(tester, const IncidentEditPage(diveId: 'd1'));
      await pickGear(tester, 'Apeks XTX');
      await enterNarrative(tester);
      await save(tester);

      expect((await saved()).observationId, isNull);
    });

    testWidgets('lists this dive first, then the rest, issues only', (
      tester,
    ) async {
      await checkIn(status: ObservationStatus.ok);
      await checkIn(tag: ObservationTag.hoseDamage);
      await checkIn(tag: ObservationTag.leak, diveId: 'd2');
      await checkIn(tag: ObservationTag.wetBreathing);

      await pumpPage(tester, const IncidentEditPage(diveId: 'd1'));
      await pickGear(tester, 'Apeks XTX');
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();

      final dialog = find.byType(SimpleDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('On this dive')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Other check-ins')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.textContaining('Hose damage').last).dy,
        lessThan(tester.getTopLeft(find.text('Other check-ins')).dy),
      );
      expect(
        tester.getTopLeft(find.textContaining('Leak').last).dy,
        greaterThan(tester.getTopLeft(find.text('Other check-ins')).dy),
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('OK')),
        findsNothing,
      );
    });

    testWidgets('choosing fills an empty dive and an untouched date', (
      tester,
    ) async {
      final observation = await checkIn(
        diveId: 'd2',
        observedAt: DateTime.utc(2026, 2, 20, 9),
      );

      await pumpPage(tester, const IncidentEditPage());
      await pickGear(tester, 'Apeks XTX');
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Free flow').last);
      await tester.pumpAndSettle();
      await enterNarrative(tester);
      await save(tester);

      final incident = await saved();
      expect(incident.observationId, observation.id);
      expect(incident.diveId, 'd2');
      expect(incident.occurredAt, DateTime.utc(2026, 2, 20));
    });

    testWidgets('a dive that came with a check-in goes with it', (
      tester,
    ) async {
      await checkIn(diveId: 'd2');

      await pumpPage(tester, const IncidentEditPage());
      await pickGear(tester, 'Apeks XTX');
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Free flow').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'None'));
      await tester.pumpAndSettle();
      await enterNarrative(tester);
      await save(tester);

      final incident = await saved();
      expect(incident.observationId, isNull);
      expect(incident.diveId, isNull);
    });

    testWidgets('picking another check-in takes its dive, not the first', (
      tester,
    ) async {
      await checkIn(diveId: 'd1');
      final second = await checkIn(diveId: 'd2', tag: ObservationTag.leak);

      await pumpPage(tester, const IncidentEditPage());
      await pickGear(tester, 'Apeks XTX');
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Free flow').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Leak').last);
      await tester.pumpAndSettle();
      await enterNarrative(tester);
      await save(tester);

      final incident = await saved();
      expect(incident.observationId, second.id);
      expect(incident.diveId, 'd2');
    });

    testWidgets('changing an edited report keeps its own dive and date', (
      tester,
    ) async {
      final observation = await checkIn(
        diveId: 'd2',
        observedAt: DateTime.utc(2026, 2, 20, 9),
      );
      final incident = await incidents.createIncident(
        occurredAt: DateTime.utc(2026, 2, 25),
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'Free flow',
        diveId: 'd1',
        equipmentId: 'reg',
      );

      await pumpPage(tester, IncidentEditPage(incidentId: incident.id));
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Free flow').last);
      await tester.pumpAndSettle();
      await save(tester);

      final after = await saved();
      expect(after.observationId, observation.id);
      expect(after.diveId, 'd1');
      expect(after.occurredAt, DateTime.utc(2026, 2, 25));
    });

    testWidgets('None clears the link', (tester) async {
      final observation = await checkIn();
      final incident = await incidents.createIncident(
        occurredAt: DateTime.utc(2026, 3, 1),
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'Free flow',
        diveId: 'd1',
        equipmentId: 'reg',
        observationId: observation.id,
      );

      await pumpPage(tester, IncidentEditPage(incidentId: incident.id));
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'None'));
      await tester.pumpAndSettle();
      await save(tester);

      expect((await saved()).observationId, isNull);
    });

    testWidgets('naming another item drops the link', (tester) async {
      final observation = await checkIn();
      final incident = await incidents.createIncident(
        occurredAt: DateTime.utc(2026, 3, 1),
        category: IncidentCategory.equipment,
        severity: IncidentSeverity.minor,
        narrative: 'Free flow',
        equipmentId: 'reg',
        observationId: observation.id,
      );

      await pumpPage(tester, IncidentEditPage(incidentId: incident.id));
      await pickGear(tester, 'Halcyon');
      await save(tester);

      final after = await saved();
      expect(after.equipmentId, 'bcd');
      expect(after.observationId, isNull);
    });

    testWidgets('a bench check-in dates the report on its local day', (
      tester,
    ) async {
      final observation = await checkIn(
        diveId: null,
        note: 'n',
        observedAt: DateTime(2026, 2, 20, 23, 30).toUtc(),
      );

      await pumpPage(tester, IncidentEditPage(observationId: observation.id));
      await save(tester);

      expect((await saved()).occurredAt, DateTime.utc(2026, 2, 20));
    });

    for (final (what, change) in [
      ('deleted', (EquipmentObservation o) => observations.delete(o.id)),
      (
        'saved as OK',
        (EquipmentObservation o) =>
            observations.update(o.copyWith(status: ObservationStatus.ok)),
      ),
    ]) {
      testWidgets('a chosen check-in $what meanwhile is not saved', (
        tester,
      ) async {
        // The sheet the form opens can do this to the row the form has chosen.
        final observation = await checkIn();

        await pumpPage(tester, const IncidentEditPage(diveId: 'd1'));
        await pickGear(tester, 'Apeks XTX');
        expect(find.textContaining('Free flow'), findsOneWidget);

        await tester.runAsync(() => change(observation));
        await tester.pumpAndSettle();
        expect(find.textContaining('Free flow'), findsNothing);

        await enterNarrative(tester);
        await save(tester);

        expect((await saved()).observationId, isNull);
      });
    }

    testWidgets('Add check-in selects the issue just added', (tester) async {
      await pumpPage(tester, const IncidentEditPage(diveId: 'd1'));
      await pickGear(tester, 'Apeks XTX');
      await tester.tap(find.text('Gear check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Add check-in'));
      await tester.pumpAndSettle();

      // The existing sheet, opened on the item and the dive.
      await tester.tap(find.widgetWithText(FilledButton, 'Add check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Issue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free flow'));
      await tester.pump();
      // The sheet's Save, above the form's.
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      // The sheet offers no near-miss action: this form is that near-miss.
      expect(find.text('Log near-miss', skipOffstage: false), findsOneWidget);
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      await enterNarrative(tester);
      await save(tester);

      final stored = await observations.getForDive('d1');
      expect((await saved()).observationId, stored.single.id);
    });
  });

  group('from a check-in row, there and back', () {
    final reg = EquipmentItem(
      id: 'reg',
      name: 'Apeks XTX',
      type: EquipmentType.regulator,
      createdAt: DateTime.utc(2026),
    );

    /// The check-in surface at '/', with the real form on the route a row
    /// pushes, so saving returns to the row that started it.
    Future<void> pumpRouted(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          GoRoute(
            path: '/incidents/new',
            builder: (_, state) => IncidentEditPage(
              observationId: state.uri.queryParameters['observationId'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
            equipmentObservationRepositoryProvider.overrideWithValue(
              observations,
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

    testWidgets('the sheet stays open and shows the new link', (tester) async {
      final observation = await checkIn(note: 'At 28 m');
      await pumpRouted(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showEquipmentObservationSheet(context, equipment: reg),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log near-miss'));
      await tester.pumpAndSettle();
      expect(find.text('Gear check-in'), findsOneWidget);

      await save(tester);

      expect((await saved()).observationId, observation.id);
      expect(find.text('Check-in: Apeks XTX'), findsOneWidget);
      expect(find.text('Near-miss linked'), findsOneWidget);
      expect(find.text('Log near-miss'), findsNothing);
    });

    testWidgets('the item card offers it on an issue and not on an OK check', (
      tester,
    ) async {
      await checkIn(note: 'At 28 m');
      await checkIn(status: ObservationStatus.ok);
      await pumpRouted(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: ObservationsCard(equipment: reg)),
        ),
      );

      expect(find.text('Log near-miss'), findsOneWidget);
    });
  });

  testWidgets('the log says when a report has a check-in', (tester) async {
    final observation = await checkIn();
    await incidents.createIncident(
      occurredAt: DateTime.utc(2026, 3, 1),
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.minor,
      narrative: 'Free flow',
      equipmentId: 'reg',
      observationId: observation.id,
    );

    await pumpPage(tester, const IncidentsListPage());

    expect(find.textContaining('Linked to a check-in'), findsOneWidget);
  });
}
