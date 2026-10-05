import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/certifications/presentation/utils/currency_severity_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How certification currency rules and statuses read (issue #2267).
/// Built-in rules resolve to l10n at render time so a seeded row never
/// stores a translated string; custom rules show the diver's own words.
const _builtInIds = [
  'padi_reactivate',
  'ssi_skills_update',
  'generic_refresher',
  'first_aid_24mo',
  'pro_membership_annual',
  'gue_revalidation',
  'ffessm_licence_annual',
  'cave_currency',
  'rebreather_currency',
  'deco_currency',
  'card_expiry',
];

CurrencyRule _rule(String id, {bool builtIn = true, String? text}) =>
    CurrencyRule(
      id: id,
      name: 'Stored name',
      clockKind: CurrencyClockKind.activity,
      lapseDays: 365,
      leadDays: 90,
      isBuiltIn: builtIn,
      advisoryText: text,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('every built-in id has a name and an advisory in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final id in _builtInIds) {
        expect(
          builtInCurrencyRuleName(l10n, id),
          isNotEmpty,
          reason: '$locale $id',
        );
        expect(
          builtInCurrencyRuleAdvisory(l10n, id),
          isNotEmpty,
          reason: '$locale $id',
        );
      }
    }
  });

  test('no built-in advisory says required', () {
    for (final id in _builtInIds) {
      expect(
        builtInCurrencyRuleAdvisory(en, id)!.toLowerCase(),
        isNot(contains('required')),
        reason: id,
      );
    }
  });

  test('a built-in shows its translation, not the stored name', () {
    final rule = _rule('cave_currency');
    expect(currencyRuleName(en, rule), 'Cave currency');
    expect(currencyRuleAdvisory(en, rule), contains('Cave skills fade'));
  });

  test('a custom rule shows its own name and text, untranslated', () {
    final rule = _rule('cave_currency', builtIn: false, text: 'My own note');
    expect(currencyRuleName(en, rule), 'Stored name');
    expect(currencyRuleAdvisory(en, rule), 'My own note');
  });

  test('an unknown id is null, so a rule from a newer build falls back', () {
    expect(builtInCurrencyRuleName(en, 'from_the_future'), isNull);
    expect(currencyRuleName(en, _rule('from_the_future')), 'Stored name');
  });

  test('severity and event type labels', () {
    expect(CurrencySeverity.lapsed.label(en), 'Lapsed');
    expect(CurrencySeverity.dueSoon.label(en), 'Due soon');
    expect(CurrencySeverity.current.label(en), 'Current');
    expect(CurrencyEventType.revalidation.label(en), 'Revalidation');
  });

  test('lapsed is alert, due soon is warn, current has no swatch', () {
    const colors = StatusColors.light;
    expect(
      currencySeveritySwatch(colors, CurrencySeverity.lapsed),
      colors.alert,
    );
    expect(
      currencySeveritySwatch(colors, CurrencySeverity.dueSoon),
      colors.warn,
    );
    expect(currencySeveritySwatch(colors, CurrencySeverity.current), isNull);
  });
}
