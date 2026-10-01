import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_dive_choice_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _dive(String id, int number, DateTime entry) =>
    Dive(id: id, diveNumber: number, dateTime: entry, entryTime: entry);

Future<List<Dive>> _pump(
  WidgetTester tester, {
  required List<Dive> dives,
  String? selectedDiveId,
  Locale locale = const Locale('en'),
}) async {
  final picked = <Dive>[];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NavTrackDiveChoiceSheet(
            dives: dives,
            selectedDiveId: selectedDiveId,
            onDiveSelected: picked.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  final first = _dive('a', 212, DateTime.utc(2025, 1, 15, 14, 16));
  final second = _dive('b', 211, DateTime.utc(2025, 1, 15, 12, 6));

  testWidgets('lists the dives in the order given, by number', (tester) async {
    await _pump(tester, dives: [first, second]);

    final top = tester.getTopLeft(find.text('Dive #212')).dy;
    final next = tester.getTopLeft(find.text('Dive #211')).dy;
    expect(top, lessThan(next));
  });

  testWidgets('marks only the selected dive', (tester) async {
    await _pump(tester, dives: [first, second], selectedDiveId: 'b');

    final selected = tester.widget<ListTile>(
      find.byKey(const ValueKey('nav-track-dive-choice-b')),
    );
    final other = tester.widget<ListTile>(
      find.byKey(const ValueKey('nav-track-dive-choice-a')),
    );
    expect(selected.selected, isTrue);
    expect(other.selected, isFalse);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('hands back the tapped dive', (tester) async {
    final picked = await _pump(tester, dives: [first, second]);

    await tester.tap(find.text('Dive #211'));
    await tester.pumpAndSettle();

    expect(picked, [second]);
  });

  testWidgets('joins date and time with the locale\'s own connector', (
    tester,
  ) async {
    await _pump(tester, dives: [first], locale: const Locale('de'));

    expect(find.textContaining(' bei '), findsOneWidget);
    expect(find.textContaining(' at '), findsNothing);
  });
}
