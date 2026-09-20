import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// #2218: the next-trip card on the trips landing panel built its subtitle as
/// a hardcoded English `'$date • In $days days'`, so every non-English diver
/// read an English countdown on the first screen the Trips tab shows them, and
/// a trip starting tomorrow read "In 1 days" in English too.
///
/// `trips_summary_upcomingSubtitle` is the composition template: it owns the
/// separator and the order of the two parts, both of which differ per locale.
/// The countdown itself is not restated here. It comes from the shared
/// `trips_list_countdown`, which the upcoming-trip banner already uses, so the
/// wording and its plural categories live in exactly one place.
void main() {
  Future<AppLocalizations> load(String languageCode) =>
      AppLocalizations.delegate.load(Locale(languageCode));

  /// The subtitle exactly as the card builds it.
  String subtitle(AppLocalizations l10n, int days) =>
      l10n.trips_summary_upcomingSubtitle(
        '2026-06-03',
        l10n.trips_list_countdown(days),
      );

  test('English agrees with its own count', () async {
    final l10n = await load('en');

    expect(subtitle(l10n, 4), '2026-06-03 • In 4 days');
    expect(subtitle(l10n, 1), '2026-06-03 • In 1 day');
    expect(subtitle(l10n, 0), '2026-06-03 • Starting today');
  });

  test('German picks its own plural form', () async {
    final l10n = await load('de');

    expect(subtitle(l10n, 4), '2026-06-03 • In 4 Tagen');
    expect(subtitle(l10n, 1), '2026-06-03 • In 1 Tag');
  });

  test('French keeps its own separator and reports zero as zero', () async {
    final l10n = await load('fr');

    // fr uses a hyphen rather than the bullet, which is why the separator
    // belongs to the translation and not to the widget.
    expect(subtitle(l10n, 1), '2026-06-03 - Dans 1 jour');
    // fr puts zero in the CLDR `one` category, so without the explicit `=0`
    // branch a count of zero would render as "Dans 0 jour".
    expect(subtitle(l10n, 0), "2026-06-03 - Départ aujourd'hui");
  });

  test('Hungarian puts the count first', () async {
    final l10n = await load('hu');

    expect(subtitle(l10n, 4), '2026-06-03 • 4 nap múlva');
  });
}
