import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

Widget _host(List<AddStripEntry> entries, {ValueChanged<String>? onAdd}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [
          AddStrip(entries: entries, onAdd: onAdd ?? (_) {}),
          const Expanded(child: SizedBox()),
        ],
      ),
    ),
  );
}

Finder _chip(String cardId) => find.byKey(ValueKey('addStrip_$cardId'));

void main() {
  testWidgets('renders nothing for no entries', (tester) async {
    await tester.pumpWidget(_host(const []));

    expect(tester.getSize(find.byType(AddStrip)).height, 0);
    expect(find.text('Add'), findsNothing);
  });

  testWidgets('one chip per entry, in order', (tester) async {
    await tester.pumpWidget(
      _host(const [
        AddStripEntry(cardId: 'equipment', label: 'Equipment'),
        AddStripEntry(cardId: 'tags', label: 'Tags'),
      ]),
    );

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(
      tester.getTopLeft(_chip('equipment')).dx,
      lessThan(tester.getTopLeft(_chip('tags')).dx),
    );
  });

  testWidgets('spans the page and starts at its left edge', (tester) async {
    await tester.pumpWidget(
      _host(const [AddStripEntry(cardId: 'tags', label: 'Tags')]),
    );

    final strip = tester.getRect(find.byType(AddStrip));
    final page = tester.getRect(find.byType(Scaffold));
    expect(strip.left, page.left);
    expect(strip.width, page.width);
    expect(tester.getTopLeft(find.text('Add')).dx, lessThan(32));
  });

  testWidgets('a tap reports the card id', (tester) async {
    final added = <String>[];
    await tester.pumpWidget(
      _host(const [
        AddStripEntry(cardId: 'equipment', label: 'Equipment'),
        AddStripEntry(cardId: 'buddies', label: 'Buddies', hidden: true),
      ], onAdd: added.add),
    );

    await tester.tap(_chip('equipment'));
    await tester.tap(_chip('buddies'));

    expect(added, ['equipment', 'buddies']);
  });

  testWidgets('a hidden entry is announced as hidden', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const [
        AddStripEntry(cardId: 'tags', label: 'Tags'),
        AddStripEntry(cardId: 'buddies', label: 'Buddies', hidden: true),
      ]),
    );

    expect(find.bySemanticsLabel('Buddies, hidden'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tags, hidden')), findsNothing);

    semantics.dispose();
  });

  // A card whose change emptied it goes back to the strip; the dot that
  // marked it on the page goes with it (issue #4527).
  testWidgets('a changed entry carries the unsaved-changes dot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const [
        AddStripEntry(cardId: 'tags', label: 'Tags', changed: true),
        AddStripEntry(cardId: 'buddies', label: 'Buddies', hidden: true),
        AddStripEntry(
          cardId: 'notes',
          label: 'Notes',
          hidden: true,
          changed: true,
        ),
      ]),
    );

    Finder dotOn(String cardId) => find.descendant(
      of: _chip(cardId),
      matching: find.byType(RecordChangedDot),
    );
    expect(dotOn('tags'), findsOneWidget);
    expect(dotOn('buddies'), findsNothing);
    expect(dotOn('notes'), findsOneWidget);
  });

  testWidgets('the strip scrolls sideways instead of wrapping', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.reset);
    final entries = [
      for (var i = 0; i < 12; i++)
        AddStripEntry(cardId: 'card$i', label: 'Section number $i'),
    ];

    await tester.pumpWidget(_host(entries));

    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(_chip('card0')).dy;
    for (var i = 0; i < 12; i++) {
      expect(tester.getTopLeft(_chip('card$i')).dy, first);
    }
    expect(tester.getTopLeft(_chip('card11')).dx, greaterThan(320));
  });
}
