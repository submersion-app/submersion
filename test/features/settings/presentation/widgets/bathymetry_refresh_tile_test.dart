import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/settings/presentation/widgets/bathymetry_refresh_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget buildWidget(
    List<Override> overrides, {
    ValueChanged<bool>? onBusyChanged,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BathymetryRefreshTile(
            leading: const Icon(Icons.refresh),
            onBusyChanged: onBusyChanged,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'calls the refresh action, shows a spinner while pending, and reports '
    'onBusyChanged',
    (tester) async {
      var calls = 0;
      final busyEvents = <bool>[];
      final completer = Completer<SwissBathyRefreshSummary?>();

      await tester.pumpWidget(
        buildWidget([
          swissBathyManualRefreshProvider.overrideWithValue(() {
            calls++;
            return completer.future;
          }),
        ], onBusyChanged: busyEvents.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Existing Map Data'));
      await tester.pump();

      expect(calls, 1);
      expect(busyEvents, [true]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const SwissBathyRefreshSummary(updated: 0, upToDate: 3, failed: 0),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(busyEvents, [true, false]);
      expect(find.text('All data is up to date'), findsOneWidget);
    },
  );

  // A sweep that reached a verdict on nothing (fresh install, or no Swiss
  // lake view opened yet) used to report "All data is up to date", which
  // claims a confirmation the app never made. It gets its own message.
  testWidgets(
    'reports that nothing is cached rather than claiming everything is up '
    'to date when the sweep checked no tiles',
    (tester) async {
      await tester.pumpWidget(
        buildWidget([
          swissBathyManualRefreshProvider.overrideWithValue(
            () async => const SwissBathyRefreshSummary(
              updated: 0,
              upToDate: 0,
              failed: 0,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Existing Map Data'));
      await tester.pumpAndSettle();

      expect(find.text('No lake depth data cached yet'), findsOneWidget);
      expect(find.text('All data is up to date'), findsNothing);
    },
  );

  testWidgets('shows how many tiles were updated on success', (tester) async {
    await tester.pumpWidget(
      buildWidget([
        swissBathyManualRefreshProvider.overrideWithValue(
          () async => const SwissBathyRefreshSummary(
            updated: 2,
            upToDate: 1,
            failed: 0,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update Existing Map Data'));
    await tester.pumpAndSettle();

    expect(find.text('2 tiles updated'), findsOneWidget);
  });

  testWidgets('a failed check leaves cached values in place and shows a '
      'non-alarming message instead of an error', (tester) async {
    await tester.pumpWidget(
      buildWidget([
        swissBathyManualRefreshProvider.overrideWithValue(
          () async => const SwissBathyRefreshSummary(
            updated: 0,
            upToDate: 0,
            failed: 2,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update Existing Map Data'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't check all data; existing values were kept"),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reports a failure, not up-to-date, when the refresh could not run at '
    'all (null summary)',
    (tester) async {
      await tester.pumpWidget(
        buildWidget([
          swissBathyManualRefreshProvider.overrideWithValue(() async => null),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Existing Map Data'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't check all data; existing values were kept"),
        findsOneWidget,
      );
      expect(find.text('All data is up to date'), findsNothing);
    },
  );
}
