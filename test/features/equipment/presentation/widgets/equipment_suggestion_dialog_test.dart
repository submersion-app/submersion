import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_suggestion.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_suggestion_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Suggest a category dialog (issue #5103).
void main() {
  /// Opens the dialog and returns a holder for its result once closed.
  Future<List<EquipmentSuggestion?>> open(
    WidgetTester tester, {
    EquipmentType currentType = EquipmentType.bcd,
    String? example,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    final results = <EquipmentSuggestion?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await showEquipmentSuggestionDialog(
                  context,
                  currentType: currentType,
                  example: example,
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return results;
  }

  bool openEnabled(WidgetTester tester) => tester
      .widget<ButtonStyleButton>(
        find.descendant(
          of: find.byKey(const ValueKey('equipment-suggest-open')),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          matchRoot: true,
        ),
      )
      .enabled;

  Set<EquipmentSuggestionKind> kindSelection(WidgetTester tester) => tester
      .widget<SegmentedButton<EquipmentSuggestionKind>>(
        find.byKey(const ValueKey('equipment-suggest-kind')),
      )
      .selected;

  Future<void> fill(
    WidgetTester tester, {
    String name = 'SPG',
    String reason = 'Own service schedule',
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('equipment-suggest-name')),
      name,
    );
    await tester.enterText(
      find.byKey(const ValueKey('equipment-suggest-reason')),
      reason,
    );
    await tester.pump();
  }

  testWidgets('defaults to a subcategory of the current type', (tester) async {
    await open(tester, currentType: EquipmentType.bcd);

    expect(find.text('Suggest a category'), findsOneWidget);
    expect(kindSelection(tester), {EquipmentSuggestionKind.subcategory});
    expect(find.text('A kind of'), findsOneWidget);
    expect(find.text('BCD'), findsOneWidget);
  });

  testWidgets('defaults to a category with no parent for Other', (
    tester,
  ) async {
    await open(tester, currentType: EquipmentType.other);

    expect(kindSelection(tester), {EquipmentSuggestionKind.category});
    expect(find.text('Closest existing type'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('Open in GitHub waits for a name and a reason', (tester) async {
    await open(tester);
    expect(openEnabled(tester), isFalse);

    await fill(tester, name: '   ', reason: 'Real reason');
    expect(openEnabled(tester), isFalse);

    await fill(tester, name: 'SPG', reason: '  \n ');
    expect(openEnabled(tester), isFalse);

    await fill(tester);
    expect(openEnabled(tester), isTrue);
  });

  testWidgets('a subcategory needs a parent', (tester) async {
    await open(tester, currentType: EquipmentType.other);
    await fill(tester);
    expect(openEnabled(tester), isTrue);

    await tester.tap(find.text('New kind of a type'));
    await tester.pumpAndSettle();

    expect(kindSelection(tester), {EquipmentSuggestionKind.subcategory});
    expect(openEnabled(tester), isFalse);
  });

  testWidgets('returns the trimmed suggestion', (tester) async {
    final results = await open(
      tester,
      currentType: EquipmentType.instrument,
      example: 'Scubapro 52 mm',
    );
    await fill(tester, name: '  SPG  ', reason: '  Own service schedule \n');

    await tester.tap(find.byKey(const ValueKey('equipment-suggest-open')));
    await tester.pumpAndSettle();

    expect(
      results.single,
      const EquipmentSuggestion(
        kind: EquipmentSuggestionKind.subcategory,
        name: 'SPG',
        parent: EquipmentType.instrument,
        reason: 'Own service schedule',
      ),
    );
  });

  testWidgets('the example checkbox adds the example', (tester) async {
    final results = await open(tester, example: 'Scubapro 52 mm');
    await fill(tester);

    expect(
      find.text('Include this item as an example (Scubapro 52 mm)'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('equipment-suggest-example')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('equipment-suggest-open')));
    await tester.pumpAndSettle();

    expect(results.single!.example, 'Scubapro 52 mm');
  });

  testWidgets('no example means no checkbox', (tester) async {
    await open(tester, example: '  ');

    expect(
      find.byKey(const ValueKey('equipment-suggest-example')),
      findsNothing,
    );
  });

  testWidgets('a category can pick None as its closest type', (tester) async {
    final results = await open(tester, currentType: EquipmentType.bcd);
    await tester.tap(find.text('New type of gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-suggest-parent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    await fill(tester);

    await tester.tap(find.byKey(const ValueKey('equipment-suggest-open')));
    await tester.pumpAndSettle();

    expect(results.single!.kind, EquipmentSuggestionKind.category);
    expect(results.single!.parent, isNull);
  });

  testWidgets('Cancel returns null', (tester) async {
    final results = await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });
}
