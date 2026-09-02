import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_dialog.dart';

import '../../../helpers/test_app.dart';

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 60, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Alternates real async progress with frame pumps.
///
/// The dialog does two things fakeAsync cannot drive: `instantiateImageCodec`
/// decodes on the engine, and `encodeStoredImage` spawns a real isolate
/// through `compute`. Both need `runAsync` to make progress. Pumping is still
/// manual rather than `pumpAndSettle`, because the dialog shows a
/// CircularProgressIndicator during each of those phases and an animating
/// spinner never settles.
Future<void> _settle(WidgetTester tester, {int rounds = 15}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('cancel returns null', (tester) async {
    Uint8List? result;
    var completed = false;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showProfilePhotoCropDialog(
                context: context,
                sourceBytes: _jpeg(800, 600),
                declaredName: 'pick.jpg',
              );
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Adjust Photo'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('save returns encoded square bytes', (tester) async {
    Uint8List? result;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showProfilePhotoCropDialog(
                context: context,
                sourceBytes: _jpeg(800, 600),
                declaredName: 'pick.jpg',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.tap(find.text('Save'));
    await _settle(tester, rounds: 30);

    expect(result, isNotNull);
    final out = img.decodeImage(result!)!;
    expect(out.width, out.height, reason: 'the stored photo must be square');
    expect(out.width, lessThanOrEqualTo(512));
  });

  testWidgets('the dialog shows the repositioning hint', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showProfilePhotoCropDialog(
              context: context,
              sourceBytes: _jpeg(400, 400),
              declaredName: 'pick.jpg',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Drag to reposition, pinch to zoom'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('the default crop is the centre of a landscape photo', (
    tester,
  ) async {
    // Left third red, middle third green, right third blue. With
    // `constrained: false` an uninitialised transform anchors the child at the
    // origin, so the default crop would take the RED left edge. Centring the
    // initial view makes it GREEN, which also matches what the codec does when
    // no crop rect is supplied.
    final source = img.Image(width: 900, height: 300);
    img.fillRect(
      source,
      x1: 0,
      y1: 0,
      x2: 299,
      y2: 299,
      color: img.ColorRgb8(255, 0, 0),
    );
    img.fillRect(
      source,
      x1: 300,
      y1: 0,
      x2: 599,
      y2: 299,
      color: img.ColorRgb8(0, 255, 0),
    );
    img.fillRect(
      source,
      x1: 600,
      y1: 0,
      x2: 899,
      y2: 299,
      color: img.ColorRgb8(0, 0, 255),
    );
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 95));

    Uint8List? result;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showProfilePhotoCropDialog(
                context: context,
                sourceBytes: bytes,
                declaredName: 'wide.jpg',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester, rounds: 30);

    expect(result, isNotNull);
    final out = img.decodeImage(result!)!;
    final centre = out.getPixel(out.width ~/ 2, out.height ~/ 2);
    expect(
      centre.g,
      greaterThan(centre.r),
      reason: 'the default crop must centre on the photo, not its left edge',
    );
    expect(centre.g, greaterThan(centre.b));
  });

  testWidgets('undecodable bytes report the reason instead of hanging', (
    tester,
  ) async {
    // instantiateImageCodec throws on bytes it cannot read. Unhandled, the
    // exception escapes into the zone and the dialog sits on its spinner with
    // no explanation. A picked file is not guaranteed to be a valid image: it
    // may be corrupt, or a contact photo in a format the engine cannot decode.
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showProfilePhotoCropDialog(
              context: context,
              sourceBytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]),
              declaredName: 'broken.jpg',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(
      find.text('That file could not be read as an image.'),
      findsOneWidget,
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the dialog must not sit on a spinner forever',
    );
    // Cancel remains the way out.
    expect(find.text('Cancel'), findsOneWidget);
  });
}
