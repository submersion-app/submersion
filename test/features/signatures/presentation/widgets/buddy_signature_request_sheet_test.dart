import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart';

import '../../../../helpers/test_app.dart';

/// Covers the capture sheet itself, which had no test at all before #1358 --
/// the gap that let a signature save fail silently for as long as it did.
///
/// The test stops at the sheet's `onSave` boundary and never reaches
/// `strokesToPng`: that finishes through `Picture.toImage`, whose future the
/// engine completes rather than a timer, so it hangs under a widget test's
/// fake clock. Everything above that line is widget behaviour and belongs
/// here; the encode and the insert are covered in
/// buddy_signature_save_notifier_test.dart.
void main() {
  final buddyWithRole = BuddyWithRole(
    buddy: Buddy(
      id: 'buddy-1',
      name: 'Reef Buddy',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    role: DiveRole.builtInBuddy(),
  );

  late List<List<Offset>>? savedStrokes;
  late Size? savedCanvasSize;

  setUp(() {
    savedStrokes = null;
    savedCanvasSize = null;
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showBuddySignatureRequestSheet(
              context: context,
              buddyWithRole: buddyWithRole,
              onSave: (strokes, canvasSize) {
                savedStrokes = strokes;
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

  /// Drags across the canvas in several steps, so the pan recognizer wins the
  /// arena and onPanUpdate fires more than once. A single jump yields a
  /// one-point stroke, which draws nothing.
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

  testWidgets('hands off to the buddy before showing the canvas', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Hand your device to'), findsOneWidget);
    expect(find.text('Reef Buddy'), findsOneWidget);
    // The canvas stays hidden until the buddy is holding the device.
    expect(canvas(), findsNothing);

    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();

    expect(canvas(), findsOneWidget);
  });

  testWidgets('reports the canvas its own laid-out size, not a guess', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();

    await drawStroke(tester);

    // Measured before Done pops the sheet and the canvas leaves the tree.
    final laidOutSize = tester.getSize(canvas());

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(savedStrokes, isNotNull);
    expect(savedStrokes, hasLength(1));
    expect(savedStrokes!.single.length, greaterThan(1));

    // The heart of issue #1358's cropping half: the size handed to the
    // encoder has to be the size the strokes were drawn on. A hardcoded
    // 400x200 silently cropped everything past x = 400.
    expect(savedCanvasSize, isNotNull);
    expect(savedCanvasSize, laidOutSize);
    // Guards against the assertion passing vacuously if the sheet ever
    // narrowed to the old hardcoded width.
    expect(laidOutSize.width, greaterThan(400));
  });

  testWidgets('the sheet closes once the signature is handed back', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();
    await drawStroke(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(canvas(), findsNothing);
  });

  testWidgets('Done stays disabled until something is drawn', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();

    FilledButton doneButton() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Done'), matching: find.byType(FilledButton)),
    );

    expect(doneButton().onPressed, isNull);

    await drawStroke(tester);
    expect(doneButton().onPressed, isNotNull);
  });

  testWidgets('Clear discards the strokes and re-disables Done', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();
    await drawStroke(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    final doneButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Done'), matching: find.byType(FilledButton)),
    );
    expect(doneButton.onPressed, isNull);
    expect(savedStrokes, isNull);
  });

  testWidgets('Cancel closes without saving', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();
    await drawStroke(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(canvas(), findsNothing);
    expect(savedStrokes, isNull);
  });

  // A plain tap wins the gesture arena uncontested and reaches onPanEnd with
  // a single point. The painter and the encoder both skip such a stroke, so
  // storing it would enable Done and save a blank signature.
  testWidgets('a tap on the canvas is not a signature', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(canvas()));
    await tester.pumpAndSettle();

    final doneButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Done'), matching: find.byType(FilledButton)),
    );
    expect(doneButton.onPressed, isNull);
    expect(savedStrokes, isNull);
  });
}
