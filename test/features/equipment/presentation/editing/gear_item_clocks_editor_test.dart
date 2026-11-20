import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_clocks_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Service clocks and Service history cards of a gear item page that
/// edits in place (issue #4527, phase 3, plan 6).
void main() {
  final l = AppLocalizationsEn();
  final at = DateTime(2026, 1, 1);
  const apex = EquipmentItem(
    id: 'g1',
    name: 'Apex',
    type: EquipmentType.regulator,
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
    await ServiceRecordRepository().createRecord(
      ServiceRecord(
        id: 'r1',
        equipmentId: 'g1',
        serviceCategory: ServiceCategory.annual,
        serviceKindId: 'k-annual',
        serviceDate: DateTime(2025, 6, 1),
        createdAt: at,
        updatedAt: at,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    // A progress bar waiting for a read never settles.
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  EditSession<EquipmentItem> sitting() {
    final session = EditSession(apex);
    addTearDown(session.dispose);
    return session;
  }

  Future<List<ServiceSchedule>> storedClocks() =>
      ServiceScheduleRepository().getSchedulesForEquipment('g1');

  group('the clocks editor', () {
    testWidgets('pausing a clock holds it, with the changed dot, and writes '
        'nothing', (tester) async {
      final session = sitting();
      await pump(tester, GearItemClocksEditor(session: session));

      await tester.tap(find.byKey(const ValueKey('gear-clock-menu-s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.equipment_serviceClocks_pause));
      await tester.pumpAndSettle();

      expect(gearItemClocksList.current(session)!.single.enabled, isFalse);
      expect(find.byType(RecordChangedDot), findsOneWidget);
      expect(find.text(l.equipment_serviceClocks_paused), findsOneWidget);
      expect((await storedClocks()).single.enabled, isTrue);
    });

    testWidgets('removing a clock holds it and writes nothing', (tester) async {
      final session = sitting();
      await pump(tester, GearItemClocksEditor(session: session));

      await tester.tap(find.byKey(const ValueKey('gear-clock-menu-s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.equipment_serviceClocks_remove));
      await tester.pumpAndSettle();

      expect(gearItemClocksList.current(session), isEmpty);
      expect(await storedClocks(), hasLength(1));
      expect(session.changedCardIds, {'serviceClocks'});
    });

    testWidgets('the kind picker leaves out kinds the sitting attached', (
      tester,
    ) async {
      final session = sitting();
      await pump(tester, GearItemClocksEditor(session: session));

      await tester.tap(find.byKey(const ValueKey('gear-clocks-add')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Yearly reg check'),
        ),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Hose swap'),
        ),
      );
      await tester.pumpAndSettle();

      expect(gearItemClocksList.current(session)!.map((s) => s.serviceKindId), [
        'k-annual',
        'k-o2',
      ]);
      expect(await storedClocks(), hasLength(1));
    });

    testWidgets('a clocks read that failed says so and offers to read '
        'again', (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement('DROP TABLE service_schedules');
      final session = sitting();
      await pump(tester, GearItemClocksEditor(session: session));

      expect(gearItemClocksList.failed(session), isTrue);
      expect(find.byType(SittingLoadFailed), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Log service waits for the service records, which it is held '
        'among', (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement('DROP TABLE service_records');
      final session = sitting();
      await pump(tester, GearItemClocksEditor(session: session));

      expect(gearItemServiceRecordsList.failed(session), isTrue);
      expect(find.byType(SittingLoadFailed), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gear-clock-menu-s1')));
      await tester.pumpAndSettle();
      final log = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text(l.equipment_serviceClocks_logService),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(log.enabled, isFalse);
    });

    testWidgets('custom reminder days are the Service clocks card\'s change', (
      tester,
    ) async {
      final session = sitting();
      await pump(tester, GearItemClocksEditor(session: session));

      await tester.tap(find.byKey(const ValueKey('gear-reminders-custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gear-reminders-day-14')));
      await tester.pumpAndSettle();

      expect(session.working.customReminderEnabled, isTrue);
      expect(session.working.customReminderDays, [7, 30]);
      expect(session.changedCardIds, {'serviceClocks'});
    });
  });

  group('the clocks card on a page that edits in place', () {
    testWidgets('locked, it offers no clock and no clock menu', (tester) async {
      await pump(tester, const ServiceClocksCard(equipmentId: 'g1'));

      expect(find.text(l.equipment_serviceClocks_addClock), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('a set custom reminder shows a row', (tester) async {
      await pump(
        tester,
        const ServiceClocksCard(
          equipmentId: 'g1',
          customReminder: (enabled: true, days: [30, 7]),
        ),
      );

      expect(
        find.text(l.equipment_serviceClocks_remindersOwn('7 days, 30 days')),
        findsOneWidget,
      );
    });

    testWidgets('reminders turned off say so; following the settings shows '
        'nothing', (tester) async {
      await pump(
        tester,
        const ServiceClocksCard(
          equipmentId: 'g1',
          customReminder: (enabled: false, days: null),
        ),
      );
      expect(find.text(l.equipment_serviceClocks_remindersOff), findsOneWidget);

      await pump(
        tester,
        const ServiceClocksCard(
          equipmentId: 'g1',
          customReminder: (enabled: null, days: null),
        ),
      );
      expect(
        find.byKey(const ValueKey('service-clocks-reminders')),
        findsNothing,
      );
    });
  });

  group('the service history in a sitting', () {
    testWidgets('a delete asks nothing and is held until Save', (tester) async {
      final session = sitting();
      await gearItemServiceRecordsList.load(session);
      await pump(
        tester,
        ServiceHistorySection(equipmentId: 'g1', editing: session),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.equipment_service_deleteMenuItem));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(gearItemServiceRecordsList.current(session), isEmpty);
      expect(
        await ServiceRecordRepository().getRecordsForEquipment('g1'),
        hasLength(1),
      );
    });

    testWidgets('in a sitting nothing is offered until the records are read', (
      tester,
    ) async {
      // Not loaded: the read has not been asked for.
      final session = sitting();
      await pump(
        tester,
        ServiceHistorySection(equipmentId: 'g1', editing: session),
        settle: false,
      );

      expect(find.text(l.equipment_service_addButton), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('locked, it offers no Add and its records open nothing', (
      tester,
    ) async {
      await pump(tester, const ServiceHistorySection(equipmentId: 'g1'));

      expect(find.text(l.equipment_service_addButton), findsNothing);
      await tester.tap(find.text(l.equipment_service_historyTitle));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
