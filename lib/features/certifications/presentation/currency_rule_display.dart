import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The localized name of a built-in currency rule (issue #2267), or null for
/// an id this build does not know, such as a rule a newer build seeded.
String? builtInCurrencyRuleName(AppLocalizations l10n, String id) =>
    switch (id) {
      'padi_reactivate' => l10n.currencyRule_padi_reactivate_name,
      'ssi_skills_update' => l10n.currencyRule_ssi_skills_update_name,
      'generic_refresher' => l10n.currencyRule_generic_refresher_name,
      'tdi_refresher' => l10n.currencyRule_tdi_refresher_name,
      'first_aid_24mo' => l10n.currencyRule_first_aid_24mo_name,
      'pro_membership_annual' => l10n.currencyRule_pro_membership_annual_name,
      'gue_revalidation' => l10n.currencyRule_gue_revalidation_name,
      'ffessm_licence_annual' => l10n.currencyRule_ffessm_licence_annual_name,
      'cave_currency' => l10n.currencyRule_cave_currency_name,
      'rebreather_currency' => l10n.currencyRule_rebreather_currency_name,
      'deco_currency' => l10n.currencyRule_deco_currency_name,
      kCardExpiryRuleId => l10n.currencyRule_card_expiry_name,
      _ => null,
    };

/// The localized advisory sentence of a built-in rule, or null for an
/// unknown id.
String? builtInCurrencyRuleAdvisory(AppLocalizations l10n, String id) =>
    switch (id) {
      'padi_reactivate' => l10n.currencyRule_padi_reactivate_advisory,
      'ssi_skills_update' => l10n.currencyRule_ssi_skills_update_advisory,
      'generic_refresher' => l10n.currencyRule_generic_refresher_advisory,
      'tdi_refresher' => l10n.currencyRule_tdi_refresher_advisory,
      'first_aid_24mo' => l10n.currencyRule_first_aid_advisory,
      'pro_membership_annual' => l10n.currencyRule_pro_membership_advisory,
      'gue_revalidation' => l10n.currencyRule_gue_revalidation_advisory,
      'ffessm_licence_annual' => l10n.currencyRule_ffessm_licence_advisory,
      'cave_currency' => l10n.currencyRule_cave_currency_advisory,
      'rebreather_currency' => l10n.currencyRule_rebreather_currency_advisory,
      'deco_currency' => l10n.currencyRule_deco_currency_advisory,
      kCardExpiryRuleId => l10n.currencyRule_card_expiry_advisory,
      _ => null,
    };

/// A rule's name as the diver reads it: a built-in's translation, else the
/// stored name. Custom rules carry the diver's own words, never translated.
String currencyRuleName(AppLocalizations l10n, CurrencyRule rule) =>
    (rule.isBuiltIn ? builtInCurrencyRuleName(l10n, rule.id) : null) ??
    rule.name;

/// A rule's advisory sentence: a built-in's translation, else the diver's
/// own note, if any.
String? currencyRuleAdvisory(AppLocalizations l10n, CurrencyRule rule) =>
    rule.isBuiltIn
    ? builtInCurrencyRuleAdvisory(l10n, rule.id) ?? rule.advisoryText
    : rule.advisoryText;

extension CurrencySeverityDisplay on CurrencySeverity {
  String label(AppLocalizations l10n) => switch (this) {
    CurrencySeverity.current => l10n.certifications_currency_status_current,
    CurrencySeverity.dueSoon => l10n.certifications_currency_status_dueSoon,
    CurrencySeverity.lapsed => l10n.certifications_currency_status_lapsed,
  };
}

extension CurrencyEventTypeDisplay on CurrencyEventType {
  String label(AppLocalizations l10n) => switch (this) {
    CurrencyEventType.refresher =>
      l10n.certifications_currency_eventType_refresher,
    CurrencyEventType.renewal => l10n.certifications_currency_eventType_renewal,
    CurrencyEventType.revalidation =>
      l10n.certifications_currency_eventType_revalidation,
    CurrencyEventType.skillsUpdate =>
      l10n.certifications_currency_eventType_skillsUpdate,
    CurrencyEventType.other => l10n.certifications_currency_eventType_other,
  };
}
