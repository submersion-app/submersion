import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';

Certification _cert(DateTime? issueDate, {String name = 'Open Water'}) =>
    Certification(
      id: name,
      name: name,
      agency: CertificationAgency.padi,
      issueDate: issueDate,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('nextDiveMilestone', () {
    test('ladder below 1000', () {
      expect(nextDiveMilestone(0), isNull);
      expect(nextDiveMilestone(1), 10);
      expect(nextDiveMilestone(10), 25);
      expect(nextDiveMilestone(247), 250);
      expect(nextDiveMilestone(999), 1000);
    });

    test('every 500 above 1000', () {
      expect(nextDiveMilestone(1000), 1500);
      expect(nextDiveMilestone(1501), 2000);
    });
  });

  group('upcomingAnniversaries', () {
    test('includes anniversary within window, computes years', () {
      final result = upcomingAnniversaries(
        [_cert(DateTime(2016, 8, 10))],
        DateTime(2026, 7, 24),
        windowDays: 60,
      );
      expect(result.single.years, 10);
      expect(result.single.date, DateTime(2026, 8, 10));
      expect(result.single.certName, 'Open Water');
    });

    test('excludes anniversary outside window', () {
      final result = upcomingAnniversaries(
        [_cert(DateTime(2016, 12, 25))],
        DateTime(2026, 7, 24),
        windowDays: 60,
      );
      expect(result, isEmpty);
    });

    test('anniversary earlier this year rolls to next year', () {
      final result = upcomingAnniversaries(
        [_cert(DateTime(2020, 1, 5))],
        DateTime(2026, 12, 20),
        windowDays: 60,
      );
      expect(result.single.date, DateTime(2027, 1, 5));
      expect(result.single.years, 7);
    });

    test('null issueDate ignored', () {
      expect(
        upcomingAnniversaries([_cert(null)], DateTime(2026, 7, 24)),
        isEmpty,
      );
    });

    test('sorted by soonest anniversary first', () {
      final result = upcomingAnniversaries(
        [
          _cert(DateTime(2020, 9, 1), name: 'Rescue'),
          _cert(DateTime(2018, 8, 1), name: 'AOW'),
        ],
        DateTime(2026, 7, 24),
        windowDays: 60,
      );
      expect(result.first.certName, 'AOW');
    });
  });

  group('milestonesProvider', () {
    late ProviderContainer container;
    var totalDives = 0;
    var certs = <Certification>[];

    setUp(() {
      container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          certificationListNotifierProvider.overrideWith(
            (ref) => _FakeCertificationListNotifier(AsyncValue.data(certs)),
          ),
          diveStatisticsProvider.overrideWith(
            (ref) async => DiveStatistics(
              totalDives: totalDives,
              totalTimeSeconds: 0,
              maxDepth: 0,
              avgMaxDepth: 0,
              totalSites: 0,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('computes the next milestone and remaining dives', () async {
      totalDives = 247;
      final milestones = await container.read(milestonesProvider.future);

      expect(milestones.nextMilestone, 250);
      expect(milestones.divesRemaining, 3);
      expect(milestones.isEmpty, isFalse);
    });

    test('is empty for a diver with no dives and no certifications', () async {
      totalDives = 0;
      certs = [];
      final milestones = await container.read(milestonesProvider.future);

      expect(milestones.nextMilestone, isNull);
      expect(milestones.divesRemaining, isNull);
      expect(milestones.anniversaries, isEmpty);
      expect(milestones.isEmpty, isTrue);
    });

    test('carries upcoming certification anniversaries through', () async {
      final now = DateTime.now();
      totalDives = 0;
      // Issue date exactly 10 years ago today: the next anniversary is today
      // (0 days out, inside the window) and the year count is always 10,
      // whatever calendar day the test runs on.
      certs = [
        _cert(DateTime(now.year - 10, now.month, now.day), name: 'Open Water'),
      ];
      final milestones = await container.read(milestonesProvider.future);

      expect(milestones.anniversaries.single.certName, 'Open Water');
      expect(milestones.anniversaries.single.years, 10);
      expect(milestones.isEmpty, isFalse);
    });
  });
}

/// Stands in for the real notifier, which loads from the database in its
/// constructor. noSuchMethod forwarding satisfies the interface without
/// implementing setters the provider under test never calls.
class _FakeCertificationListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _FakeCertificationListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
