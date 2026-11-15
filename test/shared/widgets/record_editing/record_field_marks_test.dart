import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_field_marks.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';
import 'package:submersion/shared/widgets/record_editing/reveal_answering.dart';

@immutable
class _Rec {
  const _Rec();
}

/// A text row that calls any text containing an `x` unreadable.
class _Row extends StatefulWidget {
  const _Row({this.fieldId = 'words'});

  final String fieldId;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row>
    with RevealAnswering<_Row>, RecordFieldMarks<_Rec, _Row> {
  @override
  String get markCardId => 'card';

  @override
  String get markFieldId => widget.fieldId;

  @override
  void didUpdateWidget(_Row oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fieldId != widget.fieldId) {
      withdrawMark(cardId: 'card', fieldId: oldWidget.fieldId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('row-${widget.fieldId}'),
      onChanged: (text) => reportUnreadable(text.contains('x')),
    );
  }
}

RecordEditController<_Rec> _controller({bool unlocked = true}) {
  final controller = RecordEditController<_Rec>(onSave: (_) async {});
  if (unlocked) {
    controller
      ..unlock(const _Rec())
      ..openCard('card');
  }
  addTearDown(controller.dispose);
  return controller;
}

Widget _host(
  RecordEditController<_Rec> controller, {
  bool showRow = true,
  double above = 0,
  List<String> fieldIds = const ['words'],
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 300,
          child: RecordEditScope<_Rec>(
            controller: controller,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: above),
                  if (showRow)
                    for (final id in fieldIds) _Row(fieldId: id),
                  const SizedBox(height: 600),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('storedValueOfTyped', () {
    // A row that shows no decimals.
    double? shown(double value) => value.roundToDouble();
    double same(double typed) => typed;

    test('the number the row put on show stands for the value behind it', () {
      expect(
        storedValueOfTyped(
          12,
          onShow: 12.4,
          stored: 9.0,
          shownNumber: shown,
          fromDisplay: same,
        ),
        12.4,
      );
    });

    test('else the number shown for the stored value stands for that', () {
      expect(
        storedValueOfTyped(
          9,
          onShow: 12.4,
          stored: 9.3,
          shownNumber: shown,
          fromDisplay: same,
        ),
        9.3,
      );
    });

    test('any other number is converted as typed', () {
      expect(
        storedValueOfTyped(
          40,
          onShow: 12.0,
          stored: 12.0,
          shownNumber: shown,
          fromDisplay: (typed) => typed * 0.3048,
        ),
        closeTo(12.192, 1e-9),
      );
    });

    test('with nothing on show or stored, it is converted as typed', () {
      expect(
        storedValueOfTyped(
          40,
          onShow: null,
          stored: null,
          shownNumber: shown,
          fromDisplay: (typed) => typed * 2,
        ),
        80,
      );
    });
  });

  group('RecordFieldMarks', () {
    testWidgets('unreadable text marks the card; readable text clears it', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(controller));

      await tester.enterText(find.byType(TextField), 'x');
      expect(controller.invalidCardIds, {'card'});

      await tester.enterText(find.byType(TextField), 'ok');
      expect(controller.invalidCardIds, isEmpty);
    });

    testWidgets('disposed while unreadable: the mark is cleared', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(controller));
      await tester.enterText(find.byType(TextField), 'x');
      expect(controller.invalidCardIds, {'card'});

      await tester.pumpWidget(_host(controller, showRow: false));

      expect(controller.invalidCardIds, isEmpty);
    });

    testWidgets('a row given another field withdraws the old mark', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(controller));
      await tester.enterText(find.byType(TextField), 'x');
      expect(controller.invalidCardIds, {'card'});

      await tester.pumpWidget(_host(controller, fieldIds: const ['other']));

      expect(controller.invalidCardIds, isEmpty);
    });

    testWidgets(
      'a reveal request naming its field scrolls it into view and is withdrawn',
      (tester) async {
        final controller = _controller();
        await tester.pumpWidget(_host(controller, above: 600));
        // Marked without scrolling to it: the row is below the window.
        controller.setFieldInvalid('card', 'words', invalid: true);
        expect(tester.getTopLeft(find.byType(_Row)).dy, greaterThan(300));

        controller.closeCard('card');
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(find.byType(_Row)).dy, lessThan(300));
        expect(controller.revealRequest, isNull);
      },
    );

    testWidgets('a request naming another field is left for that field', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(controller, above: 600));
      controller.setFieldInvalid('card', 'other', invalid: true);

      controller.closeCard('card');
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(_Row)).dy, greaterThan(300));
      expect(controller.revealRequest?.fieldId, 'other');
    });

    testWidgets('locked, a report marks nothing', (tester) async {
      final controller = _controller(unlocked: false);
      await tester.pumpWidget(_host(controller));

      await tester.enterText(find.byType(TextField), 'x');

      expect(controller.invalidCardIds, isEmpty);
    });

    testWidgets('with no controller above it, a report does nothing', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Row())));

      await tester.enterText(find.byType(TextField), 'x');

      expect(tester.takeException(), isNull);
    });
  });
}
