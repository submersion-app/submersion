import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

import '../../../../helpers/test_database.dart';

/// Tests for [weeklyOtuProvider]'s rolling 7-day window.
///
/// Regression coverage for issue #407: the weekly OTU "Prior" for the earliest
/// dive in the log was showing OTU borrowed from a dive logged LATER the same
/// day. The rolling total must only include the current dive and dives that
/// occurred at or before it -- never dives that happened afterwards.
void main() {
  late DiveRepository repository;

  // Per-dive OTU contributions, stubbed via profileAnalysisProvider so these
  // tests exercise only the rolling-window selection, not the Buhlmann model.
  const earlierDiveOtu = 16.0;
  const laterDiveOtu = 29.0;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // Creates two dives on the SAME calendar day: the earlier at 09:19 and the
  // later at 11:24. Built with DateTime.utc because the day-window math inside
  // weeklyOtuProvider uses DateTime.utc and the repository round-trips
  // timestamps as UTC -- so the fixture is timezone-independent.
  Future<void> createTwoSameDayDives() async {
    await repository.createDive(
      Dive(
        id: 'dive-earlier',
        diveNumber: 43,
        dateTime: DateTime.utc(2025, 9, 8, 9, 19),
      ),
    );
    await repository.createDive(
      Dive(
        id: 'dive-later',
        diveNumber: 44,
        dateTime: DateTime.utc(2025, 9, 8, 11, 24),
      ),
    );
  }

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        profileAnalysisProvider('dive-earlier').overrideWith(
          (ref) async => ProfileAnalysis.empty().copyWith(
            o2Exposure: const O2Exposure(otu: earlierDiveOtu),
          ),
        ),
        profileAnalysisProvider('dive-later').overrideWith(
          (ref) async => ProfileAnalysis.empty().copyWith(
            o2Exposure: const O2Exposure(otu: laterDiveOtu),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('weeklyOtuProvider rolling 7-day window', () {
    test('earliest dive excludes OTU from a later same-day dive', () async {
      await createTwoSameDayDives();
      final container = buildContainer();

      final weekly = await container.read(
        weeklyOtuProvider('dive-earlier').future,
      );

      // The earliest dive in the log has no prior exposure, so its weekly
      // total is just its own OTU -- it must NOT be inflated by the dive that
      // was logged later the same day (issue #407).
      expect(weekly, equals(earlierDiveOtu));
    });

    test(
      'later dive includes the earlier same-day dive as prior exposure',
      () async {
        await createTwoSameDayDives();
        final container = buildContainer();

        final weekly = await container.read(
          weeklyOtuProvider('dive-later').future,
        );

        // Regression guard: a later dive SHOULD count an earlier dive's OTU
        // toward its rolling total (16 + 29).
        expect(weekly, equals(earlierDiveOtu + laterDiveOtu));
      },
    );
  });

  group('dives that cross midnight', () {
    // 23:30 to 00:20 with 100 OTU. The stubbed analysis has no OTU curve, so
    // the split falls back to elapsed time: 30 of its 50 minutes (60 OTU) on
    // the day it started, 20 minutes (40 OTU) on the next.
    const nightDiveOtu = 100.0;
    const morningDiveOtu = 10.0;

    ProviderContainer nightContainer() {
      final container = ProviderContainer(
        overrides: [
          profileAnalysisProvider('dive-night').overrideWith(
            (ref) async => ProfileAnalysis.empty().copyWith(
              o2Exposure: const O2Exposure(otu: nightDiveOtu),
            ),
          ),
          profileAnalysisProvider('dive-morning').overrideWith(
            (ref) async => ProfileAnalysis.empty().copyWith(
              o2Exposure: const O2Exposure(otu: morningDiveOtu),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> createNightDive(DateTime start) => repository.createDive(
      Dive(
        id: 'dive-night',
        diveNumber: 1,
        dateTime: start,
        entryTime: start,
        runtime: const Duration(minutes: 50),
      ),
    );

    test(
      'the next day\'s residual OTU counts the post-midnight part',
      () async {
        await createNightDive(DateTime.utc(2025, 9, 7, 23, 30));
        await repository.createDive(
          Dive(
            id: 'dive-morning',
            diveNumber: 2,
            dateTime: DateTime.utc(2025, 9, 8, 9),
          ),
        );
        final container = nightContainer();

        final residual = await container.read(
          residualOtuProvider('dive-morning').future,
        );

        expect(residual, closeTo(40.0, 1e-9));
      },
    );

    test('the weekly window counts only the part inside it', () async {
      // The 7-day window for a dive on 2025-09-08 opens at 2025-09-02 00:00;
      // this dive started the evening before and crossed into it.
      await createNightDive(DateTime.utc(2025, 9, 1, 23, 30));
      await repository.createDive(
        Dive(
          id: 'dive-morning',
          diveNumber: 2,
          dateTime: DateTime.utc(2025, 9, 8, 9),
        ),
      );
      final container = nightContainer();

      final weekly = await container.read(
        weeklyOtuProvider('dive-morning').future,
      );

      expect(weekly, closeTo(40.0 + morningDiveOtu, 1e-9));
    });
  });
}
