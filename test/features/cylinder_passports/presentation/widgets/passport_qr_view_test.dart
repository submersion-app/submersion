import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';

void main() {
  const url =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-25';

  testWidgets('paints one module per QR cell and labels itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PassportQrView(
              data: url,
              size: 200,
              semanticLabel: 'Passport QR code',
            ),
          ),
        ),
      ),
    );
    final code = QrCode.fromData(
      data: url,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final painter = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(PassportQrView),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((painter.painter as QrModulesPainter).moduleCount, code.moduleCount);
    expect(find.bySemanticsLabel('Passport QR code'), findsOneWidget);
    expect(find.bySemanticsLabel(url), findsNothing);
  });

  test('a full 160-character payload is a version 9 or smaller code', () {
    final code = QrCode.fromData(
      data:
          '$url&n=Steel+12+L&sn=AB12345&v=12&wp=232&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1',
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    expect(code.typeNumber, lessThanOrEqualTo(9));
  });

  testWidgets('dark theme still paints black modules on white', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: PassportQrView(
              data: url,
              size: 200,
              semanticLabel: 'Passport QR code',
            ),
          ),
        ),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(PassportQrView),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as QrModulesPainter;
    expect(painter.color, const Color(0xFF000000));
    expect(painter.background, const Color(0xFFFFFFFF));
    // The QR standard asks for four modules of light margin on every side.
    expect(painter.quietModules, 4);
  });

  test('cells snap to whole device pixels', () {
    // 200 logical px at 2x over 53 modules plus two 4-module margins.
    expect(QrModulesPainter.cellSize(200, 61, 2.0), 3.0);
    expect(QrModulesPainter.cellSize(72, 61, 1.0), 1.0);
  });

  test('the module grid starts on a whole device pixel', () {
    // 72 px at 1x, 61 cells of 1 px: centring alone puts the grid at 9.5.
    expect(QrModulesPainter.moduleOrigin(72, 61, 1.0, 4, 1.0), 9.0);
    // 200 px at 2x, 3 px cells: 20.5 logical px is 41 device pixels, whole.
    expect(QrModulesPainter.moduleOrigin(200, 61, 3.0, 4, 2.0), 20.5);
    // Any ratio: the origin times the ratio is a whole number of pixels.
    final o = QrModulesPainter.moduleOrigin(101, 61, 1.0, 4, 3.0);
    expect((o * 3.0) % 1, 0);
  });
}
