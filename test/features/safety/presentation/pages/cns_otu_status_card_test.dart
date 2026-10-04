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
      CnsOtuSnapshot(
        lastDiveId: 'dive-1',
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
      CnsOtuSnapshot(
        lastDiveId: 'dive-1',
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
      CnsOtuSnapshot(
        lastDiveId: 'dive-1',
        lastDiveEnd: lastDiveEnd,
        exposure: const O2Exposure(cnsEnd: 0.0, otu: 0.0),
        weeklyOtu: 200.0,
      ),
    );

    expect(find.text('No active load'), findsNothing);
    expect(find.textContaining('Oxygen Toxicity'), findsOneWidget);
  });
}
