import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_owner_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_picker_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  DocumentOwner? result;
  var closed = false;

  Future<void> openPicker(
    WidgetTester t, {
    DocumentOwner current = const DocumentOwner.personal(),
  }) async {
    result = null;
    closed = false;
    final overrides = await getBaseOverrides();
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          documentOwnerOptionsProvider.overrideWith(
            (ref, kind) async => switch (kind) {
              DocumentOwnerKind.trip => const [
                DocumentOwnerOption('t1', 'Bonaire'),
                DocumentOwnerOption('t2', 'Red Sea'),
              ],
              DocumentOwnerKind.dive => [
                DocumentOwnerOption(
                  'v1',
                  '#12',
                  subtitle: 'Salt Pier',
                  date: DateTime.utc(2026, 9, 1, 9),
                ),
                DocumentOwnerOption(
                  'v2',
                  '',
                  subtitle: 'Blue Hole',
                  date: DateTime.utc(2026, 9, 2, 9),
                ),
                DocumentOwnerOption('v3', '', date: DateTime.utc(2026, 9, 3)),
              ],
              DocumentOwnerKind.certification => const [
                // The query's order: the empty stored name first.
                DocumentOwnerOption(
                  'c1',
                  '',
                  certification: (name: '', agency: 'padi', level: 'openWater'),
                ),
                DocumentOwnerOption(
                  'c2',
                  'Adv. Nitrox',
                  certification: (
                    name: 'Adv. Nitrox',
                    agency: 'padi',
                    level: 'advancedNitrox',
                  ),
                ),
              ],
              _ => const <DocumentOwnerOption>[],
            },
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDocumentOwnerPicker(context, current: current);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets('choosing a kind then a record returns that owner', (t) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-trip')));
    await t.pumpAndSettle();
    await t.tap(find.text('Red Sea'));
    await t.pumpAndSettle();
    expect(result, const DocumentOwner(DocumentOwnerKind.trip, 't2'));
  });

  testWidgets('search narrows the records', (t) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-trip')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('owner-search')), 'bon');
    await t.pumpAndSettle();
    expect(find.text('Bonaire'), findsOneWidget);
    expect(find.text('Red Sea'), findsNothing);
  });

  testWidgets('opens on the current kind with the current record marked', (
    t,
  ) async {
    await openPicker(
      t,
      current: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
    final tile = t.widget<ListTile>(
      find.ancestor(of: find.text('Bonaire'), matching: find.byType(ListTile)),
    );
    expect(tile.selected, isTrue);
  });

  testWidgets('Personal returns the personal owner', (t) async {
    await openPicker(
      t,
      current: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
    await t.tap(find.byKey(const ValueKey('owner-kind-personal')));
    await t.pumpAndSettle();
    expect(result, const DocumentOwner.personal());
  });

  testWidgets('a dive shows its site', (t) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-dive')));
    await t.pumpAndSettle();
    expect(find.text('#12'), findsOneWidget);
    expect(find.textContaining('Salt Pier'), findsOneWidget);
  });

  // Issue #3391: a dive reads number, name or site, then date, as the File
  // under field does; an unnumbered one leads with its name or site.
  testWidgets('an unnumbered dive leads with its site, else its date', (
    t,
  ) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-dive')));
    await t.pumpAndSettle();
    final tiles = {
      for (final tile in t.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data: (tile.subtitle as Text?)?.data,
    };
    expect(tiles['#12'], startsWith('Salt Pier · '));
    expect(tiles['Blue Hole'], isNotNull);
    expect(tiles['Blue Hole'], isNot(contains('Blue Hole')));
    // Nothing but its date: the date is the title, with nothing under it.
    expect(tiles.entries.where((e) => e.value == null), hasLength(1));
  });

  // Issue #3366: a certification with no custom title stores an empty name
  // and was listed blank.
  testWidgets('a certification with no custom title shows its certification', (
    t,
  ) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-certification')));
    await t.pumpAndSettle();
    final titles = t
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    // Sorted by the title shown, not the empty stored name.
    expect(titles, ['Adv. Nitrox', 'Open Water']);
    await t.enterText(find.byKey(const ValueKey('owner-search')), 'open');
    await t.pumpAndSettle();
    expect(find.text('Open Water'), findsOneWidget);
    expect(find.text('Adv. Nitrox'), findsNothing);
    await t.tap(find.text('Open Water'));
    await t.pumpAndSettle();
    expect(result, const DocumentOwner(DocumentOwnerKind.certification, 'c1'));
  });

  testWidgets('switching kinds clears the search', (t) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-trip')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('owner-search')), 'bon');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('owner-kind-dive')));
    await t.pumpAndSettle();
    // The field shows what filters: nothing.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('owner-search')),
        matching: find.text('bon'),
      ),
      findsNothing,
    );
    expect(find.text('#12'), findsOneWidget);
  });

  testWidgets('a personal document shows Personal as current', (t) async {
    await openPicker(t);
    final chip = t.widget<ChoiceChip>(
      find.byKey(const ValueKey('owner-kind-personal')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('an empty kind says so', (t) async {
    await openPicker(t);
    await t.tap(find.byKey(const ValueKey('owner-kind-buddy')));
    await t.pumpAndSettle();
    expect(find.text('Nothing to file under yet'), findsOneWidget);
  });

  testWidgets('dismissing returns null', (t) async {
    await openPicker(t);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
