import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/gauge_strip.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _t0 = DateTime(2026, 1, 1);

/// Records where a chip tap navigated.
class NavSpy {
  String? location;
}

const _emptyGauges = DashboardGauges(
  gearGauges: [],
  hasGear: true,
  insurance: null,
  noFlyStatus: null,
  daysSinceLastDive: null,
);

Future<NavSpy> pumpStrip(
  WidgetTester tester,
  DashboardGauges gauges, {
  MockSettingsNotifier? settingsNotifier,
}) async {
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  final spy = NavSpy();
  Widget stub(String path) => Builder(
    builder: (context) {
      spy.location = path;
      return const Scaffold();
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: GaugeStrip()),
      ),
      GoRoute(path: '/gear', builder: (_, _) => stub('/gear')),
      GoRoute(
        path: '/certifications',
        builder: (_, _) => stub('/certifications'),
      ),
      GoRoute(path: '/trips', builder: (_, _) => stub('/trips')),
      GoRoute(path: '/courses', builder: (_, _) => stub('/courses')),
      GoRoute(
        path: '/pre-dive-sessions/:id',
        builder: (_, state) =>
            stub('/pre-dive-sessions/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (_, _) => stub('/settings/backup'),
      ),
      GoRoute(
        path: '/settings/data-quality',
        builder: (_, _) => stub('/settings/data-quality'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        dashboardGaugesProvider.overrideWith((ref) async => gauges),
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return spy;
}

/// Taps the chip whose label is [label] and settles.
Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  );
  await tester.pumpAndSettle();
}

GearGauge _gearGauge(
  String name,
  EquipmentType type,
  ServiceClockSeverity severity, {
  DateTime? dueDate,
}) => GearGauge(
  type: type,
  itemName: name,
  status: ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 'schedule',
      equipmentId: 'equipment',
      serviceKindId: 'kind',
      createdAt: _t0,
      updatedAt: _t0,
    ),
    kind: ServiceKind(
      id: 'kind',
      name: 'Annual service',
      createdAt: _t0,
      updatedAt: _t0,
    ),
    anchor: _t0,
    dueDate: dueDate,
    severity: severity,
    now: DateTime.now(),
  ),
);

Trip _trip(String name, int daysFromNow) {
  final start = DateTime.now().add(Duration(days: daysFromNow));
  return Trip(
    id: name,
    name: name,
    startDate: start,
    endDate: start.add(const Duration(days: 7)),
    createdAt: _t0,
    updatedAt: _t0,
  );
}

ActiveCourseProgress _course(String name, int satisfied, int total) {
  final requirements = [
    for (var i = 0; i < total; i++)
      CourseRequirementProgress(
        requirement: CourseRequirement(
          id: 'r$i',
          courseId: 'c1',
          name: 'Requirement $i',
          kind: RequirementKind.checklist,
          completedAt: i < satisfied ? _t0 : null,
          createdAt: _t0,
          updatedAt: _t0,
        ),
        linkedDives: const [],
      ),
  ];
  return (
    course: Course(
      id: 'c1',
      diverId: 'd1',
      name: name,
      agency: CertificationAgency.padi,
      startDate: _t0,
      createdAt: _t0,
      updatedAt: _t0,
    ),
    progress: CourseProgress(courseId: 'c1', requirements: requirements),
  );
}

