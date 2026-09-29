import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';

const _styles = ['Regular', 'Bold', 'Italic', 'BoldItalic'];

/// Where the Flutter SDK keeps its own copy of Roboto.
String _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final artifacts = root != null
      ? p.join(root, 'bin', 'cache', 'artifacts')
      // flutter_tester lives in bin/cache/artifacts/engine/<platform>/.
      : p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable)));
  return p.join(artifacts, 'material_fonts');
}

/// Load Roboto into [PdfFonts] from the Flutter SDK, with no network.
///
/// [PdfFonts] downloads Roboto on first use. The test harness refuses every
/// request that leaves the machine (test/helpers/blocked_network.dart), the
/// printing package then falls back to Helvetica without throwing, and
/// [PdfFonts] caches that. Seeding the printing cache first means the download
/// is never attempted.
Future<void> loadPdfRoboto() async {
  for (final style in _styles) {
    final file = File(p.join(_materialFontsDir(), 'Roboto-$style.ttf'));
    await PdfBaseCache.defaultCache.add(
      'Roboto-$style',
      await file.readAsBytes(),
    );
  }
  PdfFonts.instance.reset();
  await PdfFonts.instance.initialize();
}

/// Undo [loadPdfRoboto], so later files get Helvetica as they expect.
Future<void> unloadPdfRoboto() async {
  for (final style in _styles) {
    await PdfBaseCache.defaultCache.remove('Roboto-$style');
  }
  PdfFonts.instance.reset();
}
