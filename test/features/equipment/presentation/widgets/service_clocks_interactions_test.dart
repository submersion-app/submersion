import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// End-to-end interactions on [ServiceClocksCard] against the real test
/// database: the kind-picker sheet, pause/resume/remove menu actions, and
/// the interval-override dialog all execute their real repository paths.
void main() {
  late SharedPreferences prefs;
  late EquipmentRepository equipmentRepo;
  late ServiceScheduleRepository scheduleRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    equipmentRepo = EquipmentRepository();
    scheduleRepo = ServiceScheduleRepository();

    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Widget buildCard(
    String equipmentId, {
    EquipmentType type = EquipmentType.tank,
    void Function(ServiceClockStatus)? onLogService,
  }) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceClocksCard(
              equipmentId: equipmentId,
              equipmentType: type,
              onLogService: onLogService,
            ),
          ),
        ),
      ),
    );
  }

  Future<EquipmentItem> makeTank(WidgetTester tester) async {
    late EquipmentItem tank;
    await tester.runAsync(() async {
      tank = await equipmentRepo.createEquipment(
        const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
      );
    });
    return tank;
  }

  Future<void> openMenu(WidgetTester tester, String kindName) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, kindName),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('picker sheet attaches a new clock through the repository', (
    tester,
  ) async {
    final tank = await makeTank(tester);
    await tester.pumpWidget(buildCard(tank.id));
    await tester.pumpAndSettle();

    expect(find.text('Hydrostatic test'), findsOneWidget);
    expect(find.text('O2 clean'), findsNothing);

    await tester.tap(find.text('Add clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O2 clean'));
    await tester.pumpAndSettle();

    // The new clock renders and the schedule row exists in the DB.
    expect(find.text('O2 clean'), findsOneWidget);
    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      expect(schedules.map((s) => s.serviceKindId), contains('o2-clean'));
    });
  });

  testWidgets('pause moves a clock to the paused section; resume restores it', (
    tester,
  ) async {
    final tank = await makeTank(tester);
    await tester.pumpWidget(buildCard(tank.id));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Visual inspection (VIP)');
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final vip = schedules.firstWhere((s) => s.serviceKindId == 'vip');
      expect(vip.enabled, isFalse);
    });

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsNothing);
    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final vip = schedules.firstWhere((s) => s.serviceKindId == 'vip');
      expect(vip.enabled, isTrue);
    });
  });

  testWidgets('remove deletes the schedule row', (tester) async {
    final tank = await makeTank(tester);
    await tester.pumpWidget(buildCard(tank.id));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Visual inspection (VIP)');
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Visual inspection (VIP)'), findsNothing);
    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      expect(schedules.map((s) => s.serviceKindId), isNot(contains('vip')));
    });
  });

  testWidgets('log service menu action hands the clock to the callback', (
    tester,
  ) async {
    final tank = await makeTank(tester);
    final logged = <ServiceClockStatus>[];
    await tester.pumpWidget(buildCard(tank.id, onLogService: logged.add));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Hydrostatic test');
    await tester.tap(find.text('Log service'));
    await tester.pumpAndSettle();

    expect(logged, hasLength(1));
    expect(logged.single.kind.id, 'hydro');
  });

  testWidgets('override dialog saves intervals and anchor date', (
    tester,
  ) async {
    final tank = await makeTank(tester);
    await tester.pumpWidget(buildCard(tank.id));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Hydrostatic test');
    await tester.tap(find.text('Edit intervals'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Interval (days)'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Interval (dives)'),
      '50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Interval (hours)'),
      '2.5',
    );

    // Pick today as the baseline date via the material date picker.
    await tester.tap(find.text('Baseline date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
      expect(hydro.intervalDays, 100);
      expect(hydro.intervalDives, 50);
      expect(hydro.intervalHours, 2.5);
      expect(hydro.anchorDate, isNotNull);
    });

    // The card now renders the usage triggers alongside the date trigger.
    expect(find.textContaining('of 50 dives left'), findsOneWidget);
    expect(find.textContaining('of 2.5 hours left'), findsOneWidget);
  });

  testWidgets('override dialog clear button nulls the anchor date', (
    tester,
  ) async {
    final tank = await makeTank(tester);
    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
      await scheduleRepo.updateSchedule(
        hydro.copyWith(anchorDate: DateTime(2024, 6, 1)),
      );
    });
    await tester.pumpWidget(buildCard(tank.id));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Hydrostatic test');
    await tester.tap(find.text('Edit intervals'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear baseline date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final schedules = await scheduleRepo.getSchedulesForEquipment(tank.id);
      final hydro = schedules.firstWhere((s) => s.serviceKindId == 'hydro');
      expect(hydro.anchorDate, isNull);
    });
  });

  testWidgets('edit dialog shows kind default hints for usage intervals', (
    tester,
  ) async {
    late EquipmentItem reg;
    await tester.runAsync(() async {
      reg = await equipmentRepo.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'XTX50',
          type: EquipmentType.regulator,
        ),
      );
    });
    await tester.pumpWidget(buildCard(reg.id, type: EquipmentType.regulator));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Regulator service');
    await tester.tap(find.text('Edit intervals'));
    await tester.pumpAndSettle();

    // Regulator service defaults: 365 days OR 100 dives -> both hints.
    expect(find.text('Default: 365'), findsOneWidget);
    expect(find.text('Default: 100'), findsOneWidget);
  });

  testWidgets('picker manage tile navigates to the service types page', (
    tester,
  ) async {
    final tank = await makeTank(tester);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: ServiceClocksCard(
                equipmentId: tank.id,
                equipmentType: EquipmentType.tank,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/service-types',
          builder: (_, _) => const Scaffold(body: Text('MANAGE_TYPES_PAGE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage service types'));
    await tester.pumpAndSettle();

    expect(find.text('MANAGE_TYPES_PAGE'), findsOneWidget);
  });

  testWidgets('item with no applicable kinds shows the empty state', (
    tester,
  ) async {
    late EquipmentItem fins;
    await tester.runAsync(() async {
      fins = await equipmentRepo.createEquipment(
        const EquipmentItem(id: '', name: 'Fins', type: EquipmentType.fins),
      );
    });
    await tester.pumpWidget(buildCard(fins.id, type: EquipmentType.fins));
    await tester.pumpAndSettle();

    expect(find.text('No service clocks'), findsOneWidget);
  });
}
