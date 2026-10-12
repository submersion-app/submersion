import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/picker_header_layout.dart';

const _title = Key('title');
const _controls = Key('controls');
const _actions = Key('actions');

/// Fixed-size children, so every offset below is exact whatever the font.
Widget _header({double titleWidth = 100}) => PickerHeaderLayout(
  title: SizedBox(key: _title, width: titleWidth, height: 28),
  listControls: const SizedBox(key: _controls, width: 96, height: 48),
  actions: const SizedBox(key: _actions, width: 150, height: 40),
);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 400}) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  testWidgets('one row, centred, when the title fits beside the rest', (
    tester,
  ) async {
    // 100 + 96 + 150 = 346, inside 400.
    await _pump(tester, _header());

    expect(
      tester.getSize(find.byType(PickerHeaderLayout)),
      const Size(400, 48),
    );
    expect(
      tester.getRect(find.byKey(_title)),
      const Rect.fromLTWH(0, 10, 100, 28),
    );
    expect(
      tester.getRect(find.byKey(_controls)),
      const Rect.fromLTWH(154, 0, 96, 48),
    );
    expect(
      tester.getRect(find.byKey(_actions)),
      const Rect.fromLTWH(250, 4, 150, 40),
    );
  });

  testWidgets('one row exactly at the fit boundary', (tester) async {
    await _pump(tester, _header(), width: 346);

    expect(tester.getSize(find.byType(PickerHeaderLayout)).height, 48);
  });

  testWidgets('list controls drop under the actions when the title would '
      'not fit whole', (tester) async {
    // 100 + 96 + 150 = 346, past 300.
    await _pump(tester, _header(), width: 300);

    expect(
      tester.getSize(find.byType(PickerHeaderLayout)),
      const Size(300, 88),
    );
    // The title keeps all the room the actions leave.
    expect(
      tester.getRect(find.byKey(_title)),
      const Rect.fromLTWH(0, 6, 100, 28),
    );
    expect(
      tester.getRect(find.byKey(_actions)),
      const Rect.fromLTWH(150, 0, 150, 40),
    );
    expect(
      tester.getRect(find.byKey(_controls)),
      const Rect.fromLTWH(204, 40, 96, 48),
    );
  });

  testWidgets('on two rows the title is capped at what the actions leave', (
    tester,
  ) async {
    await _pump(tester, _header(titleWidth: 400), width: 300);

    expect(tester.getSize(find.byKey(_title)).width, 150);
  });

  testWidgets('reports intrinsic sizes and a dry layout that match', (
    tester,
  ) async {
    await _pump(tester, _header());
    final box = tester.renderObject<RenderBox>(find.byType(PickerHeaderLayout));

    expect(box.getMinIntrinsicWidth(double.infinity), 96 + 150);
    expect(box.getMaxIntrinsicWidth(double.infinity), 100 + 96 + 150);
    expect(box.getMinIntrinsicHeight(400), 48);
    expect(box.getMaxIntrinsicHeight(400), 48);
    expect(box.getMinIntrinsicHeight(300), 88);
    expect(
      box.getDryLayout(const BoxConstraints(maxWidth: 300)),
      const Size(300, 88),
    );
  });

  testWidgets('hit tests reach each child', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      PickerHeaderLayout(
        title: const SizedBox(width: 100, height: 28),
        listControls: const SizedBox(width: 96, height: 48),
        actions: GestureDetector(
          // Opaque: an empty SizedBox is never hit on its own.
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox(key: _actions, width: 150, height: 40),
        ),
      ),
    );

    await tester.tap(find.byKey(_actions));
    expect(taps, 1);
  });
}
