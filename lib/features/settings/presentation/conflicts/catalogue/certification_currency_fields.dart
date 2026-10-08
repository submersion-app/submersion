import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for certification currency rules, prefs
/// and history entries (#2267). Labels reuse the words of the rule, interval
/// and mapping dialogs, so a conflict reads the way the diver set it.
/// Scope and mapping columns hold JSON id lists and show as changed.
final Map<String, ConflictField> certificationCurrencyFields = {
  'advisoryKey': ConflictField(
    (l) => l.settings_conflict_field_advisoryKey,
    FieldKind.opaque,
  ),
  'advisoryText': ConflictField(
    (l) => l.currencyRules_dialog_note,
    FieldKind.longText,
  ),
  'applicableAgencies': ConflictField(
    (l) => l.currencyRules_dialog_agencies,
    FieldKind.opaque,
  ),
  'applicableLevels': ConflictField(
    (l) => l.currencyRules_dialog_levels,
    FieldKind.opaque,
  ),
  'clockKind': ConflictField(
    (l) => l.currencyRules_dialog_clock,
    FieldKind.enumValue,
    enumLabel: currencyClockKindLabeler,
  ),
  'countedDiveModes': ConflictField(
    (l) => l.certifications_currency_mappingDialog_modes,
    FieldKind.opaque,
  ),
  'countedDiveTypeIds': ConflictField(
    (l) => l.certifications_currency_mappingDialog_types,
    FieldKind.opaque,
  ),
  'eventDate': ConflictField(
    (l) => l.certifications_currency_eventDialog_date,
    FieldKind.date,
  ),
  'lapseDays': ConflictField(
    (l) => l.certifications_currency_intervalDialog_lapse,
    FieldKind.number,
  ),
  'lapseDaysOverride': ConflictField(
    (l) => l.certifications_currency_intervalDialog_lapse,
    FieldKind.number,
  ),
  'leadDays': ConflictField(
    (l) => l.certifications_currency_intervalDialog_lead,
    FieldKind.number,
  ),
  'leadDaysOverride': ConflictField(
    (l) => l.certifications_currency_intervalDialog_lead,
    FieldKind.number,
  ),
  'muted': ConflictField(
    (l) => l.certifications_currency_muted,
    FieldKind.boolean,
  ),
  'supersedesRuleId': ConflictField(
    (l) => l.settings_conflict_field_supersedesRuleId,
    FieldKind.opaque,
  ),
};

/// A history entry's type and provider mean something else on other
/// records (a profile event's type, a service provider).
final Map<String, ConflictField> certificationCurrencyOverrides = {
  'certificationCurrencyEvents.eventType': ConflictField(
    (l) => l.certifications_currency_eventDialog_type,
    FieldKind.enumValue,
    enumLabel: currencyEventTypeLabeler,
  ),
  'certificationCurrencyEvents.provider': ConflictField(
    (l) => l.certifications_currency_eventDialog_provider,
    FieldKind.shortText,
  ),
};

final ConflictEnumLabeler currencyClockKindLabeler = enumLabeler(
  CurrencyClockKind.values,
  (l, v) => switch (v) {
    CurrencyClockKind.activity => l.currencyRules_dialog_clock_activity,
    CurrencyClockKind.date => l.currencyRules_dialog_clock_date,
  },
);

final ConflictEnumLabeler currencyEventTypeLabeler = enumLabeler(
  CurrencyEventType.values,
  (l, v) => v.label(l),
);
