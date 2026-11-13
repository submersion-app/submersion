// Issue #4485: the planner's dive pickers titled a dive with no name by its
// number alone, so Follow a dive listed numbers with no site.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/planner/presentation/widgets/link_dive_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/l10n/arb/app_localizations_fr.dart';
import 'package:submersion/l10n/arb/app_localizations_hu.dart';

void main() {
  const units = UnitFormatter(AppSettings());
  const blueHole = DiveSite(id: 's1', name: 'Blue Hole');
  final l10n = AppLocalizationsEn();
  final when = DateTime.utc(2026, 11, 12, 9);
  final date = units.formatDate(when);

  String title(Dive dive) => diveRowLabels(dive, units, l10n).title;

  test('a numbered dive at a site shows both', () {
    expect(
      title(Dive(id: 'a', diveNumber: 42, dateTime: when, site: blueHole)),
      '#42 · Blue Hole',
    );
  });

  test('the dive\'s own name stands in for its site', () {
    expect(
      title(
        Dive(
          id: 'a',
          diveNumber: 41,
          name: 'Night Dive at the Pier',
          dateTime: when,
          site: blueHole,
        ),
      ),
      '#41 · Night Dive at the Pier',
    );
  });

  test('a blank name falls back to the site', () {
    expect(
      title(
        Dive(
          id: 'a',
          diveNumber: 42,
          name: '  ',
          dateTime: when,
          site: blueHole,
        ),
      ),
      '#42 · Blue Hole',
    );
  });

  test('a blank site name counts as no site', () {
    expect(
      title(
        Dive(
          id: 'a',
          diveNumber: 42,
          dateTime: when,
          site: const DiveSite(id: 's2', name: ' '),
        ),
      ),
      '#42',
    );
  });

  test('an unnumbered dive shows its site alone', () {
    expect(title(Dive(id: 'a', dateTime: when, site: blueHole)), 'Blue Hole');
  });

  test('a numbered dive with no site or name shows its number', () {
    expect(title(Dive(id: 'a', diveNumber: 7, dateTime: when)), '#7');
  });

  test('a dive with nothing else to go by shows its date', () {
    expect(title(Dive(id: 'a', dateTime: when)), date);
  });

  test('the dive number follows the language\'s own form', () {
    final dive = Dive(id: 'a', diveNumber: 42, dateTime: when, site: blueHole);
    expect(
      diveRowLabels(dive, units, AppLocalizationsFr()).title,
      'n°42 · Blue Hole',
    );
    expect(
      diveRowLabels(
        Dive(id: 'b', diveNumber: 42, dateTime: when),
        units,
        AppLocalizationsHu(),
      ).title,
      '#42.',
    );
  });

  test('the subtitle keeps the date, depth and runtime', () {
    final labels = diveRowLabels(
      Dive(
        id: 'a',
        diveNumber: 42,
        dateTime: when,
        site: blueHole,
        maxDepth: 24,
        runtime: const Duration(minutes: 48),
      ),
      units,
      l10n,
    );
    expect(labels.subtitle, [date, units.formatDepth(24), '48′'].join(' · '));
  });
}
