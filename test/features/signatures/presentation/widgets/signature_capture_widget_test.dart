import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/signatures/presentation/widgets/signature_capture_widget.dart';

import '../../../../helpers/test_app.dart';

/// The instructor capture sheet, the twin of the buddy one. Both were
/// untested before #1358, which is how a hardcoded PNG size and a companion
/// missing a required column both survived.
///
/// Stops at the `onSave` boundary and never reaches `strokesToPng`: that
/// finishes through `Picture.toImage`, whose future the engine completes
/// rather than a timer, so it hangs under a widget test's fake clock.
void main() {
  late List<List<Offset>>? savedStrokes;
  late String? savedName;
  late Size? savedCanvasSize;

  setUp(() {
    savedStrokes = null;
    savedName = null;
    savedCanvasSize = null;
  });

  Future<void> openSheet(
    WidgetTester tester, {
    String? initialSignerName,
  }) async {
    await tester.pumpWidget(
      testApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSignatureCaptureSheet(
              context: context,
              initialSignerName: initialSignerName,
              onSave: (strokes, name, canvasSize) {
                savedStrokes = strokes;
                savedName = name;
                savedCanvasSize = canvasSize;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder canvas() => find.bySemanticsLabel('Draw signature');

  Future<void> drawStroke(WidgetTester tester) async {
    final origin = tester.getCenter(canvas());
    final gesture = await tester.startGesture(origin - const Offset(60, 20));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(15, 5));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the instructor name when one is known', (
    tester,
  ) async {
    await openSheet(tester, initialSignerName: 'Dive Instructor');

    expect(find.text('Dive Instructor'), findsOneWidget);
    expect(canvas(), findsOneWidget);
  });

  testWidgets('reports the canvas its own laid-out size, not a guess', (
    tester,
  ) async {
    await openSheet(tester, initialSignerName: 'Dive Instructor');
    await drawStroke(tester);

    // Measured before Save pops the sheet and the canvas leaves the tree.
    final laidOutSize = tester.getSize(canvas());

    await tester.tap(find.text('Save Signature'));
    await tester.pumpAndSettle();

    expect(savedStrokes, hasLength(1));
    expect(savedName, 'Dive Instructor');
    expect(savedCanvasSize, laidOutSize);
    // Guards against the assertion passing vacuously if the sheet ever
    // narrowed to the old hardcoded width.
    expect(laidOutSize.width, greaterThan(400));
  });

  testWidgets('refuses to save without a signer name', (tester) async {
    await openSheet(tester);
    await drawStroke(tester);

    await tester.tap(find.text('Save Signature'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter the signer name'), findsOneWidget);
    expect(savedStrokes, isNull);
  });

  testWidgets('Save stays disabled until something is drawn', (tester) async {
    await openSheet(tester, initialSignerName: 'Dive Instructor');

    FilledButton saveButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save Signature'),
        matching: find.byType(FilledButton),
      ),
    );

    expect(saveButton().onPressed, isNull);

    await drawStroke(tester);
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('Clear discards the strokes', (tester) async {
    await openSheet(tester, initialSignerName: 'Dive Instructor');
    await drawStroke(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save Signature'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('Cancel closes without saving', (tester) async {
    await openSheet(tester, initialSignerName: 'Dive Instructor');
    await drawStroke(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(canvas(), findsNothing);
    expect(savedStrokes, isNull);
  });

  // A plain tap wins the gesture arena uncontested and reaches onPanEnd with
  // a single point, which neither the painter nor the encoder draws.
  testWidgets('a tap on the canvas is not a signature', (tester) async {
    await openSheet(tester, initialSignerName: 'Dive Instructor');

    await tester.tapAt(tester.getCenter(canvas()));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save Signature'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(saveButton.onPressed, isNull);
    expect(savedStrokes, isNull);
  });
}
