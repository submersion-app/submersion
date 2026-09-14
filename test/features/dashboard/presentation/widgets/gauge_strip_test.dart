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
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _t0 = DateTime(2026, 1, 1);

/// Records where a chip tap navigated, and exposes the router so tests can
/// assert that the destination was *stacked* over Home rather than replacing
/// it (`push` vs `go`).
class NavSpy {
  String? location;
  late final GoRouter router;
}

const _emptyGauges = DashboardGauges(
  gearGauges: [],
  hasGear: true,
  insurance: null,
  noFlyStatus: null,
  daysSinceLastDive: null,
);

/// Sync enabled, nothing pending: the state the sync chip renders as "Synced".
const _syncGauges = DashboardGauges(
  gearGauges: [],
  hasGear: true,
  insurance: null,
  noFlyStatus: null,
  daysSinceLastDive: null,
  syncEnabled: true,
);

/// Counts the syncs the chip asks for, without touching the database.
/// Only the members [runSyncNow] reaches are implemented; anything else
/// throws, which is the point -- the chip must not take another path.
class _RecordingSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _RecordingSyncNotifier(super.state);

  int syncCount = 0;

  @override
  Future<void> performSync({bool auto = false}) async => syncCount++;

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<NavSpy> pumpStrip(
  WidgetTester tester,
  DashboardGauges gauges, {
  MockSettingsNotifier? settingsNotifier,
  List<Override> extraOverrides = const [],
  ThemeData? theme,
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
      GoRoute(
        path: '/equipment',
        builder: (_, _) => stub('/equipment'),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => stub('/equipment/new')),
          GoRoute(
            path: ':equipmentId',
            builder: (_, state) =>
                stub('/equipment/${state.pathParameters['equipmentId']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/certifications',
        builder: (_, _) => stub('/certifications'),
      ),
      GoRoute(path: '/trips', builder: (_, _) => stub('/trips')),
      GoRoute(path: '/courses', builder: (_, _) => stub('/courses')),
      GoRoute(
        path: '/courses/:courseId',
        builder: (_, state) =>
            stub('/courses/${state.pathParameters['courseId']}'),
      ),
      GoRoute(path: '/dives', builder: (_, _) => stub('/dives')),
      GoRoute(
        path: '/pre-dive-sessions/:id',
        builder: (_, state) =>
            stub('/pre-dive-sessions/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/planning/no-fly',
        builder: (_, _) => stub('/planning/no-fly'),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (_, _) => stub('/settings/backup'),
      ),
      GoRoute(
        path: '/settings/cloud-sync',
        builder: (_, _) => stub('/settings/cloud-sync'),
      ),
      GoRoute(
        path: '/settings/media-storage/transfers',
        builder: (_, _) => stub('/settings/media-storage/transfers'),
      ),
      GoRoute(
        path: '/dives/quality',
        builder: (_, _) => stub('/dives/quality'),
      ),
      GoRoute(
        path: '/settings/diver-profile/insurance',
        builder: (_, _) => stub('/settings/diver-profile/insurance'),
      ),
    ],
  );
  spy.router = router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        dashboardGaugesProvider.overrideWith((ref) async => gauges),
        ...extraOverrides,
      ].cast(),
      child: MaterialApp.router(
        theme: theme,
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

/// Every chip label currently in the strip, in render order. The finder
/// walks the tree depth-first, which is the order the Wrap lays its
/// children out, so this is what the diver reads left to right.
List<String> chipLabels(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(Wrap), matching: find.byType(Text)),
    )
    .map((t) => t.data!)
    .toList();

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
  String? id,
}) => GearGauge(
  type: type,
  itemId: id ?? name,
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
      expect(spy.location, '/equipment/new');
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
              id: 'reg-1',
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

      // The chip names one item, so it must open that item rather than the
      // list the diver would then have to search (issue #816).
      await tapChip(tester, 'Regulator overdue');
      expect(spy.location, '/equipment/reg-1');
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
    testWidgets('missing insurance chip navigates to the insurance record', (
      tester,
    ) async {
      final spy = await pumpStrip(tester, _emptyGauges);
      expect(find.text('No insurance on file'), findsOneWidget);
      await tapChip(tester, 'No insurance on file');
      expect(spy.location, '/settings/diver-profile/insurance');
    });

    // Expiry is optional on InsuranceEditPage, so a DAN policy recorded
    // without a renewal date is a complete record, not a missing one. The
    // chip must agree with DiverInsurance.isValid, which keys off provider.
    testWidgets('a provider with no expiry date reads as insured', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: DiverInsurance(provider: 'DAN', policyNumber: '12345'),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('No insurance on file'), findsNothing);
      expect(find.text('Insurance OK'), findsOneWidget);
    });

    testWidgets('a blank provider still reads as missing', (tester) async {
      await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: DiverInsurance(provider: ''),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('No insurance on file'), findsOneWidget);
    });

    testWidgets('expired insurance chip navigates to the insurance record', (
      tester,
    ) async {
      final spy = await pumpStrip(
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
      await tapChip(tester, 'Insurance expired');
      expect(spy.location, '/settings/diver-profile/insurance');
    });

    testWidgets('expiring-soon insurance chip navigates to the record', (
      tester,
    ) async {
      final spy = await pumpStrip(
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
      // The label carries a formatted date, so match on its prefix.
      final chip = find.textContaining('Insurance expires');
      expect(chip, findsOneWidget);
      await tester.tap(find.ancestor(of: chip, matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(spy.location, '/settings/diver-profile/insurance');
    });

    testWidgets('valid insurance chip navigates to the insurance record', (
      tester,
    ) async {
      final spy = await pumpStrip(
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
      await tapChip(tester, 'Insurance OK');
      expect(spy.location, '/settings/diver-profile/insurance');
    });
  });

  group('no-fly chip', () {
    testWidgets('clear when no restriction is active', (tester) async {
      await pumpStrip(tester, _emptyGauges);
      expect(find.text('No-fly 0:00'), findsOneWidget);
    });

    testWidgets('the clear chip opens the no-fly calculator', (tester) async {
      final spy = await pumpStrip(tester, _emptyGauges);
      await tapChip(tester, 'No-fly 0:00');
      expect(spy.location, '/planning/no-fly');
    });

    testWidgets('the active chip opens the no-fly calculator', (tester) async {
      final spy = await pumpStrip(
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
      final chip = find.textContaining('No-fly 5:');
      await tester.tap(find.ancestor(of: chip, matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(spy.location, '/planning/no-fly');
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

  group('flight window chip', () {
    DashboardGauges gaugesWith(FlightWindowState state) => DashboardGauges(
      gearGauges: const [],
      hasGear: true,
      insurance: null,
      noFlyStatus: null,
      daysSinceLastDive: null,
      flightWindow: FlightWindowStatus(
        state: state,
        flightAt: DateTime.utc(2126, 8, 10, 9),
        deadline: DateTime.utc(2126, 8, 9, 15),
        category: NoFlyCategory.repetitive,
        interval: const Duration(hours: 18),
      ),
    );

    testWidgets('shows the dive window countdown while open', (tester) async {
      await pumpStrip(tester, gaugesWith(FlightWindowState.open));
      expect(find.textContaining('Dive window'), findsOneWidget);
    });

    testWidgets('shows the closed message past the deadline', (tester) async {
      await pumpStrip(tester, gaugesWith(FlightWindowState.closed));
      expect(find.text('No more diving before flight'), findsOneWidget);
    });

    testWidgets('the open chip opens the no-fly calculator', (tester) async {
      final spy = await pumpStrip(tester, gaugesWith(FlightWindowState.open));
      final chip = find.textContaining('Dive window');
      await tester.tap(find.ancestor(of: chip, matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(spy.location, '/planning/no-fly');
    });

    testWidgets('the closed chip opens the no-fly calculator', (tester) async {
      final spy = await pumpStrip(tester, gaugesWith(FlightWindowState.closed));
      await tapChip(tester, 'No more diving before flight');
      expect(spy.location, '/planning/no-fly');
    });

    testWidgets('shows the closed message on conflict', (tester) async {
      await pumpStrip(tester, gaugesWith(FlightWindowState.conflict));
      expect(find.text('No more diving before flight'), findsOneWidget);
    });

    testWidgets('absent when no flight window exists', (tester) async {
      await pumpStrip(tester, _emptyGauges);
      expect(find.textContaining('Dive window'), findsNothing);
      expect(find.text('No more diving before flight'), findsNothing);
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

    testWidgets('opens the dive log', (tester) async {
      final spy = await pumpStrip(
        tester,
        const DashboardGauges(
          gearGauges: [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: 12,
        ),
      );
      await tapChip(tester, 'Last dive 12d ago');
      expect(spy.location, '/dives');
    });

    testWidgets('the no-dives-yet chip also opens the dive log', (
      tester,
    ) async {
      final spy = await pumpStrip(tester, _emptyGauges);
      await tapChip(tester, 'No dives yet');
      expect(spy.location, '/dives');
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
      // The chip names one course, so it opens that course, not the list.
      expect(spy.location, '/courses/c1');
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

    testWidgets('uploads chip opens the transfer queue', (tester) async {
      final spy = await pumpStrip(
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
      await tapChip(tester, '3 uploads pending');
      expect(spy.location, '/settings/media-storage/transfers');
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
      expect(spy.location, '/dives/quality');
    });

    testWidgets('the data-issues chip is singular for a count of one', (
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
          dataQualityFindings: 1,
        ),
      );
      expect(find.text('1 data issue'), findsOneWidget);
      expect(find.text('1 data issues'), findsNothing);
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

    testWidgets('an existing backup also opens backup settings', (
      tester,
    ) async {
      final spy = await pumpStrip(
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
      await tapChip(tester, 'Backed up today');
      expect(spy.location, '/settings/backup');
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

    testWidgets('shows the syncing state while a sync runs', (tester) async {
      await pumpStrip(
        tester,
        _syncGauges,
        extraOverrides: [
          syncStateProvider.overrideWith(
            (ref) => _RecordingSyncNotifier(
              const SyncState(status: SyncStatus.syncing),
            ),
          ),
        ],
      );
      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.text('Synced'), findsNothing);
    });

    // Issue #990: the chip's job is the sync itself, so tapping runs one
    // rather than sending the user to a page to press another button.
    testWidgets('tapping runs a sync instead of navigating', (tester) async {
      final notifier = _RecordingSyncNotifier(const SyncState());
      final spy = await pumpStrip(
        tester,
        _syncGauges,
        extraOverrides: [syncStateProvider.overrideWith((ref) => notifier)],
      );

      await tapChip(tester, 'Synced');

      expect(notifier.syncCount, 1);
      expect(spy.location, isNull);
    });

    // Mid-sync the chip must not queue a second run, but it also must not go
    // inert via a no-op callback: that still announces a tap action to
    // assistive tech. It opens the page showing sync progress instead.
    testWidgets('a tap mid-sync opens progress, not a second run', (
      tester,
    ) async {
      final notifier = _RecordingSyncNotifier(
        const SyncState(status: SyncStatus.syncing),
      );
      final spy = await pumpStrip(
        tester,
        _syncGauges,
        extraOverrides: [syncStateProvider.overrideWith((ref) => notifier)],
      );

      await tapChip(tester, 'Syncing...');

      expect(notifier.syncCount, 0);
      expect(spy.location, '/settings/cloud-sync');
    });

    testWidgets('long-press still opens cloud sync settings', (tester) async {
      final notifier = _RecordingSyncNotifier(const SyncState());
      final spy = await pumpStrip(
        tester,
        _syncGauges,
        extraOverrides: [syncStateProvider.overrideWith((ref) => notifier)],
      );

      await tester.longPress(
        find.ancestor(of: find.text('Synced'), matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();

      expect(spy.location, '/settings/cloud-sync');
      expect(notifier.syncCount, 0);
    });
  });

  group('navigation semantics', () {
    // Every chip stacks its destination over Home so the back button returns
    // there; `go` would replace Home and leave nothing to pop.
    testWidgets('chip taps stack over Home so back returns', (tester) async {
      final spy = await pumpStrip(tester, _emptyGauges);
      expect(spy.router.canPop(), isFalse);
      await tapChip(tester, 'No-fly 0:00');
      expect(spy.location, '/planning/no-fly');
      expect(spy.router.canPop(), isTrue);
      spy.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GaugeStrip), findsOneWidget);
    });

    testWidgets('every rendered chip is tappable', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge('Reg', EquipmentType.regulator, ServiceClockSeverity.ok),
          ],
          hasGear: true,
          insurance: const DiverInsurance(provider: 'DAN'),
          noFlyStatus: null,
          daysSinceLastDive: 12,
          expiringCertCount: 2,
          nextTrip: _trip('Bonaire', 12),
          activeChecklistId: 'session-7',
          firstCourse: _course('AN/DP', 7, 12),
          uploadsPending: 3,
          lastBackupTime: DateTime.now(),
          syncEnabled: true,
          dataQualityFindings: 4,
        ),
      );
      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
      expect(inkWells, isNotEmpty);
      for (final ink in inkWells) {
        expect(ink.onTap, isNotNull);
      }
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

  group('tone colors', () {
    final gauges = DashboardGauges(
      gearGauges: [
        _gearGauge(
          'Reg',
          EquipmentType.regulator,
          ServiceClockSeverity.overdue,
        ),
        _gearGauge(
          'BCD',
          EquipmentType.bcd,
          ServiceClockSeverity.dueSoon,
          dueDate: DateTime.now().add(const Duration(days: 3)),
        ),
        _gearGauge('Fins', EquipmentType.fins, ServiceClockSeverity.ok),
      ],
      hasGear: true,
      insurance: null,
      noFlyStatus: null,
      daysSinceLastDive: 12,
    );

    /// The pill behind the chip whose label contains [text].
    BoxDecoration pill(WidgetTester tester, String text) {
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.textContaining(text),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    Color labelColor(WidgetTester tester, String text) =>
        tester.widget<Text>(find.textContaining(text)).style!.color!;

    void expectSwatch(WidgetTester tester, String text, StatusSwatch swatch) {
      final decoration = pill(tester, text);
      expect(decoration.color, swatch.container, reason: '$text fill');
      expect(
        (decoration.border! as Border).top.color,
        swatch.outline,
        reason: '$text outline',
      );
      expect(labelColor(tester, text), swatch.onContainer, reason: text);
    }

    testWidgets('gear severities use the light status palette', (tester) async {
      await pumpStrip(tester, gauges);

      expectSwatch(tester, 'Reg overdue', StatusColors.light.alert);
      expectSwatch(tester, 'BCD due in', StatusColors.light.warn);
      expectSwatch(tester, 'Fins OK', StatusColors.light.ok);
    });

    testWidgets('gear severities use the dark status palette', (tester) async {
      await pumpStrip(
        tester,
        gauges,
        theme: ThemeData(brightness: Brightness.dark),
      );

      expectSwatch(tester, 'Reg overdue', StatusColors.dark.alert);
      expectSwatch(tester, 'BCD due in', StatusColors.dark.warn);
      expectSwatch(tester, 'Fins OK', StatusColors.dark.ok);
    });

    testWidgets('a neutral chip is outlined and matches the others in size', (
      tester,
    ) async {
      await pumpStrip(tester, gauges);

      final neutral = pill(tester, 'Last dive');
      expect(neutral.border, isNotNull);
      // Neutral must not be the page color: the hand-built presets resolve
      // surfaceContainerHighest to their surface, which erased the pill.
      expect(neutral.color, isNot(ThemeData().colorScheme.surface));

      Size sizeOf(String text) => tester.getSize(
        find
            .ancestor(
              of: find.textContaining(text),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(sizeOf('Last dive').height, sizeOf('Reg overdue').height);

      // The outline must not grow the pill: Container folds the 1px border
      // into its padding, so 5px inset + 1px border matches the old 6px
      // inset exactly (and 11 + 1 matches the old 12 across).
      final row = tester.getSize(
        find
            .ancestor(
              of: find.textContaining('Reg overdue'),
              matching: find.byType(Row),
            )
            .first,
      );
      expect(sizeOf('Reg overdue'), Size(row.width + 24, row.height + 12));
    });
  });

  group('alert ordering', () {
    testWidgets('alert chips lead, everything else keeps source order', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge(
              'Teric',
              EquipmentType.computer,
              ServiceClockSeverity.ok,
            ),
            _gearGauge(
              'Regulator',
              EquipmentType.regulator,
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
          ],
          hasGear: true,
          insurance: const DiverInsurance(provider: 'DAN'),
          noFlyStatus: null,
          daysSinceLastDive: 12,
        ),
      );
      // The overdue regulator jumps the queue; every other chip, including
      // the warn-tone backup chip, stays in the order the strip declares.
      expect(chipLabels(tester), [
        'Regulator overdue',
        'Teric OK',
        'Insurance OK',
        'No-fly 0:00',
        'Last dive 12d ago',
        'No backup yet',
      ]);
    });

    testWidgets('several alerts keep their relative order', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge(
              'Regulator',
              EquipmentType.regulator,
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
          ],
          hasGear: true,
          insurance: DiverInsurance(
            provider: 'DAN',
            expiryDate: DateTime(2020, 1, 1),
          ),
          noFlyStatus: null,
          daysSinceLastDive: 12,
        ),
      );
      expect(chipLabels(tester).take(2), [
        'Regulator overdue',
        'Insurance expired',
      ]);
    });
  });

  group('hardened safety chips', () {
    /// Hides every chip type, so each test proves the chip renders purely
    /// because it is a hardened alert rather than because it slipped past.
    Future<MockSettingsNotifier> allHidden() async {
      final settingsNotifier = MockSettingsNotifier();
      for (final type in HomeChipType.values) {
        await settingsNotifier.setHomeChipEnabled(type.name, false);
      }
      return settingsNotifier;
    }

    testWidgets('overdue gear renders with gear chips hidden', (tester) async {
      final spy = await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge(
              'Regulator',
              EquipmentType.regulator,
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
              id: 'reg-1',
            ),
            _gearGauge(
              'BCD',
              EquipmentType.bcd,
              ServiceClockSeverity.dueSoon,
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
        settingsNotifier: await allHidden(),
      );
      // Only the lapsed item survives: due-soon and OK gear are ordinary
      // chips the diver is allowed to hide.
      expect(chipLabels(tester), ['Regulator overdue']);

      await tapChip(tester, 'Regulator overdue');
      expect(spy.location, '/equipment/reg-1');
    });

    testWidgets('expired insurance renders with insurance hidden', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: DiverInsurance(
            provider: 'DAN',
            expiryDate: DateTime(2020, 1, 1),
          ),
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
        settingsNotifier: await allHidden(),
      );
      expect(chipLabels(tester), ['Insurance expired']);
    });

    testWidgets('a valid policy still hides when insurance is hidden', (
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
        settingsNotifier: await allHidden(),
      );
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('a missing policy is not treated as an alert', (tester) async {
      // No insurance on file is a neutral chip, not a safety fact, so
      // hiding the type must silence it.
      await pumpStrip(
        tester,
        _emptyGauges,
        settingsNotifier: await allHidden(),
      );
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('a shut flight window renders with the type hidden', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          flightWindow: FlightWindowStatus(
            state: FlightWindowState.closed,
            flightAt: DateTime.utc(2126, 8, 10, 9),
            deadline: DateTime.utc(2126, 8, 9, 15),
            category: NoFlyCategory.repetitive,
            interval: const Duration(hours: 18),
          ),
        ),
        settingsNotifier: await allHidden(),
      );
      expect(chipLabels(tester), ['No more diving before flight']);
    });

    testWidgets('an open flight window still hides when the type is hidden', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
          flightWindow: FlightWindowStatus(
            state: FlightWindowState.open,
            flightAt: DateTime.utc(2126, 8, 10, 9),
            deadline: DateTime.utc(2126, 8, 9, 15),
            category: NoFlyCategory.repetitive,
            interval: const Duration(hours: 18),
          ),
        ),
        settingsNotifier: await allHidden(),
      );
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('red currency and backup chips stay hideable', (tester) async {
      // Both go alert-tone at these thresholds, and both are habit nags
      // rather than dive-safety gates, so hiding them must still work.
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: const [],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: 400,
          lastBackupTime: DateTime.now().subtract(const Duration(days: 45)),
        ),
        settingsNotifier: await allHidden(),
      );
      expect(find.byType(Wrap), findsNothing);
    });
  });

  group('overdue overflow chip', () {
    testWidgets('renders the count and opens the equipment list', (
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
          ],
          gearOverdueOverflow: 3,
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.text('+3 more overdue'), findsOneWidget);

      // It names no single item, so it falls back to the list.
      await tapChip(tester, '+3 more overdue');
      expect(spy.location, '/equipment');
    });

    testWidgets('is absent when nothing overflowed', (tester) async {
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge(
              'Regulator',
              EquipmentType.regulator,
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
          ],
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
      );
      expect(find.textContaining('more overdue'), findsNothing);
    });

    testWidgets('survives gear chips being hidden', (tester) async {
      final settingsNotifier = MockSettingsNotifier();
      await settingsNotifier.setHomeChipEnabled('gear', false);
      await pumpStrip(
        tester,
        DashboardGauges(
          gearGauges: [
            _gearGauge(
              'Regulator',
              EquipmentType.regulator,
              ServiceClockSeverity.overdue,
              dueDate: DateTime(2026, 6, 1),
            ),
          ],
          gearOverdueOverflow: 2,
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: null,
        ),
        settingsNotifier: settingsNotifier,
      );
      expect(find.text('+2 more overdue'), findsOneWidget);
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