void main() {
  group('gear chips', () {
    testWidgets('no gear registered shows an add-gear chip that navigates', (
      tester,
    ) async {
      final spy = await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: false,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: 12,
        ),
      );
      expect(find.text('Add gear'), findsOneWidget);
      await tapChip(tester, 'Add gear');
      expect(spy.location, '/gear');
    });

    testWidgets('overdue, due-soon and ok gear render their own labels', (
      tester,
    ) async {
      final spy = await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge(
              'Regulator',
              EquipmentType.regulator,
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
            _gearGauge(
              'BCD',
              EquipmentType.bcd,
              ServiceClockSeverity.dueSoon,
              // daysUntilDue truncates, so add slack to land on exactly 20.
              dueDate: DateTime.now().add(const Duration(days: 20, hours: 1)),
            ),
            _gearGauge(
              'Teric',
              EquipmentType.computer,
              ServiceClockSeverity.ok,
            ),
          ],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('Regulator overdue'), findsOneWidget);
      expect(find.text('BCD due in 20d'), findsOneWidget);
      expect(find.text('Teric OK'), findsOneWidget);
      expect(find.text('Add gear'), findsNothing);

      await tapChip(tester, 'Regulator overdue');
      expect(spy.location, '/gear');
    });

    testWidgets('due-soon clock without a due date falls back to 0 days', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge('BCD', EquipmentType.bcd, ServiceClockSeverity.dueSoon),
          ],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('BCD due in 0d'), findsOneWidget);
    });
  });

  group('insurance chip', () {
    testWidgets('missing insurance', (tester) async {
      await pumpStrip(tester, _emptyGauges);
      expect(find.text('No insurance on file'), findsOneWidget);
    });

    testWidgets('insurance without an expiry date reads as missing', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: DiverInsurance(provider: 'DAN'),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('No insurance on file'), findsOneWidget);
    });

    testWidgets('expired insurance', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: DiverInsurance(
            provider: 'DAN',
            expiryDate: DateTime.now().subtract(const Duration(days: 5)),
          ),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('Insurance expired'), findsOneWidget);
    });

    testWidgets('insurance expiring soon shows the date', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: DiverInsurance(
            provider: 'DAN',
            expiryDate: DateTime.now().add(const Duration(days: 10)),
          ),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.textContaining('Insurance expires'), findsOneWidget);
    });

    testWidgets('valid insurance', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: DiverInsurance(
            provider: 'DAN',
            expiryDate: DateTime.now().add(const Duration(days: 300)),
          ),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('Insurance OK'), findsOneWidget);
    });
  });

  group('no-fly chip', () {
    testWidgets('clear when no restriction is active', (tester) async {
      await pumpStrip(tester, _emptyGauges);
      expect(find.text('No-fly 0:00'), findsOneWidget);
    });

    testWidgets('shows remaining time while active', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: NoFlyStatus(
            until: DateTime.now().toUtc().add(
              const Duration(hours: 5, minutes: 30),
            ),
            category: NoFlyCategory.single,
            interval: const Duration(hours: 12),
          ),
          daysSinceLastDive: null,
        ),
      );
      expect(find.textContaining('No-fly 5:'), findsOneWidget);
    });

    testWidgets('an elapsed snapshot reads as clear', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: NoFlyStatus(
            until: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
            category: NoFlyCategory.single,
            interval: const Duration(hours: 12),
          ),
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('No-fly 0:00'), findsOneWidget);
    });
  });

  group('dive currency chip', () {
    Future<void> pumpDays(WidgetTester tester, int? days) => pumpStrip(
      tester,
      DashboardGauges(
        gearGauges: const [],
        hasGear: true,
        insurance: null,
        noFlyStatus: null,
        daysSinceLastDive: days,
      ),
    );

    testWidgets('no dives yet', (tester) async {
      await pumpDays(tester, null);
      expect(find.text('No dives yet'), findsOneWidget);
    });

    testWidgets('dove today', (tester) async {
      await pumpDays(tester, 0);
      expect(find.text('Dove today'), findsOneWidget);
    });

    testWidgets('recent dive stays neutral', (tester) async {
      await pumpDays(tester, 12);
      expect(find.text('Last dive 12d ago'), findsOneWidget);
    });

    testWidgets('past the warn threshold', (tester) async {
      await pumpDays(tester, kCurrencyWarnDays + 1);
      expect(find.text('Last dive 181d ago'), findsOneWidget);
    });

    testWidgets('past the alert threshold', (tester) async {
      await pumpDays(tester, kCurrencyAlertDays + 1);
      expect(find.text('Last dive 366d ago'), findsOneWidget);
    });
  });

  group('attention chips', () {
    testWidgets('certifications chip navigates', (tester) async {
      final spy = await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          expiringCertCount: 2,
        ),
      );
      expect(find.text('2 certifications expiring'), findsOneWidget);
      await tapChip(tester, '2 certifications expiring');
      expect(spy.location, '/certifications');
    });

    testWidgets('trip chip navigates', (tester) async {
      final spy = await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          nextTrip: _trip('Bonaire', 12),
        ),
      );
      expect(find.textContaining('Bonaire in'), findsOneWidget);
      await tapChip(
        tester,
        find
            .textContaining('Bonaire in')
            .evaluate()
            .map((e) => (e.widget as Text).data!)
            .first,
      );
      expect(spy.location, '/trips');
    });

    testWidgets('checklist chip opens the active session', (tester) async {
      final spy = await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          activeChecklistId: 'session-7',
        ),
      );
      expect(find.text('Checklist in progress'), findsOneWidget);
      await tapChip(tester, 'Checklist in progress');
      expect(spy.location, '/pre-dive-sessions/session-7');
    });

    testWidgets('course chip navigates', (tester) async {
      final spy = await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          firstCourse: _course('AN/DP', 7, 12),
        ),
      );
      expect(find.text('AN/DP: 7/12'), findsOneWidget);
      await tapChip(tester, 'AN/DP: 7/12');
      expect(spy.location, '/courses');
    });

    testWidgets('uploads chip appears only with pending transfers', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          uploadsPending: 3,
        ),
      );
      expect(find.text('3 uploads pending'), findsOneWidget);
    });

    testWidgets('data quality chip navigates', (tester) async {
      final spy = await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          dataQualityFindings: 4,
        ),
      );
      expect(find.text('4 data issues'), findsOneWidget);
      await tapChip(tester, '4 data issues');
      expect(spy.location, '/settings/data-quality');
    });

    testWidgets('event chips stay hidden when they have no data', (
      tester,
    ) async {
      await pumpStrip(tester, _emptyGauges);
      expect(find.textContaining('certifications expiring'), findsNothing);
      expect(find.text('Checklist in progress'), findsNothing);
      expect(find.textContaining('uploads pending'), findsNothing);
      expect(find.textContaining('data issues'), findsNothing);
    });
  });

  group('backup chip', () {
    testWidgets('no backup yet navigates to backup settings', (tester) async {
      final spy = await pumpStrip(tester, _emptyGauges);
      expect(find.text('No backup yet'), findsOneWidget);
      await tapChip(tester, 'No backup yet');
      expect(spy.location, '/settings/backup');
    });

    testWidgets('backed up today', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          lastBackupTime: DateTime.now(),
        ),
      );
      expect(find.text('Backed up today'), findsOneWidget);
    });

    testWidgets('ageing backup reports days', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          lastBackupTime: DateTime.now().subtract(
            const Duration(days: kBackupAlertDays + 1),
          ),
        ),
      );
      expect(find.text('Backup ${kBackupAlertDays + 1}d ago'), findsOneWidget);
    });
  });

  group('sync chip', () {
    testWidgets('hidden when no backend is configured', (tester) async {
      await pumpStrip(tester, _emptyGauges);
      expect(find.text('Synced'), findsNothing);
    });

    testWidgets('synced when nothing is pending', (tester) async {
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          syncEnabled: true,
        ),
      );
      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('reports pending records', (tester) async {
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          syncEnabled: true,
          syncPending: 5,
        ),
      );
      expect(find.text('5 unsynced'), findsOneWidget);
    });
  });

  group('visibility settings', () {
    testWidgets('hidden chip types are not rendered', (tester) async {
      final settingsNotifier = MockSettingsNotifier();
      await settingsNotifier.setHomeChipEnabled('noFly', false);
      await settingsNotifier.setHomeChipEnabled('gear', false);
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: false,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: 12,
        ),
        settingsNotifier: settingsNotifier,
      );
      expect(find.text('No-fly 0:00'), findsNothing);
      expect(find.text('Add gear'), findsNothing);
      expect(find.text('Last dive 12d ago'), findsOneWidget);
    });

    testWidgets('hiding every chip type collapses the strip', (tester) async {
      final settingsNotifier = MockSettingsNotifier();
      for (final type in HomeChipType.values) {
        await settingsNotifier.setHomeChipEnabled(type.name, false);
      }
      await pumpStrip(tester, _emptyGauges, settingsNotifier: settingsNotifier);
      expect(find.byType(Wrap), findsNothing);
    });
  });

  group('async states', () {
    testWidgets('reserves height while loading', (tester) async {
      final overrides = await getBaseOverrides();
      final completer = Completer<DashboardGauges>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            dashboardGaugesProvider.overrideWith((ref) => completer.future),
          ].cast(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: GaugeStrip()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Wrap), findsNothing);
      expect(tester.getSize(find.byType(SizedBox).first).height, 40);

      completer.complete(_emptyGauges);
      await tester.pumpAndSettle();
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('error shows a retry chip that refetches', (tester) async {
      final overrides = await getBaseOverrides();
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            dashboardGaugesProvider.overrideWith((ref) async {
              attempts++;
              if (attempts == 1) throw StateError('boom');
              return _emptyGauges;
            }),
          ].cast(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: GaugeStrip()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status unavailable - tap to retry'), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('No dives yet'), findsOneWidget);
    });
  });
}
