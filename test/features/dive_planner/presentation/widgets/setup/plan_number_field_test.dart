import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';

import '../../../../../helpers/test_app.dart';

/// Hosts a [PlanNumberField] plus a second focusable field, so a test can move
/// focus away and exercise the commit-on-blur clamp.
Widget _harness({
  required double? value,
  required ValueChanged<double?> onChanged,
  double? min,
  double? max,
  bool isInteger = true,
  int decimals = 0,
  bool allowEmpty = true,
  Key? fieldKey,
}) => testApp(
  locale: const Locale('en'),
  child: Column(
    children: [
      PlanNumberField(
        key: fieldKey,
        label: 'Ascent rate',
        value: value,
        hintValue: 9,
        suffixText: 'm/min',
        decimals: decimals,
        isInteger: isInteger,
        min: min,
        max: max,
        allowEmpty: allowEmpty,
        onChanged: onChanged,
      ),
      const TextField(key: Key('elsewhere')),
    ],
  ),
);

TextField _field(WidgetTester tester) => tester.widget<TextField>(
  find.descendant(
    of: find.byType(PlanNumberField),
    matching: find.byType(TextField),
  ),
);

bool _hasError(WidgetTester tester) =>
    _field(tester).decoration?.errorText != null;

void main() {
  testWidgets('renders the label, the seeded value and the unit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(value: 9, onChanged: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.text('Ascent rate'), findsOneWidget);
    expect(_field(tester).controller!.text, '9');
    // The unit sits outside the box so every planner row lines up.
    expect(find.text('m/min'), findsOneWidget);
  });

  testWidgets('reports a value typed inside the range', (tester) async {
    double? reported;
    await tester.pumpWidget(
      _harness(value: 9, min: 1, max: 30, onChanged: (v) => reported = v),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.pumpAndSettle();

    expect(reported, 12);
    expect(_hasError(tester), isFalse);
  });

  testWidgets('marks out-of-range text and withholds it from the callback', (
    tester,
  ) async {
    double? reported;
    await tester.pumpWidget(
      _harness(value: 9, min: 1, max: 30, onChanged: (v) => reported = v),
    );
    await tester.pumpAndSettle();

    // A rate no diver should be able to plan: the field must not quietly pass
    // it to the schedule.
    await tester.enterText(find.byType(TextField).first, '99');
    await tester.pumpAndSettle();

    expect(reported, isNull);
    expect(_hasError(tester), isTrue);
  });

  testWidgets('clamps an out-of-range entry when focus leaves the field', (
    tester,
  ) async {
    double? reported;
    await tester.pumpWidget(
      _harness(value: 9, min: 1, max: 30, onChanged: (v) => reported = v),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '99');
    await tester.pumpAndSettle();
    // Moving on is the diver's way of committing: the box settles on the
    // nearest legal rate rather than staying red with nothing stored.
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();

    expect(reported, 30);
    expect(_field(tester).controller!.text, '30');
    expect(_hasError(tester), isFalse);
  });

  testWidgets('commit settles a pending edit without any focus change', (
    tester,
  ) async {
    final key = GlobalKey<PlanNumberFieldState>();
    double? reported;
    await tester.pumpWidget(
      _harness(
        value: 9,
        min: 1,
        max: 30,
        fieldKey: key,
        onChanged: (v) => reported = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '99');
    await tester.pumpAndSettle();
    // A button tap on a touch screen leaves focus in the box, so a dialog's
    // submit action has to settle the edit itself, the same way a blur would.
    key.currentState!.commit();
    await tester.pumpAndSettle();

    expect(reported, 30);
    expect(_field(tester).controller!.text, '30');
    expect(_hasError(tester), isFalse);
  });

  testWidgets('a new value from the parent clears a stale out-of-range mark', (
    tester,
  ) async {
    var value = 9.0;
    late StateSetter setOuter;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return PlanNumberField(
              label: 'Ascent rate',
              value: value,
              hintValue: 9,
              suffixText: 'm/min',
              decimals: 0,
              isInteger: true,
              min: 1,
              max: 30,
              onChanged: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '99');
    await tester.pumpAndSettle();
    expect(_hasError(tester), isTrue);

    // A plan reload or a unit switch reseeds the box with a legal value; the
    // red border belonged to the text it replaced.
    setOuter(() => value = 12);
    await tester.pumpAndSettle();

    expect(_field(tester).controller!.text, '12');
    expect(_hasError(tester), isFalse);
  });

  testWidgets('restores the current value when unreadable text is committed', (
    tester,
  ) async {
    double? reported;
    await tester.pumpWidget(
      _harness(
        value: 9,
        min: 1,
        max: 30,
        isInteger: false,
        decimals: 1,
        onChanged: (v) => reported = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '.,.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();

    expect(reported, isNull);
    // formatRoundedForInput drops the trailing zero when seeding a field.
    expect(_field(tester).controller!.text, '9');
  });

  testWidgets('brings back the held value when an emptied box is committed', (
    tester,
  ) async {
    double? reported = 9;
    await tester.pumpWidget(
      _harness(
        value: 9,
        min: 1,
        max: 30,
        allowEmpty: false,
        onChanged: (v) => reported = v,
      ),
    );
    await tester.pumpAndSettle();

    // A rate is a setting the plan always has, so an empty box is a
    // half-finished edit, not "no ascent rate".
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(reported, isNull);

    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();
    expect(_field(tester).controller!.text, '9');
  });

  testWidgets('reports null for an empty field', (tester) async {
    double? reported = 9;
    await tester.pumpWidget(_harness(value: 9, onChanged: (v) => reported = v));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    expect(reported, isNull);
  });
}
