import 'dart:convert';

import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/core/constants/enums.dart' show DiveMode;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart'
    show kCardExpiryRuleId;

/// The names an enum set's parsed value holds, in [values] order.
List<T> _enumsOf<T extends Enum>(Object? parsed, List<T> values) {
  final names = parsed is String ? parsed.split(',').toSet() : <String>{};
  return [
    for (final v in values)
      if (names.contains(v.name)) v,
  ];
}

List<String> _textsOf(Object? parsed) =>
    parsed is String ? [for (final t in jsonDecode(parsed) as List) '$t'] : [];

/// The certification currency catalog, through the repository the currency
/// rule dialog uses. A built-in rule is reference data: editing one creates
/// the custom copy that supersedes it, for the profile in use, as the dialog
/// does, and a built-in is never deleted.
class CurrencyRuleWrites extends WritableEntry {
  CurrencyRuleWrites(this._r);

  final RecordRepositories _r;

  static const _table = 'certification_currency_rules';

  @override
  String get name => 'currency_rules';

  @override
  String get table => _table;

  @override
  String get note =>
      'lead_days is how long before the lapse the clock warns, 0 to '
      'lapse_days. counted_dive_type_ids and counted_dive_modes narrow an '
      'activity clock only. An update of a built-in rule creates its custom '
      'copy, which supersedes it.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'clock_kind': FieldCodec.enumName(CurrencyClockKind.values),
    'agencies': FieldCodec.enumSet(CertificationAgency.values),
    'levels': FieldCodec.enumSet(CertificationLevel.values),
    'lapse_days': const FieldCodec.integer(min: 1, max: 36500),
    'lead_days': const FieldCodec.integer(min: 0, max: 36500),
    'counted_dive_type_ids': const FieldCodec.textList(maxItems: 50),
    'counted_dive_modes': FieldCodec.enumSet(DiveMode.values),
    'advisory_text': const FieldCodec.text(nullable: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'lapse_days', 'lead_days'};

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {'clock_kind': CurrencyClockKind.activity.name};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final builtIn = check.document?['is_built_in'] == true;
    if (check.kind == ChangeKind.delete) {
      return builtIn
          ? const PlanBlock(
              BlockReason.notPermitted,
              'A built-in currency rule is never deleted.',
            )
          : null;
    }
    if (builtIn) {
      final profile = await _profile();
      final copy = (await _r.currency.getRules())
          .where((r) => r.supersedesRuleId == check.id && !r.isBuiltIn)
          .where((r) => r.diverId == profile)
          .firstOrNull;
      if (copy != null) {
        return PlanBlock(
          BlockReason.duplicateRecord,
          'This built-in rule has a custom copy, ${copy.id}; edit that.',
        );
      }
    }
    final rule = _rule(check.document, check.values);
    if (rule.leadDays > rule.lapseDays) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'lead_days: from 0 to lapse_days.',
      );
    }
    if (rule.clockKind == CurrencyClockKind.date &&
        (rule.countedDiveTypeIds.isNotEmpty ||
            rule.countedDiveModes.isNotEmpty)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'counted_dive_type_ids and counted_dive_modes narrow an activity '
        'clock only.',
      );
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => document['is_built_in'] == true
      ? const SideEffects(created: {_table: 1})
      : const SideEffects();

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final rule = _rule(null, values);
    return (await _r.currency.createRule(
      _with(rule, id: '', diverId: diverId),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = (await _r.currency.getRules())
        .where((r) => r.id == id)
        .firstOrNull;
    if (current == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Currency rule $id no longer exists.',
        details: {'id': id},
      );
    }
    final edited = _applied(current, update.values);
    if (current.isBuiltIn) {
      await _r.currency.createRule(
        _with(edited, id: '', diverId: await _profile(), supersedes: id),
      );
    } else {
      await _r.currency.updateRule(edited);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.currency.deleteRule(id);

  /// The profile in use, which owns a built-in rule's copy: the active one,
  /// or the default.
  Future<String?> _profile() async =>
      await _r.divers.getActiveDiverIdFromSettings() ??
      (await _r.divers.getDefaultDiver())?.id;

  /// The rule [document] holds with [values] written over it, as the
  /// dialog would save it.
  static CurrencyRule _rule(
    Map<String, Object?>? document,
    Map<String, Object?> values,
  ) {
    final now = DateTime.now();
    final base = CurrencyRule(
      id: document?['id'] as String? ?? '',
      diverId: document?['diver_id'] as String?,
      name: document?['name'] as String? ?? '',
      clockKind: CurrencyClockKind.parse(
        document?['clock_kind'] as String? ?? 'activity',
      ),
      agencies: _enumsOf(
        (document?['agencies'] as List?)?.join(','),
        CertificationAgency.values,
      ),
      levels: _enumsOf(
        (document?['levels'] as List?)?.join(','),
        CertificationLevel.values,
      ),
      lapseDays: document?['lapse_days'] as int? ?? 0,
      leadDays: document?['lead_days'] as int? ?? 0,
      countedDiveTypeIds: [
        for (final t in document?['counted_dive_type_ids'] as List? ?? []) '$t',
      ],
      countedDiveModes: _enumsOf(
        (document?['counted_dive_modes'] as List?)?.join(','),
        DiveMode.values,
      ),
      advisoryText: document?['advisory_text'] as String?,
      supersedesRuleId: document?['supersedes_rule_id'] as String?,
      isBuiltIn: document?['is_built_in'] == true,
      createdAt: now,
      updatedAt: now,
    );
    return _applied(base, values);
  }

  static CurrencyRule _applied(CurrencyRule rule, Map<String, Object?> v) {
    final clock = v.containsKey('clock_kind')
        ? CurrencyClockKind.parse(v['clock_kind']! as String)
        : rule.clockKind;
    return CurrencyRule(
      id: rule.id,
      diverId: rule.diverId,
      name: v['name'] as String? ?? rule.name,
      clockKind: clock,
      agencies: v.containsKey('agencies')
          ? _enumsOf(v['agencies'], CertificationAgency.values)
          : rule.agencies,
      levels: v.containsKey('levels')
          ? _enumsOf(v['levels'], CertificationLevel.values)
          : rule.levels,
      lapseDays: v['lapse_days'] as int? ?? rule.lapseDays,
      leadDays: v['lead_days'] as int? ?? rule.leadDays,
      countedDiveTypeIds: v.containsKey('counted_dive_type_ids')
          ? _textsOf(v['counted_dive_type_ids'])
          : rule.countedDiveTypeIds,
      countedDiveModes: v.containsKey('counted_dive_modes')
          ? _enumsOf(v['counted_dive_modes'], DiveMode.values)
          : rule.countedDiveModes,
      advisoryKey: rule.advisoryKey,
      advisoryText: v.containsKey('advisory_text')
          ? v['advisory_text'] as String?
          : rule.advisoryText,
      supersedesRuleId: rule.supersedesRuleId,
      isBuiltIn: rule.isBuiltIn,
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
    );
  }

  static CurrencyRule _with(
    CurrencyRule rule, {
    required String id,
    required String? diverId,
    String? supersedes,
  }) => CurrencyRule(
    id: id,
    diverId: diverId,
    name: rule.name,
    clockKind: rule.clockKind,
    agencies: rule.agencies,
    levels: rule.levels,
    lapseDays: rule.lapseDays,
    leadDays: rule.leadDays,
    countedDiveTypeIds: rule.countedDiveTypeIds,
    countedDiveModes: rule.countedDiveModes,
    advisoryText: rule.advisoryText,
    supersedesRuleId: supersedes ?? rule.supersedesRuleId,
    createdAt: rule.createdAt,
    updatedAt: rule.updatedAt,
  );
}

/// A card's own interval and scope for one currency rule, as the currency
/// section's dialogs keep it: one per card and rule, written whole, with a
/// null field inheriting the rule's.
class CurrencyPrefWrites extends WritableEntry {
  CurrencyPrefWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'currency_prefs';

  @override
  String get table => 'certification_currency_prefs';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'certifications', field: 'certification_id');

  @override
  String get note =>
      'rule_id is a currency rule or card_expiry, whose lapse is the printed '
      'date. A null override inherits the rule\'s value.';

  @override
  late final Map<String, FieldCodec> fields = {
    'certification_id': const FieldCodec.reference('certifications'),
    'rule_id': const FieldCodec.text(maxLength: 100),
    'lapse_days_override': const FieldCodec.integer(
      min: 1,
      max: 36500,
      nullable: true,
    ),
    'lead_days_override': const FieldCodec.integer(
      min: 0,
      max: 36500,
      nullable: true,
    ),
    'counted_dive_type_ids': const FieldCodec.textList(
      maxItems: 50,
      nullable: true,
    ),
    'counted_dive_modes': FieldCodec.enumSet(DiveMode.values, nullable: true),
    'muted': const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'rule_id'};

  @override
  Set<String> get createOnly => const {'rule_id'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['rule_id'] as String?;

  @override
  UniqueClaim? uniqueKey(WriteCheck check) => check.kind == ChangeKind.create
      ? UniqueClaim(
          'pref/${check.values['certification_id']}/${check.values['rule_id']}',
        )
      : null;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final pref = {...?check.document, ...check.values};
    final ruleId = pref['rule_id']! as String;
    final certificationId = pref['certification_id']! as String;
    if (check.kind == ChangeKind.create &&
        (await _r.currency.getPrefs(
          certificationId,
        )).any((p) => p.ruleId == ruleId)) {
      return const PlanBlock(
        BlockReason.duplicateRecord,
        'rule_id: this card has its settings for that rule; update them.',
      );
    }
    final lapse = pref['lapse_days_override'] as int?;
    final lead = pref['lead_days_override'] as int?;
    if (ruleId == kCardExpiryRuleId) {
      if (lapse != null ||
          pref['counted_dive_type_ids'] != null ||
          pref['counted_dive_modes'] != null) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'card_expiry lapses on the printed date; only its lead and muted '
          'are set.',
        );
      }
      return null;
    }
    final rule = (await _r.currency.getRulesForDiver(
      check.ownerId,
    )).where((r) => r.id == ruleId).firstOrNull;
    if (rule == null) {
      return PlanBlock(
        BlockReason.unknownReference,
        'rule_id: no currency rule $ruleId for this profile.',
      );
    }
    final effectiveLapse = lapse ?? rule.lapseDays;
    if ((lead ?? rule.leadDays) > effectiveLapse) {
      return PlanBlock(
        BlockReason.invalidValue,
        lead == null
            ? 'lapse_days_override: at least the rule\'s lead, '
                  '${rule.leadDays} days.'
            : 'lead_days_override: from 0 to the lapse, $effectiveLapse days.',
      );
    }
    return null;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    return (await _r.currency.upsertPref(
      _applied(
        CurrencyPref(
          id: '',
          certificationId: values['certification_id']! as String,
          ruleId: values['rule_id']! as String,
          createdAt: now,
          updatedAt: now,
        ),
        values,
      ),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = (await _r.currency.getAllPrefs())
        .where((p) => p.id == id)
        .firstOrNull;
    if (current == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Currency setting $id no longer exists.',
        details: {'id': id},
      );
    }
    await _r.currency.upsertPref(_applied(current, update.values));
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.currency.deletePref(id);

  static CurrencyPref _applied(CurrencyPref pref, Map<String, Object?> v) {
    T? kept<T>(String key, T? held) => v.containsKey(key) ? v[key] as T? : held;
    return CurrencyPref(
      id: pref.id,
      certificationId: pref.certificationId,
      ruleId: pref.ruleId,
      lapseDaysOverride: kept('lapse_days_override', pref.lapseDaysOverride),
      leadDaysOverride: kept('lead_days_override', pref.leadDaysOverride),
      countedDiveTypeIds: v.containsKey('counted_dive_type_ids')
          ? (v['counted_dive_type_ids'] == null
                ? null
                : _textsOf(v['counted_dive_type_ids']))
          : pref.countedDiveTypeIds,
      countedDiveModes: v.containsKey('counted_dive_modes')
          ? (v['counted_dive_modes'] == null
                ? null
                : _enumsOf(v['counted_dive_modes'], DiveMode.values))
          : pref.countedDiveModes,
      muted: v['muted'] as bool? ?? pref.muted,
      createdAt: pref.createdAt,
      updatedAt: pref.updatedAt,
    );
  }
}

