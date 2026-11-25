import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The logo's typeface, for the app name where it stands beside the icon.
///
/// The brand wordmark is drawn in Inter Display ExtraBold
/// (scripts/brand/README.md), and the app bundles that one face so the name
/// in the About dialog, the Settings About card and the startup screen reads
/// as the logo does in every theme (issue #5014). Only the name uses it: the
/// rest of the app keeps its theme's text.
abstract final class BrandTypography {
  /// The family pubspec.yaml declares for the bundled wordmark face.
  static const String wordmarkFamily = 'Inter Display';

  /// The wordmark's weight: ExtraBold, the only weight bundled.
  static const FontWeight wordmarkWeight = FontWeight.w800;

  /// The font's licence, shipped beside the other bundled licences.
  static const _licence = 'assets/licenses/inter_display_ofl.txt';

  /// [base] (a theme slot, typically) set in the logo's face, keeping its
  /// size, colour and the rest. The theme's fallback list is dropped, so a
  /// glyph Inter lacks falls back to the platform font rather than to a
  /// theme face such as a monospace one.
  static TextStyle wordmark(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: wordmarkFamily,
        fontFamilyFallback: const <String>[],
        fontWeight: wordmarkWeight,
      );

  /// Adds the font's SIL Open Font License to the app's license page. Called
  /// once from `main()`; the text is read only when the page is opened.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(<String>[
        wordmarkFamily,
      ], await rootBundle.loadString(_licence));
    });
  }
}
