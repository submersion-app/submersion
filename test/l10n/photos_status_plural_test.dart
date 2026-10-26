// The Photos page status line counts uploads (issue #3482 phase 4). German,
// Dutch and Hebrew conjugate by how many items move, the Romance languages
// agree "copied" with the copied count, and Arabic counts with a noun that
// takes the dual for 2, the plural for 3 to 10 and the singular accusative
// for 11 to 99.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

void main() {
  test('German conjugates by the uploading count', () {
    final de = _l('de');
    expect(de.settings_photos_status_uploadingOnly(1), '1 wird hochgeladen');
    expect(de.settings_photos_status_uploadingOnly(2), '2 werden hochgeladen');
    expect(
      de.settings_photos_status_waitingRetry(1),
      '1 wartet auf einen neuen Versuch',
    );
    expect(
      de.settings_photos_status_uploading(3, 10, 1),
      '3 von 10 kopiert, 1 wird hochgeladen',
    );
  });

  test('Dutch and Hebrew conjugate by the count too', () {
    expect(_l('nl').settings_photos_status_waitingRetry(1), contains('wacht '));
    expect(_l('nl').settings_photos_status_uploadingOnly(1), contains('wordt'));
    expect(_l('he').settings_photos_status_waitingRetry(1), contains('ממתין '));
  });

  test('Romance languages agree with the copied count', () {
    expect(_l('es').settings_photos_status_copied(1, 10), '1 de 10 copiada');
    expect(_l('es').settings_photos_status_copied(4, 10), '4 de 10 copiadas');
    expect(_l('fr').settings_photos_status_copied(1, 3), contains('copiée'));
    expect(_l('it').settings_photos_status_copied(1, 3), contains('copiata'));
    expect(
      _l('pt').settings_photos_status_uploading(1, 3, 2),
      contains('copiada,'),
    );
  });

  test('Arabic takes the dual, plural and accusative forms', () {
    final ar = _l('ar');
    expect(ar.settings_photos_status_uploadingOnly(2), contains('عنصران'));
    expect(ar.settings_photos_status_uploadingOnly(5), contains('5 عناصر'));
    expect(ar.settings_photos_status_waitingRetry(11), contains('11 عنصرًا'));
    expect(ar.settings_photos_status_uploading(1, 4, 2), contains('عنصران'));
    expect(ar.settings_photos_status_copied(1, 2), contains('عنصرين'));
  });

  test('English keeps one form', () {
    final en = _l('en');
    expect(en.settings_photos_status_uploadingOnly(1), '1 uploading');
    expect(en.settings_photos_status_copied(7, 10), '7 of 10 copied');
  });
}
