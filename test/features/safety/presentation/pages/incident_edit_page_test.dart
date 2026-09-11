import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/pages/incident_edit_page.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Records the create/update/delete calls the edit form makes and loads a
/// fixed result (or throws) for `getIncidentById`, so every page path can be
/// exercised without a database.
class _FakeIncidentRepository extends IncidentRepository {
  _FakeIncidentRepository({this.result, this.error});

  final Incident? result;
  final Object? error;

  Incident? created;
  Incident? updated;
  String? deletedId;

  @override
  Future<Incident?> getIncidentById(String id) async {
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<Incident> createIncident({
    required DateTime occurredAt,
    required IncidentCategory category,
    required IncidentSeverity severity,
    required String narrative,
    String? contributingFactors,
    String? lessonsLearned,
    String? diveId,
    String? diverId,
    String? equipmentId,
  }) async {
    final incident = Incident(
      id: 'created-id',
      diverId: diverId,
      diveId: diveId,
      equipmentId: equipmentId,
      occurredAt: occurredAt,
      category: category,
      severity: severity,
      narrative: narrative,
      contributingFactors: contributingFactors,
      lessonsLearned: lessonsLearned,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );
    created = incident;
    return incident;
  }

  @override
  Future<void> updateIncident(Incident incident) async {
    updated = incident;
  }

  @override
  Future<void> deleteIncident(String id) async {
    deletedId = id;
  }
}

void main() {
  Incident existingIncident() => Incident(
    id: 'i1',
    occurredAt: DateTime.utc(2026, 7, 10),
    category: IncidentCategory.gasSupply,
    severity: IncidentSeverity.moderate,
    narrative: 'Free-flow at 18 m; switched to buddy octo.',
    contributingFactors: 'Cold water.',
    lessonsLearned: 'Service the reg.',
    createdAt: DateTime.utc(2026, 7, 10),
    updatedAt: DateTime.utc(2026, 7, 10),
  );

  // A GoRouter that lands directly on the edit page but keeps a list page
  // beneath it, so the page's post-save `context.pop()` has somewhere to go.
  // The route location is irrelevant to the page (it reads the widget's
  // constructor args, not the path params), so both new and edit variants
  // reuse the same '/incidents/new' leaf.
  GoRouter routerFor(Widget editPage) => GoRouter(
    initialLocation: '/incidents/new',
    routes: [
      GoRoute(
        path: '/incidents',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LIST'))),
        routes: [GoRoute(path: 'new', builder: (context, state) => editPage)],
      ),
    ],
  );

  void useTallSurface(WidgetTester tester) {
    // Tall surface so the whole form (incl. the Save button below the fold in a
    // default viewport) is laid out and hittable without scrolling.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpEdit(
    WidgetTester tester,
    _FakeIncidentRepository repo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: const IncidentEditPage(incidentId: 'missing'),
        ),
      ),
    );
    await tester.pump(); // resolve the getIncidentById future
    await tester.pump();
  }

  testWidgets('missing record shows not-found, never the create form', (
    tester,
  ) async {
    await pumpEdit(tester, _FakeIncidentRepository(result: null));

    // Not-found copy is shown and the editable form (Save button) is not, so
    // Save can never silently create a new record under an "Edit" title.
    expect(find.text('Near-miss report not found'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('read error surfaces a message instead of a stuck spinner', (
    tester,
  ) async {
    await pumpEdit(
      tester,
      _FakeIncidentRepository(error: Exception('db read failed')),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('empty narrative shows the required message, not a blank error', (
    tester,
  ) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incidentRepositoryProvider.overrideWithValue(
            _FakeIncidentRepository(),
          ),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: const IncidentEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Save a new report with the (required) narrative left blank.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(find.text('Describe what happened'), findsOneWidget);
  });

  testWidgets('loads an existing incident into the edit form', (tester) async {
    useTallSurface(tester);
    final repo = _FakeIncidentRepository(result: existingIncident());

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        router: routerFor(const IncidentEditPage(incidentId: 'i1')),
      ),
    );
    await tester.pumpAndSettle();

    // Edit title, delete affordance, and the record's fields are populated.
    expect(find.text('Edit near-miss'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(
      find.text('Free-flow at 18 m; switched to buddy octo.'),
      findsOneWidget,
    );
    expect(find.text('Cold water.'), findsOneWidget);
    expect(find.text('Service the reg.'), findsOneWidget);
  });

  testWidgets('editing and saving calls updateIncident and pops', (
    tester,
  ) async {
    useTallSurface(tester);
    final repo = _FakeIncidentRepository(result: existingIncident());

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        router: routerFor(const IncidentEditPage(incidentId: 'i1')),
      ),
    );
    await tester.pumpAndSettle();

    // Change the category (chip) and severity (segmented button).
    await tester.tap(find.text('Equipment'));
    await tester.pump();
    await tester.tap(find.text('Serious'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.updated, isNotNull);
    expect(repo.updated!.category, IncidentCategory.equipment);
    expect(repo.updated!.severity, IncidentSeverity.serious);
    expect(repo.created, isNull);
    // Popped back to the list route.
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets(
    'creating a new incident calls createIncident with the active diver',
    (tester) async {
      useTallSurface(tester);
      final repo = _FakeIncidentRepository();
      // The raw id names a diver that no longer exists; the validated one
      // (what the gear picker and the incident list read) has fallen back.
      final diver = MockCurrentDiverIdNotifier();
      await diver.setCurrentDiver('deleted-diver');

      await tester.pumpWidget(
        testAppRouter(
          locale: const Locale('en'),
          overrides: [
            incidentRepositoryProvider.overrideWithValue(repo),
            currentDiverIdProvider.overrideWith((ref) => diver),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-1',
            ),
          ],
          router: routerFor(const IncidentEditPage(diveId: 'dive-9')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Ran low on gas on the safety stop.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.created, isNotNull);
      expect(repo.created!.narrative, 'Ran low on gas on the safety stop.');
      expect(repo.created!.diverId, 'diver-1');
      expect(repo.created!.diveId, 'dive-9');
      // The default occurred-at is a timezone-stable wall-clock UTC date.
      expect(repo.created!.occurredAt.isUtc, isTrue);
      expect(repo.updated, isNull);
      expect(find.text('LIST'), findsOneWidget);
    },
  );

  testWidgets('delete confirmation removes the incident and pops', (
    tester,
  ) async {
    useTallSurface(tester);
    final repo = _FakeIncidentRepository(result: existingIncident());

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        router: routerFor(const IncidentEditPage(incidentId: 'i1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this near-miss report?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deletedId, 'i1');
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('cancelling the date picker leaves the date unchanged', (
    tester,
  ) async {
    useTallSurface(tester);
    final repo = _FakeIncidentRepository(result: existingIncident());

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        router: routerFor(const IncidentEditPage(incidentId: 'i1')),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the date row by its leading icon so the test does not depend on the
    // locale/timezone of the formatted subtitle.
    await tester.tap(find.byIcon(Icons.event));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('cancelling the delete dialog keeps the incident', (
    tester,
  ) async {
    useTallSurface(tester);
    final repo = _FakeIncidentRepository(result: existingIncident());

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        router: routerFor(const IncidentEditPage(incidentId: 'i1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Dismiss via Cancel: nothing is deleted and the form stays put.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deletedId, isNull);
    expect(find.text('Edit near-miss'), findsOneWidget);
  });

  testWidgets(
    'the equipment picker lists the dive gear first and preselects the category',
    (tester) async {
      useTallSurface(tester);
      final repo = _FakeIncidentRepository();
      final reg = EquipmentItem(
        id: 'reg',
        name: 'Apeks XTX',
        type: EquipmentType.regulator,
        createdAt: DateTime.utc(2026),
      );
      final fins = EquipmentItem(
        id: 'fins',
        name: 'Jet Fins',
        type: EquipmentType.fins,
        createdAt: DateTime.utc(2026),
      );
      final dive = Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 10),
        gear: [GearLink(item: reg)],
      );

      await tester.pumpWidget(
        testAppRouter(
          locale: const Locale('en'),
          overrides: [
            incidentRepositoryProvider.overrideWithValue(repo),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
            diveProvider('d1').overrideWith((ref) async => dive),
            activeEquipmentProvider.overrideWith((ref) async => [reg, fins]),
            equipmentItemProvider('reg').overrideWith((ref) async => reg),
          ],
          router: routerFor(const IncidentEditPage(diveId: 'd1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Equipment involved'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      await tester.tap(find.text('Equipment involved'));
      await tester.pumpAndSettle();
      expect(find.text('On this dive'), findsOneWidget);
      expect(find.text('All gear'), findsOneWidget);
      // The dive's regulator is listed under the dive header only; the
      // full list carries the rest of the active gear.
      expect(find.text('Apeks XTX'), findsOneWidget);
      expect(find.text('Jet Fins'), findsOneWidget);

      await tester.tap(find.text('Apeks XTX'));
      await tester.pumpAndSettle();
      expect(find.text('Apeks XTX'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Equipment'),
      );
      expect(chip.selected, isTrue);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Second stage free-flowed at depth.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repo.created!.equipmentId, 'reg');
      expect(repo.created!.category, IncidentCategory.equipment);
    },
  );

  testWidgets('a cylinder linked to a gear item is listed on the dive', (
    tester,
  ) async {
    // The registry links a cylinder through the tank, not the dive's gear
    // junction, and the item can be retired (so absent from the active
    // list). It still belongs under the dive header, once.
    useTallSurface(tester);
    final repo = _FakeIncidentRepository();
    final reg = EquipmentItem(
      id: 'reg',
      name: 'Apeks XTX',
      type: EquipmentType.regulator,
      createdAt: DateTime.utc(2026),
    );
    final cylinder = EquipmentItem(
      id: 'cyl',
      name: 'Blue AL80',
      type: EquipmentType.tank,
      isActive: false,
      createdAt: DateTime.utc(2026),
    );
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 7, 10),
      gear: [GearLink(item: reg)],
      tanks: const [
        DiveTank(id: 't1', equipmentId: 'cyl'),
        DiveTank(id: 't2', equipmentId: 'cyl'),
        // Also in the dive's gear: listed once, not twice.
        DiveTank(id: 't3', equipmentId: 'reg'),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [
          incidentRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          diveProvider('d1').overrideWith((ref) async => dive),
          activeEquipmentProvider.overrideWith((ref) async => [reg]),
          equipmentItemProvider('cyl').overrideWith((ref) async => cylinder),
          equipmentItemProvider('reg').overrideWith((ref) async => reg),
        ],
        router: routerFor(const IncidentEditPage(diveId: 'd1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipment involved'));
    await tester.pumpAndSettle();

    expect(find.text('On this dive'), findsOneWidget);
    expect(find.text('Blue AL80'), findsOneWidget);
    expect(find.text('Apeks XTX'), findsOneWidget);
    // Everything active is already listed above, so no empty header.
    expect(find.text('All gear'), findsNothing);

    await tester.tap(find.text('Blue AL80'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Tank valve stuck half open.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(repo.created!.equipmentId, 'cyl');
  });

  testWidgets('a category chosen by hand survives picking an item', (
    tester,
  ) async {
    useTallSurface(tester);
    final repo = _FakeIncidentRepository();
    final fins = EquipmentItem(
      id: 'fins',
      name: 'Jet Fins',
      type: EquipmentType.fins,
      createdAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [
          incidentRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          activeEquipmentProvider.overrideWith((ref) async => [fins]),
        ],
        router: routerFor(const IncidentEditPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buoyancy'));
    await tester.pump();
    await tester.tap(find.text('Equipment involved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jet Fins'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Buoyancy'),
    );
    expect(chip.selected, isTrue);
  });
  group('queues the named gear for a findings refresh', () {
    late List<Set<String>> requests;
    final fins = EquipmentItem(
      id: 'fins',
      name: 'Jet Fins',
      type: EquipmentType.fins,
      createdAt: DateTime.utc(2026),
    );

    setUp(() {
      requests = [];
      SensorSummaryScheduler.instance.findingsRequestListener = requests.add;
    });
    tearDown(
      () => SensorSummaryScheduler.instance.findingsRequestListener = null,
    );

    Future<_FakeIncidentRepository> openSaved(WidgetTester tester) async {
      useTallSurface(tester);
      final repo = _FakeIncidentRepository(
        result: existingIncident().copyWith(equipmentId: 'reg'),
      );
      await tester.pumpWidget(
        testAppRouter(
          locale: const Locale('en'),
          overrides: [
            incidentRepositoryProvider.overrideWithValue(repo),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            activeEquipmentProvider.overrideWith((ref) async => [fins]),
          ],
          router: routerFor(const IncidentEditPage(incidentId: 'i1')),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('moving an incident to another item refreshes both', (
      tester,
    ) async {
      await openSaved(tester);
      await tester.tap(find.text('Equipment involved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jet Fins'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(requests, [
        {'reg', 'fins'},
      ]);
    });

    testWidgets('deleting an incident refreshes its item', (tester) async {
      await openSaved(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(requests, [
        {'reg'},
      ]);
    });
  });

  testWidgets('a saved category survives picking an item on edit', (
    tester,
  ) async {
    // The stored category was the diver's choice when they saved it, so
    // naming an item later must not flip it to Equipment.
    useTallSurface(tester);
    final repo = _FakeIncidentRepository(result: existingIncident());
    final fins = EquipmentItem(
      id: 'fins',
      name: 'Jet Fins',
      type: EquipmentType.fins,
      createdAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [
          incidentRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          activeEquipmentProvider.overrideWith((ref) async => [fins]),
        ],
        router: routerFor(const IncidentEditPage(incidentId: 'i1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipment involved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jet Fins'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Equipment'),
    );
    expect(chip.selected, isFalse);
  });
}
