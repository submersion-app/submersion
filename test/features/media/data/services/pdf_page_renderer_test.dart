import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';

/// pdfium cannot load under flutter_test: the Flutter path needs the
/// bundled plugin binary (not present in the test harness) and the Dart
/// path needs either the PDFIUM_PATH environment variable or dart
/// native-assets support (flutter_test provides neither). Worse, a failed
/// engine init crashes pdfrx's background worker isolate, which hangs the
/// calling future to timeout rather than throwing. So these tests only
/// run when the host explicitly provides a pdfium build via PDFIUM_PATH;
/// the in-app runtime always has the bundled plugin binary. Exercised by
/// manual desktop smoke tests otherwise.
final _pdfiumAvailable = () {
  final path = Platform.environment['PDFIUM_PATH'];
  return path != null && File(path).existsSync();
}();

void main() {
  setUpAll(() {
    // Pure-Dart initializer: picks up PDFIUM_PATH.
    PdfPageRenderer.initializer = pdfrxInitialize;
  });

  // These run everywhere: a throwing initializer means the renderer bails
  // out before it can touch pdfium, so no native binary is involved. They
  // are declared first so they observe the renderer's un-initialized
  // state even on a host where PDFIUM_PATH is set.
  group('engine bootstrap failure', () {
    late Future<void> Function() previousInitializer;
    var initializerCalls = 0;

    setUp(() {
      previousInitializer = PdfPageRenderer.initializer;
      initializerCalls = 0;
      PdfPageRenderer.initializer = () async {
        initializerCalls++;
        throw Exception('pdfium unavailable');
      };
    });

    tearDown(() => PdfPageRenderer.initializer = previousInitializer);

    test('returns null instead of throwing for a file source', () async {
      final result = await PdfPageRenderer.renderFirstPageJpeg(
        file: File('test/fixtures/sample.pdf'),
      );
      expect(result, isNull);
      expect(
        initializerCalls,
        1,
        reason: 'bootstrap must be attempted before opening the document',
      );
    });

    test('returns null instead of throwing for a bytes source', () async {
      final result = await PdfPageRenderer.renderFirstPageJpeg(
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );
      expect(result, isNull);
      expect(initializerCalls, 1);
    });

    test('retries the bootstrap on the next call after a failure', () async {
      expect(
        await PdfPageRenderer.renderFirstPageJpeg(bytes: Uint8List(4)),
        isNull,
      );
      expect(
        await PdfPageRenderer.renderFirstPageJpeg(bytes: Uint8List(4)),
        isNull,
      );
      expect(
        initializerCalls,
        2,
        reason: 'a failed bootstrap must not be latched as initialized',
      );
    });
  });

  // Issue #3996. Unlike the pdfium tests below, these run in CI.
  group('renderWholePage', () {
    test('sizes the full page and leaves the crop window unset', () async {
      final page = _RecordingPage(841.89, 595.28);

      await PdfPageRenderer.renderWholePage(page, 1024);

      expect(page.renderArgs[#fullWidth], 1024);
      expect(page.renderArgs[#fullHeight], 724);
      expect(page.renderArgs[#width], isNull);
      expect(page.renderArgs[#height], isNull);
    });

    test(
      'scales a portrait page by its height, to the nearest pixel',
      () async {
        final page = _RecordingPage(612, 792);

        await PdfPageRenderer.renderWholePage(page, 1536);

        expect(page.renderArgs[#fullWidth], 1187);
        expect(page.renderArgs[#fullHeight], 1536);
      },
    );
  });

  test('renders first page of a pdf to a jpeg within maxDimension', () async {
    final bytes = await PdfPageRenderer.renderFirstPageJpeg(
      file: File('test/fixtures/sample.pdf'),
      maxDimension: 256,
    );
    expect(bytes, isNotNull);
    final decoded = img.decodeJpg(bytes!);
    expect(decoded, isNotNull);
    expect(
      decoded!.width <= 256 && decoded.height <= 256,
      isTrue,
      reason: 'longest edge must be capped',
    );
  }, skip: _pdfiumAvailable ? false : 'needs PDFIUM_PATH (see header note)');

  test('returns null for garbage bytes', () async {
    final bytes = await PdfPageRenderer.renderFirstPageJpeg(
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(bytes, isNull);
  }, skip: _pdfiumAvailable ? false : 'needs PDFIUM_PATH (see header note)');

  // Issue #3996. pdfium blanks the page only when the target is larger than
  // the page's 72 dpi size (842 points wide here); below that the old crop
  // stays inside this solid red page and looks correct. So this test needs a
  // target above 842, which leaves the old code's far corner white.
  test(
    'fills the rendered bitmap to every edge, not just its own corner',
    () async {
      final bytes = await PdfPageRenderer.renderFirstPageJpeg(
        file: File('test/fixtures/landscape_fullbleed.pdf'),
        maxDimension: 1024,
      );
      expect(bytes, isNotNull);
      final decoded = img.decodeJpg(bytes!);
      expect(decoded, isNotNull);
      // A4 landscape, 1.414:1. The crop bug kept this right too, since the
      // bitmap took its size from the same request, so the corner below is
      // what catches it.
      expect(decoded!.width / decoded.height, closeTo(1.414, 0.05));
      // A couple of pixels in, so JPEG compression at the exact edge cannot
      // produce a false negative.
      final corner = decoded.getPixel(decoded.width - 2, decoded.height - 2);
      expect(corner.r, greaterThan(200));
      expect(corner.g, lessThan(30));
      expect(corner.b, lessThan(30));
    },
    skip: _pdfiumAvailable ? false : 'needs PDFIUM_PATH (see header note)',
  );
}

/// A page that records what [PdfPage.render] was asked for, so the arguments
/// can be checked on a host with no pdfium binary.
class _RecordingPage implements PdfPage {
  _RecordingPage(this.width, this.height);

  @override
  final double width;

  @override
  final double height;

  Map<Symbol, dynamic> renderArgs = const {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #render) return super.noSuchMethod(invocation);
    renderArgs = invocation.namedArguments;
    return Future<PdfImage?>.value();
  }
}
