import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Certification currency conflicts read in the words of the currency
/// dialogs (#2267), not in another record's words for the same column name.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a history entry type is labelled as a currency event, not a '
      'profile event', () {
    final field = conflictFieldFor('certificationCurrencyEvents', 'eventType');
    expect(field.label(l10n), l10n.certifications_currency_eventDialog_type);
    expect(field.kind, FieldKind.enumValue);
    expect(
      field.enumLabel!(l10n, 'skillsUpdate'),
      l10n.certifications_currency_eventType_skillsUpdate,
    );
    expect(field.enumLabel!(l10n, 'fromANewerPeer'), isNull);

    final profileEvent = conflictFieldFor('diveProfileEvents', 'eventType');
    expect(profileEvent.label(l10n), l10n.settings_conflict_field_eventType);
  });

  test('a rule clock names what it counts from', () {
    final field = conflictFieldFor('certificationCurrencyRules', 'clockKind');
    expect(field.label(l10n), l10n.currencyRules_dialog_clock);
    expect(
      field.enumLabel!(l10n, 'activity'),
      l10n.currencyRules_dialog_clock_activity,
    );
    expect(
      field.enumLabel!(l10n, 'date'),
      l10n.currencyRules_dialog_clock_date,
    );
  });

  test('scope and mapping lists show as changed, never as raw JSON', () {
    for (final column in [
      'applicableAgencies',
      'applicableLevels',
      'countedDiveTypeIds',
      'countedDiveModes',
    ]) {
      expect(
        conflictFieldFor('certificationCurrencyRules', column).kind,
        FieldKind.opaque,
        reason: column,
      );
    }
  });
}
