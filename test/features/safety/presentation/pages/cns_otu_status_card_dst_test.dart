import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/services/tissue_live_service.dart';
import 'package:submersion/features/safety/presentation/pages/cns_otu_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/dst_transition.dart';
import '../../../../helpers/mock_providers.dart';

/// Issue #3960: stored dive times are clock digits, so subtracting them from
/// the clock digits of "now" gains or loses an hour of recovery across a DST
/// change. These run under the process's own zone: the Test job's Sydney and
/// the Timezone Tests job's New York and Adelaide all have a change to sit
/// on. In a zone with no DST the two readings cannot differ.
void main() {
  const units = UnitFormatter(AppSettings());
  final lastDive = Dive(
    id: 'dive-1',
    dateTime: DateTime.utc(2027, 1, 1),
    diveNumber: 42,
    name: 'Blue Hole',
  );

  List<TissueCompartment> loadedCompartments() {
    final algorithm = BuhlmannAlgorithm();
    algorithm.calculateSegment(
      depthMeters: 30,
      durationSeconds: 40 * 60,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
    return algorithm.compartments;
  }

  /// Pumps the card with the clock fixed at [now], for a dive that truly
  /// ended at [diveEnd], stored the way the app stores it: as clock digits.
  Future<void> pumpAt(
    WidgetTester tester, {
    required DateTime now,
    required DateTime diveEnd,
    double cnsEnd = 100.0,
    double dailyOtu = 0.0,
    DateTime? computedAt,
    List<TissueCompartment>? compartments,
  }) => withClock(Clock.fixed(now.toLocal()), () async {
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
            body: SingleChildScrollView(
              child: CnsOtuStatusCard(
                snapshot: CnsOtuSnapshot(
                  lastDiveId: 'dive-1',
                  lastDiveEnd: asWallClockUtc(diveEnd.toLocal()),
                  exposure: O2Exposure(cnsEnd: cnsEnd),
                  dailyOtu: dailyOtu,
                  weeklyOtu: 0.0,
                  computedAt: computedAt ?? asWallClockUtc(now.toLocal()),
                  endOfDiveCompartments: compartments,
                ),
                units: units,
                gfLow: 0.30,
                gfHigh: 0.70,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  });

  double liveCns(WidgetTester tester) =>
      tester.widget<O2ToxicityCard>(find.byType(O2ToxicityCard)).liveCns!;

  void expectSameLoading(DecoStatus actual, DecoStatus expected) {
    for (var i = 0; i < expected.compartments.length; i++) {
      expect(
        actual.compartments[i].totalInertGas,
        closeTo(expected.compartments[i].totalInertGas, 1e-9),
        reason: 'compartment $i',
      );
    }
  }

  group('across the spring change', () {
    // 90 real minutes, but the clock digits are an hour further apart: in
    // New York 01:30 EST to 04:00 EDT reads as 150 minutes.
    late DateTime diveEnd;
    late DateTime now;

    setUp(() {
      final change = dstTransition(forward: true)!;
      diveEnd = change.subtract(const Duration(minutes: 30));
      now = change.add(const Duration(hours: 1));
    });

    testWidgets('decays CNS over the 90 minutes that really elapsed', (
      tester,
    ) async {
      await pumpAt(tester, now: now, diveEnd: diveEnd);

      expect(liveCns(tester), closeTo(50.0, 1e-6));
    }, skip: zoneHasNoDst);

    testWidgets('labels the real time since the dive', (tester) async {
      await pumpAt(tester, now: now, diveEnd: diveEnd);

      expect(find.textContaining('1h 30m'), findsOneWidget);
    }, skip: zoneHasNoDst);

    testWidgets('off-gasses tissues over the 90 minutes that really elapsed', (
      tester,
    ) async {
      final compartments = loadedCompartments();
      await pumpAt(
        tester,
        now: now,
        diveEnd: diveEnd,
        compartments: compartments,
      );

      final expected = TissueLiveService.currentStatus(
        endOfDiveCompartments: compartments,
        lastDiveEnd: diveEnd,
        now: now,
        gfLow: 0.30,
        gfHigh: 0.70,
      );
      final card = tester.widget<CompactTissueLoadingCard>(
        find.byType(CompactTissueLoadingCard),
      );
      expectSameLoading(card.status, expected);
      expectSameLoading(card.decoStatuses!.last, expected);
    }, skip: zoneHasNoDst);
  });

  group('across the autumn change', () {
    // 150 real minutes, but the clock digits are an hour closer: in New York
    // 00:30 EDT to 02:00 EST reads as 90 minutes. Both ends stay clear of the
    // repeated hour, whose digits could be either side of the change.
    late DateTime diveEnd;
    late DateTime now;

    setUp(() {
      final change = dstTransition(forward: false)!;
      diveEnd = change.subtract(const Duration(minutes: 90));
      now = change.add(const Duration(hours: 1));
    });

    testWidgets('decays CNS over the 150 minutes that really elapsed', (
      tester,
    ) async {
      await pumpAt(tester, now: now, diveEnd: diveEnd);

      expect(liveCns(tester), closeTo(31.498026, 1e-6));
    }, skip: zoneHasNoDst);

    testWidgets('labels the real time since the dive', (tester) async {
      await pumpAt(tester, now: now, diveEnd: diveEnd);

      expect(find.textContaining('2h 30m'), findsOneWidget);
    }, skip: zoneHasNoDst);
  });

  // Daily OTU keeps its calendar day: moving it onto true instants too would
  // shift the day boundary by the zone's UTC offset.
  testWidgets('daily OTU still follows the local calendar day', (tester) async {
    final lateEvening = DateTime(2027, 1, 15, 23, 30);
    await pumpAt(
      tester,
      now: lateEvening,
      diveEnd: lateEvening.subtract(const Duration(hours: 1)),
      dailyOtu: 40.0,
      computedAt: DateTime.utc(2027, 1, 15, 0, 5),
    );
    expect(
      tester.widget<O2ToxicityCard>(find.byType(O2ToxicityCard)).dailyOtu,
      40.0,
    );

    final earlyMorning = DateTime(2027, 1, 16, 0, 30);
    await pumpAt(
      tester,
      now: earlyMorning,
      diveEnd: earlyMorning.subtract(const Duration(hours: 2)),
      dailyOtu: 40.0,
      computedAt: DateTime.utc(2027, 1, 15, 0, 5),
    );
    expect(
      tester.widget<O2ToxicityCard>(find.byType(O2ToxicityCard)).dailyOtu,
      0.0,
    );
  });
}