/// A card's currency history, as the event dialog logs it: what the diver
/// did and on which day. An entry is logged or deleted, never edited.
class CurrencyEventWrites extends WritableEntry {
  CurrencyEventWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'currency_events';

  @override
  String get table => 'certification_currency_events';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'certifications', field: 'certification_id');

  @override
  String get note =>
      'event_type defaults to refresher, or renewal for a rule that counts '
      'from a date. An entry is not edited: delete it and log another.';

  @override
  late final Map<String, FieldCodec> fields = {
    'certification_id': const FieldCodec.reference('certifications'),
    'rule_id': const FieldCodec.text(maxLength: 100, nullable: true),
    'event_type': FieldCodec.enumName(CurrencyEventType.values),
    'event_date': const FieldCodec.calendarDate(),
    'provider': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'event_date'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['event_type'] as String?;

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final rule = (await _r.currency.getRules())
        .where((r) => r.id == values['rule_id'])
        .firstOrNull;
    return {
      'event_type': rule?.clockKind == CurrencyClockKind.date
          ? CurrencyEventType.renewal.name
          : CurrencyEventType.refresher.name,
    };
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    if (check.kind == ChangeKind.update) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A currency entry is not edited; delete it and log another.',
      );
    }
    if (check.values['rule_id'] case final String ruleId
        when !(await _r.currency.getRulesForDiver(
          check.ownerId,
        )).any((r) => r.id == ruleId)) {
      return PlanBlock(
        BlockReason.unknownReference,
        'rule_id: no currency rule $ruleId for this profile.',
      );
    }
    final day = calendarDay(check.values['event_date'])!;
    final now = DateTime.now();
    if (day.isBefore(DateTime(1950)) ||
        day.isAfter(DateTime(now.year, now.month, now.day))) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'event_date: a day from 1950-01-01 to today.',
      );
    }
    return null;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    return (await _r.currency.createEvent(
      CurrencyEvent(
        id: '',
        certificationId: values['certification_id']! as String,
        ruleId: values['rule_id'] as String?,
        eventType: CurrencyEventType.parse(values['event_type']! as String),
        eventDate: calendarDay(values['event_date'])!,
        provider: values['provider'] as String?,
        notes: values['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) =>
      throw UnsupportedError('A currency entry is not edited.');

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.currency.deleteEvent(id);
}
