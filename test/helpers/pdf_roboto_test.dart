import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';

import 'pdf_roboto.dart';

const _styles = ['Regular', 'Bold', 'Italic', 'BoldItalic'];

void main() {
  // The test binding answers every HTTP request with 400, so a font that
  // loads here did not come from the network.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(unloadPdfRoboto);

  test('loads all four Roboto styles with the network blocked', () async {
    await loadPdfRoboto();

    expect(PdfFonts.instance.isInitialized, isTrue);
    expect(PdfFonts.instance.regular, isA<pw.TtfFont>());
    expect(PdfFonts.instance.bold, isA<pw.TtfFont>());
    expect(PdfFonts.instance.italic, isA<pw.TtfFont>());
    expect(PdfFonts.instance.boldItalic, isA<pw.TtfFont>());
  });

  test('unloading leaves nothing behind for the next file', () async {
    await loadPdfRoboto();

    await unloadPdfRoboto();

    expect(PdfFonts.instance.isInitialized, isFalse);
    for (final style in _styles) {
      expect(
        await PdfBaseCache.defaultCache.contains('Roboto-$style'),
        isFalse,
        reason: style,
      );
    }
  });

  test(
    'without the helper the blocked download falls back to Helvetica',
    () async {
      await PdfFonts.instance.initialize();

      expect(PdfFonts.instance.regular, isNot(isA<pw.TtfFont>()));
    },
  );
}
