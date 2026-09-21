import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Flutter's `gen-l10n` compiles an ARB `=1{...}` branch into the CLDR **`one`
/// plural category**, not an exact-value match. French and Portuguese put zero
/// in that category (`one: i = 0,1`), so a singular branch that spells the
/// digit out ("1 plongée") reports one item when the real count is zero.
///
/// Issue #2084: a buddy with no dives read "1 plongée" in French.
void main() {
  Future<AppLocalizations> load(String languageCode) =>
      AppLocalizations.delegate.load(Locale(languageCode));

  test('French reports zero dives as zero, not one', () async {
    final l10n = await load('fr');

    expect(l10n.buddies_label_diveCount(0), contains('0'));
    expect(l10n.buddies_label_diveCount(0), isNot(contains('1')));
    // The singular and plural forms must still be right either side of it.
    expect(l10n.buddies_label_diveCount(1), '1 plongée');
    expect(l10n.buddies_label_diveCount(2), '2 plongées');
  });

  test('Portuguese reports zero dives as zero, not one', () async {
    final l10n = await load('pt');

    expect(l10n.buddies_label_diveCount(0), contains('0'));
    expect(l10n.buddies_label_diveCount(0), isNot(contains('1')));
    expect(l10n.buddies_label_diveCount(1), '1 mergulho');
    expect(l10n.buddies_label_diveCount(2), '2 mergulhos');
  });

  test('English is unaffected: zero falls in the other category', () async {
    final l10n = await load('en');

    expect(l10n.buddies_label_diveCount(0), '0 dives');
    expect(l10n.buddies_label_diveCount(1), '1 dive');
    expect(l10n.buddies_label_diveCount(2), '2 dives');
  });
}
