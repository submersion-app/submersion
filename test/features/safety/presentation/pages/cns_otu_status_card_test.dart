import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/pages/cns_otu_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  const units = UnitFormatter(AppSettings());
  final lastDive = Dive(
    id: 'dive-1',
    dateTime: DateTime.utc(2026, 7, 17, 10),
    entryTime: DateTime.utc(2026, 7, 17, 10),
    diveNumber: 42,
    name: 'Blue Hole',
  );

  Future<void> pumpCard(WidgetTester tester, CnsOtuSnapshot? snapshot) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveProvider.overrideWith((ref, id) async => lastDive),
          diveTypesProvider.overrideWith(
            (ref) async => const <DiveTypeEntity>[],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CnsOtuStatusCard(snapshot: snapshot, units: units),
          ),
        ),
      ),
    );
    // diveProvider resolves asynchronously; let _LastDiveHeader's second
    // build (with data) land before assertions run.
    await tester.pump();
  }

  CnsOtuSnapshot snapshotOf({
    required DateTime lastDiveEnd,
    required O2Exposure? exposure,
    double dailyOtu = 0.0,
    double weeklyOtu = 0.0,
    DateTime? computedAt,
  }) => CnsOtuSnapshot(
    lastDiveId: 'dive-1',
    lastDiveEnd: lastDiveEnd,
    exposure: exposure,
    dailyOtu: dailyOtu,
    weeklyOtu: weeklyOtu,
    computedAt: computedAt ?? NoFlyService.wallClockNowUtc(),
  );

  testWidgets('shows no active load without a snapshot', (tester) async {
    await pumpCard(tester, null);
    expect(find.text('No active load'), findsOneWidget);
  });

  testWidgets('shows no active load once CNS and OTU have both cleared', (
    tester,
  ) async {
    final lastDiveEnd = NoFlyService.wallClockNowUtc().subtract(
      const Duration(hours: 30),
    );
    await pumpCard(
      tester,
      snapshotOf(
        lastDiveEnd: lastDiveEnd,
        exposure: const O2Exposure(cnsEnd: 40.0),
        weeklyOtu: 0.0,
      ),
    );
    expect(find.text('No active load'), findsOneWidget);
  });

  testWidgets('shows the live CNS/OTU card for a recent dive', (tester) async {
    final lastDiveEnd = NoFlyService.wallClockNowUtc().subtract(
      const Duration(minutes: 30),
    );
    await pumpCard(
      tester,
      snapshotOf(
        lastDiveEnd: lastDiveEnd,
        exposure: const O2Exposure(cnsEnd: 40.0, otu: 20.0),
        weeklyOtu: 50.0,
      ),
    );

    expect(find.text('No active load'), findsNothing);
    expect(find.textContaining('Oxygen Toxicity'), findsOneWidget);
    // "This dive"/"this-dive" wording would wrongly imply a dive in
    // progress; the card must use the "last dive" phrasing instead.
    expect(find.textContaining('this dive'), findsNothing);
    expect(find.textContaining('Before last dive'), findsOneWidget);
    expect(find.textContaining('Last dive:'), findsOneWidget);
    expect(find.text('Last Dive'), findsOneWidget);
    // Identifies which dive this live readout is projected from.
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets(
    'the "last dive" CNS delta stays at the dive\'s own value as CNS decays, '
    'not shrinking toward 0',
    (tester) async {
      // cnsStart 10, cnsEnd 50 -> the dive itself added 40 points. Long
      // enough ago that live CNS has decayed well below that 40-point delta,
      // so a delta re-derived from the LIVE value would read lower than 40.
      final lastDiveEnd = NoFlyService.wallClockNowUtc().subtract(
        const Duration(hours: 3),
      );
      await pumpCard(
        tester,
        snapshotOf(
          lastDiveEnd: lastDiveEnd,
          exposure: const O2Exposure(cnsStart: 10.0, cnsEnd: 50.0),
          weeklyOtu: 0.0,
        ),
      );

      expect(find.textContaining('Last dive: +40.0%'), findsOneWidget);
    },
  );

  testWidgets(
    'daily OTU resets to 0 once "now" is a later calendar day than the '
    'totals, instead of showing yesterday\'s near-limit total',
    (tester) async {
      final now = NoFlyService.wallClockNowUtc();
      // Yesterday: guaranteed a different calendar day from "now"
      // regardless of the time this test happens to run.
      final yesterday = DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(hours: 1));
      await pumpCard(
        tester,
        snapshotOf(
          lastDiveEnd: yesterday,
          exposure: const O2Exposure(otuStart: 230.0, otu: 20.0),
          dailyOtu: 250.0,
          // weeklyOtu alone keeps the card in its active state so the daily
          // row is actually rendered to check.
          weeklyOtu: 250.0,
          computedAt: yesterday,
        ),
      );

      expect(find.textContaining('0 / 300 OTU (0%)'), findsOneWidget);
      expect(find.textContaining('250 / 300 OTU'), findsNothing);
    },
  );

  testWidgets('the daily row shows today\'s total from the snapshot', (
    tester,
  ) async {
    await pumpCard(
      tester,
      snapshotOf(
        lastDiveEnd: NoFlyService.wallClockNowUtc().subtract(
          const Duration(minutes: 30),
        ),
        // The dive's own-day total (otuStart + otu) is not today's.
        exposure: const O2Exposure(otuStart: 200.0, otu: 20.0),
        dailyOtu: 45.0,
        weeklyOtu: 220.0,
      ),
    );

    expect(find.textContaining('45 / 300 OTU (15%)'), findsOneWidget);
  });

  testWidgets('a multi-day gap reads in days and hours', (tester) async {
    await pumpCard(
      tester,
      snapshotOf(
        lastDiveEnd: NoFlyService.wallClockNowUtc().subtract(
          const Duration(days: 3, hours: 4, minutes: 30),
        ),
        exposure: const O2Exposure(otu: 20.0),
        weeklyOtu: 200.0,
      ),
    );

    expect(find.text('Last dive ended 3d 4h ago'), findsOneWidget);
  });

  group('last dive without a profile', () {
    testWidgets('warns and shows the known OTU totals', (tester) async {
      await pumpCard(
        tester,
        snapshotOf(
          lastDiveEnd: NoFlyService.wallClockNowUtc().subtract(
            const Duration(hours: 2),
          ),
          exposure: null,
          dailyOtu: 30.0,
          weeklyOtu: 120.0,
        ),
      );

      expect(find.text('Last dive has no profile'), findsOneWidget);
      expect(find.text('No active load'), findsNothing);
      expect(find.textContaining('30 / 300 OTU'), findsOneWidget);
      expect(find.textContaining('120 / 850 OTU'), findsOneWidget);
      // CNS is unknown, so no CNS reading is offered at all.
      expect(find.text('CNS Oxygen Clock'), findsNothing);
      expect(find.text('#42'), findsOneWidget);
    });

    testWidgets('warns even with zero known totals', (tester) async {
      await pumpCard(
        tester,
        snapshotOf(
          lastDiveEnd: NoFlyService.wallClockNowUtc().subtract(
            const Duration(days: 6),
          ),
          exposure: null,
        ),
      );

      expect(find.text('Last dive has no profile'), findsOneWidget);
    });

    testWidgets('reads as clear once the dive is out of the weekly window', (
      tester,
    ) async {
      await pumpCard(
        tester,
        snapshotOf(
          lastDiveEnd: NoFlyService.wallClockNowUtc().subtract(
            const Duration(days: 7, minutes: 1),
          ),
          exposure: null,
        ),
      );

      expect(find.text('Last dive has no profile'), findsNothing);
      expect(find.text('No active load'), findsOneWidget);
    });
  });

  testWidgets('a weekly OTU carryover alone counts as an active load', (
    tester,
  ) async {
    // The last dive itself added no CNS/OTU, but a 7-day rolling total from
    // earlier dives is still above the daily/weekly limits worth tracking.
    final lastDiveEnd = NoFlyService.wallClockNowUtc().subtract(
      const Duration(hours: 10),
    );
    await pumpCard(
      tester,
      snapshotOf(
        lastDiveEnd: lastDiveEnd,
        exposure: const O2Exposure(cnsEnd: 0.0, otu: 0.0),
        weeklyOtu: 200.0,
      ),
    );

    expect(find.text('No active load'), findsNothing);
    expect(find.textContaining('Oxygen Toxicity'), findsOneWidget);
  });
}
