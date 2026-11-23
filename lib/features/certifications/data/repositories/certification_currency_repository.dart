import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// CRUD for certification currency (issue #2267): the rule catalog, the per
/// certification prefs and the event ledger.
///
/// Built-in rules are reference data. They are never created, edited or
/// deleted here: built-in rows are excluded from sync export, so a write to
/// one would be device-local and silent. The UI copies a built-in into a
/// custom rule that supersedes it instead.
class CertificationCurrencyRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const rulesEntity = 'certificationCurrencyRules';
  static const prefsEntity = 'certificationCurrencyPrefs';
  static const eventsEntity = 'certificationCurrencyEvents';

  /// Emits whenever any of the three currency tables changes, including a
  /// write that arrives through sync and bypasses this repository.
  Stream<void> watchCurrencyChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.certificationCurrencyRules),
      TableUpdateQuery.onTable(_db.certificationCurrencyPrefs),
      TableUpdateQuery.onTable(_db.certificationCurrencyEvents),
    ]),
  );

  // ---------------------------------------------------------------- rules

  /// Every rule: the built-ins plus every diver's custom rules. Scoping to
  /// the active diver is the caller's job, as it is for service kinds.
  Future<List<CurrencyRule>> getRules() async {
    final rows = await _db.select(_db.certificationCurrencyRules).get();
    return rows.map(_mapRule).toList();
  }

  /// The built-ins plus [diverId]'s custom rules, and unowned custom rules.
  Future<List<CurrencyRule>> getRulesForDiver(String? diverId) async {
    final rules = await getRules();
    return [
      for (final r in rules)
        if (r.isBuiltIn || r.diverId == null || r.diverId == diverId) r,
    ];
  }

  /// Creates a custom rule. The row is always written as custom, whatever
  /// [rule] says, so no code path can mint a built-in that never syncs.
  Future<CurrencyRule> createRule(CurrencyRule rule) async {
    final id = rule.id.isEmpty ? _uuid.v4() : rule.id;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    await _db
        .into(_db.certificationCurrencyRules)
        .insert(
          CertificationCurrencyRulesCompanion(
            id: Value(id),
            diverId: Value(rule.diverId),
            name: Value(rule.name),
            clockKind: Value(rule.clockKindJson),
            applicableAgencies: Value(rule.agenciesJson),
            applicableLevels: Value(rule.levelsJson),
            lapseDays: Value(rule.lapseDays),
            leadDays: Value(rule.leadDays),
            countedDiveTypeIds: Value(rule.diveTypesJson),
            countedDiveModes: Value(rule.diveModesJson),
            advisoryKey: const Value(null),
            advisoryText: Value(rule.advisoryText),
            supersedesRuleId: Value(rule.supersedesRuleId),
            isBuiltIn: const Value(false),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: rulesEntity,
      recordId: id,
      localUpdatedAt: nowMs,
    );
    SyncEventBus.notifyLocalChange();
    return rule.copyWith(
      id: id,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateRule(CurrencyRule rule) async {
    if (rule.isBuiltIn) {
      throw StateError('Built-in currency rules cannot be edited');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // One transaction, so a sync apply between the read and the write
    // cannot be overwritten with the scope read before it.
    await _db.transaction(() async {
      final stored = await (_db.select(
        _db.certificationCurrencyRules,
      )..where((t) => t.id.equals(rule.id))).getSingleOrNull();
      // A scope the edit leaves alone is written back as stored, readable or
      // not (issue #4942).
      String scope(
        String Function(CurrencyRuleRow row) column,
        String next,
        List<String> Function(String raw) names,
      ) => CurrencyScopeCodec.keepIfUnchanged(
        stored: stored == null ? null : column(stored),
        next: next,
        names: names,
      );
      // The dive types and modes are one mapping, kept as stored only when
      // neither half changed. A change of clock is a change to it too: the
      // dialog shows and saves the mapping for the new clock (empty for a
      // date clock, which never reads it), so it is written as given. That
      // lets a rule whose mapping this build cannot read be repaired by
      // changing its clock either way. A rule that keeps its clock keeps its
      // stored mapping like any other unchanged column.
      final clockChanged =
          stored != null &&
          CurrencyClockKind.parse(stored.clockKind) != rule.clockKind;
      // "As given" is the lists themselves: the JSON getters would hand back
      // a rule's own stored arrays while the lists decode the same.
      final mapping = clockChanged
          ? rule.encodedMapping
          : CurrencyScopeCodec.keepMappingIfUnchanged(
              stored: stored == null
                  ? null
                  : (
                      types: stored.countedDiveTypeIds,
                      modes: stored.countedDiveModes,
                    ),
              next: (types: rule.diveTypesJson, modes: rule.diveModesJson),
            );
      // A clock kind this build does not know reads as activity; an edit
      // that leaves the clock alone writes the stored kind back.
      final clockKind =
          stored != null &&
              CurrencyClockKind.parse(stored.clockKind) == rule.clockKind
          ? stored.clockKind
          : rule.clockKind.name;
      await (_db.update(
        _db.certificationCurrencyRules,
      )..where((t) => t.id.equals(rule.id) & t.isBuiltIn.equals(false))).write(
        CertificationCurrencyRulesCompanion(
          diverId: Value(rule.diverId),
          name: Value(rule.name),
          clockKind: Value(clockKind),
          applicableAgencies: Value(
            scope(
              (r) => r.applicableAgencies,
              rule.agenciesJson,
              CurrencyScopeCodec.agencyNames,
            ),
          ),
          applicableLevels: Value(
            scope(
              (r) => r.applicableLevels,
              rule.levelsJson,
              CurrencyScopeCodec.levelNames,
            ),
          ),
          lapseDays: Value(rule.lapseDays),
          leadDays: Value(rule.leadDays),
          countedDiveTypeIds: Value(mapping.types!),
          countedDiveModes: Value(mapping.modes!),
          advisoryText: Value(rule.advisoryText),
          supersedesRuleId: Value(rule.supersedesRuleId),
          updatedAt: Value(nowMs),
        ),
      );
    });
    await _syncRepository.markRecordPending(
      entityType: rulesEntity,
      recordId: rule.id,
      localUpdatedAt: nowMs,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a custom rule. Prefs and events that name it are left alone:
  /// they carry the rule id as plain text, and the record of a refresher the
  /// diver actually did outlives the rule that prompted it.
  Future<void> deleteRule(String id) async {
    final row = await (_db.select(
      _db.certificationCurrencyRules,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.isBuiltIn) {
      throw StateError('Built-in currency rules cannot be deleted');
    }
    await (_db.delete(
      _db.certificationCurrencyRules,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: rulesEntity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  // ---------------------------------------------------------------- prefs

  Future<List<CurrencyPref>> getPrefs(String certificationId) async {
    final rows = await (_db.select(
      _db.certificationCurrencyPrefs,
    )..where((t) => t.certificationId.equals(certificationId))).get();
    return rows.map(_mapPref).toList();
  }

  Future<List<CurrencyPref>> getAllPrefs() async {
    final rows = await _db.select(_db.certificationCurrencyPrefs).get();
    return rows.map(_mapPref).toList();
  }

  /// Writes [pref] by full value, inserting or replacing the row with its
  /// id. A null field is written as null, which is how a pref goes back to
  /// inheriting the rule.
  ///
  /// The dive-type and dive-mode mapping is one answer to "which dives
  /// count". A save that leaves both halves' values alone writes them back
  /// as stored, readable or not, so a mute toggle cannot turn a mapping this
  /// build cannot read into "any dive"; a save that changes either writes
  /// both as given (issue #4942). Pass [mappingEdited] when the diver set
  /// the mapping: over a stored mapping this build cannot read, what they
  /// chose is written even when it decodes to the same values.
  Future<CurrencyPref> upsertPref(
    CurrencyPref pref, {
    bool mappingEdited = false,
  }) async {
    final id = pref.id.isEmpty ? _uuid.v4() : pref.id;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    // One transaction, so a sync apply between the read and the write
    // cannot be overwritten with the mapping read before it.
    final written = await _db.transaction(() async {
      final existing = await (_db.select(
        _db.certificationCurrencyPrefs,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final createdAtMs = existing?.createdAt ?? nowMs;
      final stored = existing == null
          ? null
          : (
              types: existing.countedDiveTypeIds,
              modes: existing.countedDiveModes,
            );
      // What the diver set is the lists themselves: the pref's mappingJson
      // would hand back its own stored arrays while the lists decode the
      // same.
      final mapping =
          mappingEdited &&
              stored != null &&
              !CurrencyScopeCodec.isReadableMapping(stored)
          ? pref.encodedMapping
          : CurrencyScopeCodec.keepMappingIfUnchanged(
              stored: stored,
              next: pref.mappingJson,
            );
      await _db
          .into(_db.certificationCurrencyPrefs)
          .insertOnConflictUpdate(
            CertificationCurrencyPrefsCompanion(
              id: Value(id),
              certificationId: Value(pref.certificationId),
              ruleId: Value(pref.ruleId),
              lapseDaysOverride: Value(pref.lapseDaysOverride),
              leadDaysOverride: Value(pref.leadDaysOverride),
              countedDiveTypeIds: Value(mapping.types),
              countedDiveModes: Value(mapping.modes),
              muted: Value(pref.muted),
              createdAt: Value(createdAtMs),
              updatedAt: Value(nowMs),
            ),
          );
      return (createdAtMs: createdAtMs, mapping: mapping);
    });
    await _syncRepository.markRecordPending(
      entityType: prefsEntity,
      recordId: id,
      localUpdatedAt: nowMs,
    );
    SyncEventBus.notifyLocalChange();
    // The pref as written, so a caller reading it sees a kept mapping this
    // build cannot read as such, not as the "any dive" it decodes to.
    return _prefOf(
      id: id,
      certificationId: pref.certificationId,
      ruleId: pref.ruleId,
      lapseDaysOverride: pref.lapseDaysOverride,
      leadDaysOverride: pref.leadDaysOverride,
      mapping: written.mapping,
      muted: pref.muted,
      createdAt: DateTime.fromMillisecondsSinceEpoch(written.createdAtMs),
      updatedAt: now,
    );
  }

  Future<void> deletePref(String id) async {
    await (_db.delete(
      _db.certificationCurrencyPrefs,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: prefsEntity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  // --------------------------------------------------------------- events

  /// [certificationId]'s ledger, newest event first.
  Future<List<CurrencyEvent>> getEvents(String certificationId) async {
    final rows =
        await (_db.select(_db.certificationCurrencyEvents)
              ..where((t) => t.certificationId.equals(certificationId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.eventDate),
                (t) => OrderingTerm.desc(t.createdAt),
              ]))
            .get();
    return rows.map(_mapEvent).toList();
  }

  Future<List<CurrencyEvent>> getAllEvents() async {
    final rows = await _db.select(_db.certificationCurrencyEvents).get();
    return rows.map(_mapEvent).toList();
  }

  Future<CurrencyEvent> createEvent(CurrencyEvent event) async {
    final id = event.id.isEmpty ? _uuid.v4() : event.id;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    await _db
        .into(_db.certificationCurrencyEvents)
        .insert(
          CertificationCurrencyEventsCompanion(
            id: Value(id),
            certificationId: Value(event.certificationId),
            ruleId: Value(event.ruleId),
            eventType: Value(event.eventType.name),
            eventDate: Value(event.eventDate.millisecondsSinceEpoch),
            provider: Value(event.provider),
            notes: Value(event.notes),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: eventsEntity,
      recordId: id,
      localUpdatedAt: nowMs,
    );
    SyncEventBus.notifyLocalChange();
    return event.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  Future<void> deleteEvent(String id) async {
    await (_db.delete(
      _db.certificationCurrencyEvents,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: eventsEntity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  /// Tombstones every pref and event of [certificationId]. Called before the
  /// certification row is deleted: SQLite's cascade writes no deletion-log
  /// rows, so without these a peer would push the orphans straight back.
  Future<void> tombstoneChildrenOf(String certificationId) async {
    final prefs = await (_db.select(
      _db.certificationCurrencyPrefs,
    )..where((t) => t.certificationId.equals(certificationId))).get();
    final events = await (_db.select(
      _db.certificationCurrencyEvents,
    )..where((t) => t.certificationId.equals(certificationId))).get();
    for (final p in prefs) {
      await _syncRepository.logDeletion(
        entityType: prefsEntity,
        recordId: p.id,
      );
    }
    for (final e in events) {
      await _syncRepository.logDeletion(
        entityType: eventsEntity,
        recordId: e.id,
      );
    }
  }

  // -------------------------------------------------------------- mapping

  CurrencyRule _mapRule(CurrencyRuleRow row) => CurrencyRule(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    clockKind: CurrencyClockKind.parse(row.clockKind),
    agencies: CurrencyScopeCodec.decodeAgencies(row.applicableAgencies),
    levels: CurrencyScopeCodec.decodeLevels(row.applicableLevels),
    lapseDays: row.lapseDays,
    leadDays: row.leadDays,
    countedDiveTypeIds: CurrencyScopeCodec.decodeStrings(
      row.countedDiveTypeIds,
    ),
    countedDiveModes: CurrencyScopeCodec.decodeModes(row.countedDiveModes),
    advisoryKey: row.advisoryKey,
    advisoryText: row.advisoryText,
    supersedesRuleId: row.supersedesRuleId,
    isBuiltIn: row.isBuiltIn,
    unreadableScope:
        !CurrencyScopeCodec.isReadableAgencies(row.applicableAgencies) ||
        !CurrencyScopeCodec.isReadableLevels(row.applicableLevels) ||
        !CurrencyScopeCodec.isReadableStrings(row.countedDiveTypeIds) ||
        !CurrencyScopeCodec.isReadableModes(row.countedDiveModes),
    storedClockKind: row.clockKind,
    storedScope: (
      agencies: row.applicableAgencies,
      levels: row.applicableLevels,
      types: row.countedDiveTypeIds,
      modes: row.countedDiveModes,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  CurrencyPref _mapPref(CurrencyPrefRow row) => _prefOf(
    id: row.id,
    certificationId: row.certificationId,
    ruleId: row.ruleId,
    lapseDaysOverride: row.lapseDaysOverride,
    leadDaysOverride: row.leadDaysOverride,
    mapping: (types: row.countedDiveTypeIds, modes: row.countedDiveModes),
    muted: row.muted,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  /// A pref holding [mapping] as stored: decoded, flagged when this build
  /// cannot read it, and carried raw so a save or backup keeps it.
  static CurrencyPref _prefOf({
    required String id,
    required String certificationId,
    required String ruleId,
    required int? lapseDaysOverride,
    required int? leadDaysOverride,
    required CurrencyMappingJson mapping,
    required bool muted,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => CurrencyPref(
    id: id,
    certificationId: certificationId,
    ruleId: ruleId,
    lapseDaysOverride: lapseDaysOverride,
    leadDaysOverride: leadDaysOverride,
    countedDiveTypeIds: mapping.types == null
        ? null
        : CurrencyScopeCodec.decodeStrings(mapping.types!),
    countedDiveModes: mapping.modes == null
        ? null
        : CurrencyScopeCodec.decodeModes(mapping.modes!),
    unreadableMapping: !CurrencyScopeCodec.isReadableMapping(mapping),
    storedMapping: mapping,
    muted: muted,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  CurrencyEvent _mapEvent(CurrencyEventRow row) => CurrencyEvent(
    id: row.id,
    certificationId: row.certificationId,
    ruleId: row.ruleId,
    eventType: CurrencyEventType.parse(row.eventType),
    eventDate: DateTime.fromMillisecondsSinceEpoch(row.eventDate),
    provider: row.provider,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
