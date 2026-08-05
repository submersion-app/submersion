import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

final _t0 = DateTime(2026, 1, 1);

Trip _trip(String name, DateTime start) => Trip(
  id: name,
  name: name,
  startDate: start,
  endDate: start.add(const Duration(days: 5)),
  createdAt: _t0,
  updatedAt: _t0,
);

EquipmentClocks _clocks(String name, ServiceClockSeverity severity) => (
  item: EquipmentItem(id: name, name: name, type: EquipmentType.regulator),
  statuses: [
    ServiceClockStatus(
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
      dueDate: DateTime(2026, 8, 1),
      severity: severity,
      now: DateTime(2026, 7, 24),
    ),
  ],
);

ActiveCourseProgress _course(String name, int total) => (
  course: Course(
    id: 'c1',
    diverId: 'd1',
    name: name,
    agency: CertificationAgency.padi,
    startDate: _t0,
    createdAt: _t0,
    updatedAt: _t0,
  ),
  progress: CourseProgress(
    courseId: 'c1',
    requirements: [
      for (var i = 0; i < total; i++)
        CourseRequirementProgress(
          requirement: CourseRequirement(
            id: 'r$i',
            courseId: 'c1',
            name: 'Requirement $i',
            kind: RequirementKind.checklist,
            createdAt: _t0,
            updatedAt: _t0,
          ),
          linkedDives: const [],
        ),
    ],
  ),
);

ProviderContainer makeContainer({
  List<EquipmentClocks> clocks = const [],
  Diver? diver,
  NoFlyStatus? noFly,
  int? daysSinceLastDive,
  int certCount = 0,
  List<Trip> trips = const [],
  PreDiveSession? activeSession,
  List<ActiveCourseProgress> courses = const [],
  int uploads = 0,
  DateTime? lastBackup,
  bool syncEnabled = false,
  int syncPending = 0,
  int findings = 0,
}) {
  final container = ProviderContainer(
    overrides: [
      activeEquipmentClocksProvider.overrideWith((ref) async => clocks),
      currentDiverProvider.overrideWith((ref) async => diver),
      noFlyStatusProvider.overrideWith((ref) async => noFly),
      daysSinceLastDiveProvider.overrideWith((ref) async => daysSinceLastDive),
      expiringCertificationCountProvider.overrideWith((ref) async => certCount),
      allTripsProvider.overrideWith((ref) async => trips),
      preDiveActiveSessionProvider.overrideWith((ref) async => activeSession),
      activeCoursesProgressProvider.overrideWith((ref) async => courses),
      mediaTransferSummaryProvider.overrideWith(
        (ref) => Stream.value(MediaTransferSummary(queued: uploads)),
      ),
      lastBackupTimeProvider.overrideWithValue(lastBackup),
      isSyncEnabledProvider.overrideWithValue(syncEnabled),
      pendingChangesCountProvider.overrideWithValue(syncPending),
      openQualityFindingsCountProvider.overrideWith(
        (ref) => Stream.value(findings),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('nextUpcomingTrip', () {
    final now = DateTime(2026, 7, 24);

    test('picks the soonest future trip', () {
      final next = nextUpcomingTrip([
        _trip('Later', DateTime(2026, 10, 1)),
        _trip('Sooner', DateTime(2026, 8, 5)),
      ], now);
      expect(next?.name, 'Sooner');
    });

    test('ignores trips that already started', () {
      final next = nextUpcomingTrip([_trip('Past', DateTime(2026, 5, 1))], now);
      expect(next, isNull);
    });

    test('empty list yields null', () {
      expect(nextUpcomingTrip([], now), isNull);
    });
  });

  group('dashboardGaugesProvider', () {
    test('reports quiet defaults when nothing needs attention', () async {
      final container = makeContainer();
      final gauges = await container.read(dashboardGaugesProvider.future);

      expect(gauges.gearGauges, isEmpty);
      expect(gauges.hasGear, isFalse);
      expect(gauges.insurance, isNull);
      expect(gauges.nextTrip, isNull);
      expect(gauges.activeChecklistId, isNull);
      expect(gauges.firstCourse, isNull);
      expect(gauges.uploadsPending, 0);
      expect(gauges.lastBackupTime, isNull);
      expect(gauges.syncEnabled, isFalse);
      expect(gauges.dataQualityFindings, 0);
    });

    test('surfaces every attention source', () async {
      final backup = DateTime(2026, 7, 20);
      final container = makeContainer(
        clocks: [_clocks('Regulator', ServiceClockSeverity.overdue)],
        diver: Diver(
          id: 'd1',
          name: 'Eric',
          insurance: DiverInsurance(
            provider: 'DAN',
            expiryDate: DateTime(2027, 3, 1),
          ),
          createdAt: _t0,
          updatedAt: _t0,
        ),
        daysSinceLastDive: 12,
        certCount: 2,
        trips: [_trip('Bonaire', DateTime.now().add(const Duration(days: 12)))],
        courses: [_course('AN/DP', 12)],
        uploads: 3,
        lastBackup: backup,
        syncEnabled: true,
        syncPending: 5,
        findings: 4,
      );

      // The upload and data-quality counts arrive over streams. Hold a
      // listener (the findings provider is autoDispose) and let the first
      // events land so the provider recomputes with real values instead of
      // its loading fallback -- exactly how the live dashboard settles.
      final sub = container.listen(dashboardGaugesProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final gauges = await container.read(dashboardGaugesProvider.future);

      expect(gauges.hasGear, isTrue);
      expect(gauges.gearGauges.single.itemName, 'Regulator');
      expect(gauges.insurance?.provider, 'DAN');
      expect(gauges.daysSinceLastDive, 12);
      expect(gauges.expiringCertCount, 2);
      expect(gauges.nextTrip?.name, 'Bonaire');
      expect(gauges.firstCourse?.course.name, 'AN/DP');
      expect(gauges.uploadsPending, 3);
      expect(gauges.lastBackupTime, backup);
      expect(gauges.syncEnabled, isTrue);
      expect(gauges.syncPending, 5);
      expect(gauges.dataQualityFindings, 4);
    });

    test('skips courses that have no requirements', () async {
      final container = makeContainer(courses: [_course('Empty course', 0)]);
      final gauges = await container.read(dashboardGaugesProvider.future);
      expect(gauges.firstCourse, isNull);
    });

    test('gear gauges exclude clocks that are not due', () async {
      final container = makeContainer(
        clocks: [_clocks('Regulator', ServiceClockSeverity.ok)],
      );
      final gauges = await container.read(dashboardGaugesProvider.future);
      expect(gauges.hasGear, isTrue);
      expect(gauges.gearGauges, isEmpty);
    });
  });
}
