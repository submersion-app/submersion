import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The planner, the gas calculators, the gas-model explanation, and the
/// rock-bottom about text only ever handle a volume rate (L/min), which the
/// app calls RMV. SAC is reserved for the pressure rate (bar/min). German
/// keeps AMV, its established term for the volume rate.
///
/// The planner's own gas-options labels are covered too: the state fields and
/// the stored columns keep their historical `sac` names, but every one of
/// them is a volume rate, so the label a diver reads must say RMV.
void main() {
  List<String> volumeOnlyLabels(AppLocalizations l10n) => [
    l10n.divePlanner_label_sacRate,
    l10n.divePlanner_semantics_sacRate('15', 'L'),
    l10n.divePlanner_gasOptions_sacBottom,
    l10n.divePlanner_gasOptions_sacDeco,
    l10n.divePlanner_gasOptions_sacFactor,
    l10n.gasCalculators_sacRate,
    l10n.gasCalculators_rockBottom_yourSac,
    l10n.gasCalculators_rockBottom_buddySac,
    l10n.gasCalculators_rockBottom_stressedSacRates,
    l10n.gasCalculators_rockBottom_stressedSacHint,
    l10n.gasCalculators_rockBottom_combinedStressedSac,
    l10n.gasCalculators_rockBottom_aboutDescription,
    l10n.settings_units_gasModel_explanation,
  ];

  test('the English volume-only labels say RMV', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.divePlanner_label_sacRate, 'RMV:');
    expect(en.divePlanner_semantics_sacRate('15', 'L'), 'RMV: 15 L per minute');
    expect(en.divePlanner_gasOptions_sacBottom, 'Bottom RMV');
    expect(en.divePlanner_gasOptions_sacDeco, 'Deco RMV');
    expect(en.divePlanner_gasOptions_sacFactor, 'RMV factor');
    expect(en.gasCalculators_sacRate, 'RMV');
    expect(en.gasCalculators_rockBottom_yourSac, 'Your RMV');
    expect(en.gasCalculators_rockBottom_buddySac, 'Buddy RMV');
    expect(en.gasCalculators_rockBottom_stressedSacRates, 'Stressed RMV');
    expect(
      en.gasCalculators_rockBottom_stressedSacHint,
      'Use a higher RMV to account for stress during an emergency',
    );
    expect(
      en.gasCalculators_rockBottom_combinedStressedSac,
      'Combined stressed RMV',
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('no volume-only label says SAC in ${locale.languageCode}', () {
      final l10n = lookupAppLocalizations(locale);
      for (final label in volumeOnlyLabels(l10n)) {
        expect(label, isNot(contains('SAC')), reason: label);
        // French used "CAS" for the same acronym in three keys.
        expect(label, isNot(contains('CAS')), reason: label);
      }
    });
  }

  test('German keeps AMV for the volume rate', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(de.gasCalculators_rockBottom_yourSac, 'Dein AMV');
    expect(de.divePlanner_label_sacRate, 'AMV:');
    expect(de.divePlanner_gasOptions_sacBottom, 'Grund-AMV');
    expect(de.divePlanner_gasOptions_sacDeco, 'Deko-AMV');
  });
}
