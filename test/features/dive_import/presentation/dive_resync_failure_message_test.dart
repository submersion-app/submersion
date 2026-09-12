import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/presentation/dive_resync_failure_message.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  test('every failure reason has a sentence of its own', () {
    // A closed enum only pays off if the mapping covers all of it: a reason
    // sharing another's sentence would leave the diver guessing.
    final en = AppLocalizationsEn();
    final messages = <String>{};

    for (final reason in DiveResyncFailure.values) {
      final message = diveResyncFailureMessage(en, reason);
      expect(message, startsWith('Could not resync: '));
      expect(messages.add(message), isTrue, reason: 'duplicate for $reason');
    }
  });

  test('the sentences are translated, not English inside a wrapper', () {
    // The reasons used to be English strings built in the service layer and
    // interpolated into the translated sentence, so ten of eleven locales
    // showed a half-translated message.
    final de = AppLocalizationsDe();

    for (final reason in DiveResyncFailure.values) {
      expect(
        diveResyncFailureMessage(de, reason),
        startsWith('Resynchronisierung fehlgeschlagen: '),
      );
    }
  });
}
