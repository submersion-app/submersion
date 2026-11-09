// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #4331: the German UI addressed the user with
/// the formal "Sie", while newer strings already used "du". Leisure apps and
/// divers talking to each other use the informal form, so every string now
/// does.
///
/// A capitalised "Sie", "Ihnen" or "Ihr..." in the middle of a sentence can
/// only be the formal address: the third-person "sie" (she, they, it) and
/// "ihr" (her, their, its) are lowercase there. At the start of a sentence
/// the capital is ambiguous ("Sie wird gespeichert" means "it is saved"), so
/// those positions are not checked.
void main() {
  late AppLocalizations de;

  setUpAll(() {
    de = lookupAppLocalizations(const Locale('de'));
  });

  final formal = RegExp(r'\b(Sie|Ihnen|Ihr|Ihre|Ihren|Ihrem|Ihrer|Ihres)\b');

  /// Characters after which a new sentence (or a plural branch, or a quoted
  /// phrase) begins, so a capital there says nothing about formality.
  const sentenceStarts = {'.', '!', '?', ':', '\n', '{', '"', '„', '“'};

  bool atSentenceStart(String value, int index) {
    final before = value.substring(0, index).trimRight();
    if (before.isEmpty) return true;
    return sentenceStarts.contains(before[before.length - 1]);
  }

  test('no German string addresses the user formally', () {
    final arb =
        json.decode(File('lib/l10n/arb/app_de.arb').readAsStringSync())
            as Map<String, dynamic>;

    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      for (final match in formal.allMatches(value)) {
        if (!atSentenceStart(value, match.start)) {
          offenders.add('$key = $value');
          break;
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'German strings must use "du", not "Sie". Offending keys:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the generated German localizations use the informal form', () {
    expect(de.setup_profile_title, 'Erstelle dein Profil');
    expect(
      de.buddies_dialog_discardMessage,
      'Du hast nicht gespeicherte Änderungen. '
      'Möchtest du diese wirklich verwerfen?',
    );
    expect(
      de.insights_observations_diveCountMilestone('100', '1.1.2026'),
      'Du hast am 1.1.2026 100 Tauchgänge erreicht',
    );
  });
}
