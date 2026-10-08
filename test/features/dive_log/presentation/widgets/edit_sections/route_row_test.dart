import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_row.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/nav_track_fixtures.dart';

Future<int Function()> _pump(
  WidgetTester tester,
  DiveRouteLinkDraft? draft, {
  bool loadFailed = false,
}) async {
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  var taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteRow(
          draft: draft,
          loadFailed: loadFailed,
          onTap: () => taps++,
        ),
      ),
    ),
  );
  return () => taps;
}

void main() {
  testWidgets('labels the row and shows None without routes', (tester) async {
    await _pump(tester, DiveRouteLinkDraft.initial(const []));
    expect(find.text('Underwater Track'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('shows the single linked route by name', (tester) async {
    await _pump(
      tester,
      DiveRouteLinkDraft.initial([testNavTrack('a', name: 'Wreck tour')]),
    );
    expect(find.text('Wreck tour'), findsOneWidget);
  });

  testWidgets('shows the first name and how many more', (tester) async {
    await _pump(
      tester,
      DiveRouteLinkDraft.initial([
        testNavTrack('a', name: 'Wreck tour'),
        testNavTrack('b'),
        testNavTrack('c'),
      ]),
    );
    expect(find.text('Wreck tour +2'), findsOneWidget);
  });

  testWidgets('tapping calls onTap once the draft is loaded', (tester) async {
    final taps = await _pump(tester, DiveRouteLinkDraft.initial(const []));
    await tester.tap(find.byKey(const ValueKey('dive-edit-route-row')));
    expect(taps(), 1);
  });

  testWidgets('tapping does nothing while the links are still loading', (
    tester,
  ) async {
    final taps = await _pump(tester, null);
    await tester.tap(find.byKey(const ValueKey('dive-edit-route-row')));
    expect(taps(), 0);
  });

  testWidgets('says the routes could not be loaded instead of None', (
    tester,
  ) async {
    final taps = await _pump(tester, null, loadFailed: true);
    expect(find.text('Could not load underwater tracks'), findsOneWidget);
    expect(find.text('None'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dive-edit-route-row')));
    expect(taps(), 0);
  });
}
