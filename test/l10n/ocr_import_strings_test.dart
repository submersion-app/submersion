import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every locale must carry the OCR import strings: gen-l10n falls back to
/// English silently, so an untranslated locale would ship unnoticed.
void main() {
  test('every supported locale translates the OCR import strings', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final strings = <String>[
        l10n.diveLog_listPage_bottomSheet_scanPaperLog,
        l10n.ocrImport_scanPage_processing,
        l10n.ocrImport_scanPage_pickPhoto,
        l10n.ocrImport_scanPage_takePhoto,
        l10n.ocrImport_scanPage_nothingRead,
        l10n.ocrImport_scanPage_engineMissing,
        l10n.ocrImport_editPage_photoAttachFailed,
      ];
      for (final value in strings) {
        expect(value, isNotEmpty, reason: 'locale $locale');
      }
    }
  });
}
