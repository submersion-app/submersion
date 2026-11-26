import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinder_block.dart';

const _figure = Key('figure');
const _detail = Key('detail');
const _trailing = Key('trailing');
const _block = Key('block');

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const CylinderBlock(
                key: _block,
                figure: SizedBox(key: _figure, width: 100, height: 120),
                icon: Icons.circle,
                title: 'Diluent',
                subtitle: [Text('Diluent role')],
                gasMix: GasMix(o2: 21),
                gasLabel: 'Gas Air',
                // Takes all the width it is given, so its rect shows the
                // room the details get.
                details: [
                  SizedBox(key: _detail, width: double.infinity, height: 10),
                ],
                trailing: SizedBox(key: _trailing, width: 96, height: 48),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('on a wide card', () {
    testWidgets('the details sit beside the figure', (tester) async {
      await _pump(tester, width: 700);

      expect(
        tester.getTopLeft(find.byKey(_detail)).dx,
        greaterThan(tester.getTopRight(find.byKey(_figure)).dx),
      );
    });

    testWidgets('the menu is on the title line, not beside the details', (
      tester,
    ) async {
      await _pump(tester, width: 700);

      // The details run to the block's edge: the menu takes no width there.
      expect(
        tester.getTopRight(find.byKey(_detail)).dx,
        tester.getTopRight(find.byKey(_block)).dx,
      );
      // The menu ends the title line.
      expect(
        tester.getTopRight(find.byKey(_trailing)).dx,
        tester.getTopRight(find.byKey(_block)).dx,
      );
      expect(
        tester.getBottomLeft(find.byKey(_trailing)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Diluent role')).dy),
      );
    });
  });

  group('on a narrow card', () {
    testWidgets('the details run under the figure at the full width', (
      tester,
    ) async {
      await _pump(tester, width: 320);

      final detail = tester.getRect(find.byKey(_detail));
      final block = tester.getRect(find.byKey(_block));
      expect(
        detail.top,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(_figure)).dy),
      );
      expect(detail.left, block.left);
      expect(detail.right, block.right);
    });

    testWidgets('the menu sits under the title, beside the figure', (
      tester,
    ) async {
      await _pump(tester, width: 320);

      final figure = tester.getRect(find.byKey(_figure));
      final trailing = tester.getRect(find.byKey(_trailing));
      // In the room beside the tall figure, so the title keeps the whole
      // column rather than sharing it with the controls.
      expect(trailing.left, greaterThan(figure.right));
      expect(
        trailing.top,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Diluent role')).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text('Diluent')).dx,
        greaterThan(figure.right),
      );
    });

    testWidgets('a large text size stacks the details on a wider card too', (
      tester,
    ) async {
      await _pump(tester, width: 700, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(_detail)).dx,
        tester.getTopLeft(find.byKey(_block)).dx,
      );
    });
  });
}
