import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/service_clock_snapshot_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The closed Service clocks card while the page's sitting holds clock
/// changes (issue #5042).
void main() {
  final l = AppLocalizationsEn();
  final at = DateTime(2026, 1, 1);
  const apex = EquipmentItem(
    id: 'g1',
    name: 'Apex',
    type: EquipmentType.regulator,
  );
  final annual = ServiceKind(
    id: 'k-annual',
    name: 'Yearly reg check',
    defaultIntervalDays: 365,
    createdAt: at,
    updatedAt: at,
  );
  final hoses = ServiceKind(
    id: 'k-o2',
    name: 'Hose swap',
    defaultIntervalDays: 730,
    createdAt: at,
    updatedAt: at,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await db.customStatement(
      "INSERT INTO service_kinds (id, name, default_interval_days, "
      "created_at, updated_at) VALUES "
      "('k-annual', 'Yearly reg check', 365, 0, 0), "
      "('k-o2', 'Hose swap', 730, 0, 0)",
    );
    await EquipmentRepository().createEquipment(apex);
    await db.customStatement('DELETE FROM service_schedules');
    await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: 's1',
        equipmentId: 'g1',
        serviceKindId: 'k-annual',
        createdAt: at,
        updatedAt: at,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  ServiceSchedule clock(String id, String kindId) => ServiceSchedule(
    id: id,
    equipmentId: 'g1',
    serviceKindId: kindId,
    createdAt: at,
    updatedAt: at,
  );

  /// A snapshot whose verdicts are one ok clock per enabled schedule, due a
  /// year on, so the rows it draws can be told from unconfigured ones.
  ServiceClockSnapshot snapshotOf(List<ServiceSchedule> schedules) =>
      ServiceClockSnapshot(
        schedules: schedules,
        records: const [],
        evaluate: (schedules, records) => [
          for (final s in schedules)
            if (s.enabled)
              ServiceClockStatus(
                schedule: s,
                kind: s.serviceKindId == hoses.id ? hoses : annual,
                anchor: at,
                dueDate: DateTime(2027, 1, 1),
                severity: ServiceClockSeverity.ok,
                now: at,
              ),
        ],
      );

  /// The sitting with the stored clock removed and a hose swap added.
  Future<EditSession<EquipmentItem>> sittingWithHeldClocks() async {
    final session = EditSession(apex);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    await gearItemClocksList.load(session);
    removeHeldClock(session, 's1');
    holdClock(session, clock('', 'k-o2'));
    return session;
  }

  Future<void> pump(
    WidgetTester tester,
    ValueNotifier<EditSession<EquipmentItem>?> shown, {
    ServiceClockSnapshot? Function()? snapshot,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast(),
          if (snapshot != null)
            serviceClockSnapshotProvider(
              'g1',
            ).overrideWith((ref) async => snapshot()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder(
                valueListenable: shown,
                builder: (context, session, _) =>
                    ServiceClocksCard(equipmentId: 'g1', shown: session),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder dueRow(String kindName) =>
      find.ancestor(of: find.text(kindName), matching: find.byType(ListTile));

  testWidgets('a closed card shows the clocks the sitting holds, evaluated, '
      'not the stored ones', (tester) async {
    final session = await sittingWithHeldClocks();
    await pump(tester, ValueNotifier(session));

    expect(find.text('Yearly reg check'), findsNothing);
    expect(find.text('Hose swap'), findsOneWidget);
    // The added clock is evaluated as held, not drawn as unconfigured.
    expect(find.text(l.equipment_serviceClocks_unconfigured), findsNothing);
    expect(
      find.descendant(
        of: dueRow('Hose swap'),
        matching: find.textContaining('Due '),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a closed card without a sitting shows the stored clocks', (
    tester,
  ) async {
    await pump(tester, ValueNotifier(null));

    expect(find.text('Yearly reg check'), findsOneWidget);
    expect(find.text('Hose swap'), findsNothing);
  });

  testWidgets('the rows and their verdicts come from one read, so a schedule '
      'list read later is not drawn beside older verdicts', (tester) async {
    // The schedule list alone has already moved on; the snapshot has not.
    await pump(
      tester,
      ValueNotifier(null),
      snapshot: () => snapshotOf([clock('s1', 'k-annual')]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServiceClocksCard)),
    );
    expect(
      await container.read(serviceSchedulesForEquipmentProvider('g1').future),
      hasLength(1),
    );
    await ServiceScheduleRepository().createSchedule(clock('s2', 'k-o2'));
    await tester.pumpAndSettle();

    expect(find.text('Yearly reg check'), findsOneWidget);
    expect(find.text('Hose swap'), findsNothing);
    expect(find.text(l.equipment_serviceClocks_unconfigured), findsNothing);
  });

  testWidgets('once the sitting ends the card shows the stored clocks', (
    tester,
  ) async {
    final session = await sittingWithHeldClocks();
    final shown = ValueNotifier<EditSession<EquipmentItem>?>(session);
    addTearDown(shown.dispose);
    await pump(
      tester,
      shown,
      snapshot: () => snapshotOf([clock('s1', 'k-annual')]),
    );
    expect(find.text('Hose swap'), findsOneWidget);

    session.dispose();
    shown.value = null;
    await tester.pump();
    expect(find.text('Yearly reg check'), findsOneWidget);
    expect(find.text('Hose swap'), findsNothing);
  });

  testWidgets('a read that fails after one that worked is said, not hidden '
      'behind the earlier clocks', (tester) async {
    var fail = false;
    await pump(
      tester,
      ValueNotifier(null),
      snapshot: () {
        if (fail) throw StateError('database is locked');
        return snapshotOf([clock('s1', 'k-annual')]);
      },
    );
    expect(find.text('Yearly reg check'), findsOneWidget);

    fail = true;
    ProviderScope.containerOf(
      tester.element(find.byType(ServiceClocksCard)),
    ).invalidate(serviceClockSnapshotProvider('g1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('database is locked'), findsOneWidget);
    expect(find.text('Yearly reg check'), findsNothing);
  });

  testWidgets('an item not yet created lists its held clocks without a '
      'verdict, not as unconfigured', (tester) async {
    const fresh = EquipmentItem(
      id: 'new',
      name: 'New reg',
      type: EquipmentType.regulator,
    );
    final session = EditSession(fresh, isNew: true);
    addTearDown(session.dispose);
    gearItemClocksList.loadNone(session);
    await tester.pump();
    holdClock(
      session,
      ServiceSchedule(
        id: '',
        equipmentId: 'new',
        serviceKindId: 'k-o2',
        createdAt: at,
        updatedAt: at,
      ),
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast(),
          serviceClockSnapshotProvider('new').overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceClocksCard(equipmentId: 'new', shown: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hose swap'), findsOneWidget);
    expect(find.text(l.equipment_serviceClocks_unconfigured), findsNothing);
    expect(find.text(l.equipment_serviceClocks_empty), findsNothing);
  });
}
