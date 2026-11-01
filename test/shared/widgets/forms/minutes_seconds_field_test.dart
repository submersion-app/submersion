import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';

/// The field's own behaviour; parseMinutesSeconds and formatMinutesSeconds
/// are covered in test/core/utils/minutes_seconds_test.dart.
void main() {
  Widget host(Widget child, GlobalKey<FormState> formKey) => MaterialApp(
    home: Scaffold(
      body: Form(key: formKey, child: child),
    ),
  );

  testWidgets('typing reports the parsed seconds', (tester) async {
    final formKey = GlobalKey<FormState>();
    final seen = <int?>[];
    await tester.pumpWidget(
      host(
        MinutesSecondsField(
          seconds: 600,
          onChanged: seen.add,
          label: 'Time',
          formatErrorText: 'Use minutes:seconds',
        ),
        formKey,
      ),
    );

    expect(find.text('10:00'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '12:30');

    expect(seen, [750]);
  });

  testWidgets('unparsable text fails validation with the format text', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      host(
        MinutesSecondsField(
          seconds: null,
          onChanged: (_) {},
          label: 'Time',
          formatErrorText: 'Use minutes:seconds',
        ),
        formKey,
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'ab');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Use minutes:seconds'), findsOneWidget);
  });

  testWidgets('leaving the field reports that the time settled', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var settled = 0;
    await tester.pumpWidget(
      host(
        Column(
          children: [
            MinutesSecondsField(
              seconds: 600,
              onChanged: (_) {},
              onSettled: () => settled++,
              label: 'Time',
              formatErrorText: 'Use minutes:seconds',
            ),
            const TextField(key: Key('other')),
          ],
        ),
        formKey,
      ),
    );

    await tester.enterText(find.byType(TextFormField), '12:30');
    expect(settled, 0);
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    expect(settled, 1);
  });

  testWidgets('a parsed value still runs the extra rule', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      host(
        MinutesSecondsField(
          seconds: 600,
          onChanged: (_) {},
          label: 'Time',
          formatErrorText: 'Use minutes:seconds',
          validator: (seconds) => seconds > 1800 ? 'Too late' : null,
        ),
        formKey,
      ),
    );

    await tester.enterText(find.byType(TextFormField), '31:00');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Too late'), findsOneWidget);
  });
}
