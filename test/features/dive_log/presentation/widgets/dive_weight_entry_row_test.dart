import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_weight_entry_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The dive editor's weight row (issue #956): placement, amount and remove,
/// with the diver's optional name for the weight on a second line.
void main() {
  const units = UnitFormatter(AppSettings());

  /// Hosts rows the way the dive editor does: keyed by id, edits stored in
  /// place without a rebuild, removal rebuilding the list. Returns a reader
  /// for the host's current list.
  Future<List<DiveWeight> Function()> pumpRows(
    WidgetTester tester,
    List<DiveWeight> initial,
  ) async {
    var weights = initial;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Form(
              child: Column(
                children: [
                  for (final w in weights)
                    DiveWeightEntryRow(
                      key: ValueKey(w.id),
                      weight: w,
                      units: units,
                      onChanged: (updated) => weights = [
                        for (final x in weights)
                          x.id == updated.id ? updated : x,
                      ],
                      onRemove: () => setState(
                        () => weights = [
                          for (final x in weights)
                            if (x.id != w.id) x,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return () => weights;
  }

  DiveWeight w(String id, double kg, {String label = ''}) => DiveWeight(
    id: id,
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: kg,
    label: label,
  );

  Finder nameField(int row) => find
      .byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Name (optional)',
      )
      .at(row);

  Finder amountField(String text) => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'kg' &&
        widget.controller?.text == text,
  );

  testWidgets('shows the name under the type and amount', (tester) async {
    await pumpRows(tester, [w('a', 2, label: 'Top pocket')]);
    expect(nameField(0), findsOneWidget);
    expect(find.text('Top pocket'), findsOneWidget);
    expect(
      tester.getTopLeft(nameField(0)).dy,
      greaterThan(tester.getBottomLeft(amountField('2')).dy),
    );
  });

  testWidgets('typing an amount then a name keeps both', (tester) async {
    final current = await pumpRows(tester, [w('a', 2)]);
    await tester.enterText(amountField('2'), '3');
    await tester.enterText(nameField(0), 'Top pocket');
    expect(current().single.amountKg, 3);
    expect(current().single.label, 'Top pocket');
  });

  testWidgets('deleting a middle row leaves the others on their own rows', (
    tester,
  ) async {
    final current = await pumpRows(tester, [
      w('a', 1, label: 'Top pocket'),
      w('b', 2, label: '2nd pocket'),
      w('c', 3, label: '3rd pocket'),
    ]);
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pump();

    expect(current().map((x) => x.id), ['a', 'c']);
    expect(find.text('2nd pocket'), findsNothing);
    expect(find.text('Top pocket'), findsOneWidget);
    expect(find.text('3rd pocket'), findsOneWidget);
    expect(amountField('3'), findsOneWidget);
    expect(amountField('2'), findsNothing);
  });

  testWidgets('the counter appears only near the limit', (tester) async {
    await pumpRows(tester, [w('a', 2)]);
    await tester.enterText(nameField(0), 'Top pocket');
    await tester.pump();
    expect(find.textContaining('/256'), findsNothing);
    await tester.enterText(nameField(0), 'x' * 240);
    await tester.pump();
    expect(find.text('240/256'), findsOneWidget);
  });

  testWidgets('a name sits clearly closer to its own row than to the next', (
    tester,
  ) async {
    await pumpRows(tester, [w('a', 1), w('b', 2)]);
    final ownGap =
        tester.getTopLeft(nameField(0)).dy -
        tester.getBottomLeft(amountField('1')).dy;
    final nextGap =
        tester.getTopLeft(amountField('2')).dy -
        tester.getBottomLeft(nameField(0)).dy;
    expect(nextGap, greaterThanOrEqualTo(ownGap * 2));
  });

  testWidgets('changing the type keeps the amount and name', (tester) async {
    final current = await pumpRows(tester, [w('a', 2, label: 'Top pocket')]);
    await tester.tap(find.text('Trim Weights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankle Weights').last);
    await tester.pumpAndSettle();

    expect(current().single.weightType, WeightType.ankleWeights);
    expect(current().single.amountKg, 2);
    expect(current().single.label, 'Top pocket');
  });

  testWidgets('a cleared amount is 0 kg; unreadable text keeps the last one', (
    tester,
  ) async {
    final current = await pumpRows(tester, [w('a', 2)]);
    await tester.enterText(amountField('2'), '');
    expect(current().single.amountKg, 0);
    await tester.enterText(amountField(''), '3');
    await tester.enterText(amountField('3'), '3..');
    expect(current().single.amountKg, 3);
  });
}
