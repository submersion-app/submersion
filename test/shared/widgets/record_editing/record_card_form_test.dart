import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_form.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Reused form fields keep their own validators; a card reports them so
/// Done and Save refuse while one shows an error (issue #4527).
void main() {
  late RecordEditController<String> controller;

  setUp(() {
    controller = RecordEditController<String>(onSave: (_) async {})
      ..unlock('record');
  });
  tearDown(() => controller.dispose());

  String? mustBeDigits(String? value) =>
      RegExp(r'^\d*$').hasMatch(value ?? '') ? null : 'Digits only';

  Future<void> pump(
    WidgetTester tester, {
    String initial = '',
    bool show = true,
    RecordEditController<String>? scope,
  }) async {
    final field = TextFormField(
      key: const Key('field'),
      initialValue: initial,
      validator: mustBeDigits,
    );
    final form = RecordCardForm<String>(cardId: 'tanks', child: field);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: scope == null
              ? (show ? form : const SizedBox())
              : RecordEditScope<String>(
                  controller: scope,
                  child: show ? form : const SizedBox(),
                ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a field failing its validator marks the card invalid; '
      'fixing it clears it', (tester) async {
    await pump(tester, scope: controller);
    expect(controller.invalidCardIds, isEmpty);

    await tester.enterText(find.byKey(const Key('field')), '1x');
    // Validated after the frame the text arrived in; drawn in the next.
    await tester.pump();
    await tester.pump();
    expect(controller.invalidCardIds, {'tanks'});
    expect(find.text('Digits only'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('field')), '12');
    await tester.pump();
    expect(controller.invalidCardIds, isEmpty);
  });

  testWidgets('a field already failing when built is reported at once', (
    tester,
  ) async {
    await pump(tester, initial: 'x', scope: controller);

    expect(controller.invalidCardIds, {'tanks'});
  });

  testWidgets('disposed, the form withdraws its report', (tester) async {
    await pump(tester, initial: 'x', scope: controller);
    expect(controller.invalidCardIds, {'tanks'});

    await pump(tester, show: false, scope: controller);

    expect(controller.invalidCardIds, isEmpty);
  });

  testWidgets('no controller in scope: nothing is reported and nothing '
      'throws', (tester) async {
    await pump(tester, initial: 'x');

    expect(tester.takeException(), isNull);
    expect(find.text('Digits only'), findsOneWidget);
  });

  // Another card can change what a field checks against (the header's
  // runtime bounds a gas switch time), with no keystroke in this card.
  group('a limit changed from outside', () {
    Future<void> pumpLimit(WidgetTester tester, int max) async {
      String? withinMax(String? value) =>
          (int.tryParse(value ?? '') ?? 0) > max ? 'Too late' : null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordEditScope<String>(
              controller: controller,
              child: RecordCardForm<String>(
                cardId: 'tanks',
                child: TextFormField(
                  key: const Key('field'),
                  initialValue: '40',
                  validator: withinMax,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a limit raised elsewhere clears the report', (tester) async {
      await pumpLimit(tester, 30);
      expect(controller.invalidCardIds, {'tanks'});

      await pumpLimit(tester, 50);

      expect(controller.invalidCardIds, isEmpty);
      expect(find.text('Too late'), findsNothing);
    });

    testWidgets('a limit lowered elsewhere makes the report and shows the '
        'error', (tester) async {
      await pumpLimit(tester, 50);
      expect(controller.invalidCardIds, isEmpty);

      await pumpLimit(tester, 30);

      expect(controller.invalidCardIds, {'tanks'});
      expect(find.text('Too late'), findsOneWidget);
    });

    testWidgets('rebuilt from above with every field valid, no field is '
        'built a second time to be checked', (tester) async {
      var builds = 0;
      Future<void> pumpCounting(int max) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordEditScope<String>(
                controller: controller,
                child: RecordCardForm<String>(
                  cardId: 'tanks',
                  child: FormField<int>(
                    initialValue: 40,
                    validator: (v) => (v ?? 0) > max ? 'Too late' : null,
                    builder: (state) {
                      builds++;
                      return Text(state.errorText ?? 'ok');
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await pumpCounting(50);
      final before = builds;
      await pumpCounting(60);

      expect(builds - before, 1);
      expect(controller.invalidCardIds, isEmpty);
    });
  });
}
