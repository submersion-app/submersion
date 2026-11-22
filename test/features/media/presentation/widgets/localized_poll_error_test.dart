import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/features/media/presentation/widgets/synology_password_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  test('the app\'s own password errors read in the diver\'s language', () {
    expect(
      localizedPollError(de, kSynologyPasswordMissingMessage),
      'Diese Synology-Photos-Freigabe braucht ihr Passwort.',
    );
    // A status: nothing to type into where it shows.
    expect(
      localizedPollError(de, kSynologyPasswordRejectedMessage),
      'Die Freigabe hat das gespeicherte Passwort nicht akzeptiert.',
    );
  });

  test('a source\'s own error is shown as recorded', () {
    expect(localizedPollError(de, 'HTTP 503'), 'HTTP 503');
  });
}
