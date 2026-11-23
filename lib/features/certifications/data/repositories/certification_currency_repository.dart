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
            clockKind: Value(rule.clockKind.name),
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
        String? Function(CurrencyRuleRow row) column,
        String next,
        List<String> Function(String raw) names,
      ) => CurrencyScopeCodec.keepIfUnchanged(
        stored: stored == null ? null : column(stored),
        next: next,
        names: names,
      );
      // A date clock never reads the mapping, so the empty mapping the dialog
      // saves for it cannot widen anything. Writing it as given lets a rule
      // whose mapping this build cannot read be repaired by dating it.
      final dated = rule.clockKind == CurrencyClockKind.date;
      await (_db.update(
        _db.certificationCurrencyRules,
      )..where((t) => t.id.equals(rule.id) & t.isBuiltIn.equals(false))).write(
        CertificationCurrencyRulesCompanion(
          diverId: Value(rule.diverId),
          name: Value(rule.name),
          clockKind: Value(rule.clockKind.name),
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
          countedDiveTypeIds: Value(
            dated
                ? rule.diveTypesJson
                : scope(
                    (r) => r.countedDiveTypeIds,
                    rule.diveTypesJson,
                    CurrencyScopeCodec.decodeStrings,
                  ),
          ),
          countedDiveModes: Value(
            dated
                ? rule.diveModesJson
                : scope(
                    (r) => r.countedDiveModes,
                    rule.diveModesJson,
                    CurrencyScopeCodec.modeNames,
                  ),
          ),
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
  Future<CurrencyPref> upsertPref(CurrencyPref pref) async {
    final id = pref.id.isEmpty ? _uuid.v4() : pref.id;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    // One transaction, so a sync apply between the read and the write
    // cannot be overwritten with the mapping read before it.
    final createdAtMs = await _db.transaction(() async {
      final existing = await (_db.select(
        _db.certificationCurrencyPrefs,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final createdAtMs = existing?.createdAt ?? nowMs;
      final nextTypes = pref.countedDiveTypeIds == null
          ? null
          : CurrencyScopeCodec.encode(pref.countedDiveTypeIds!);
      final nextModes = pref.countedDiveModes == null
          ? null
          : CurrencyScopeCodec.encode([
              for (final m in pref.countedDiveModes!) m.name,
            ]);
      // Types and modes are one answer to "which dives count". A save that
      // leaves both alone writes them back as stored, readable or not, so a
      // mute toggle cannot turn an unreadable mapping into "any dive"; a save
      // that changes either writes both as given (issue #4942).
      final keepMapping =
          existing != null &&
          CurrencyScopeCodec.sameValues(
            existing.countedDiveTypeIds,
            nextTypes,
            CurrencyScopeCodec.decodeStrings,
          ) &&
          CurrencyScopeCodec.sameValues(
            existing.countedDiveModes,
            nextModes,
            CurrencyScopeCodec.modeNames,
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
              countedDiveTypeIds: Value(
                keepMapping ? existing.countedDiveTypeIds : nextTypes,
              ),
              countedDiveModes: Value(
                keepMapping ? existing.countedDiveModes : nextModes,
              ),
              muted: Value(pref.muted),
              createdAt: Value(createdAtMs),
              updatedAt: Value(nowMs),
            ),
          );
      return createdAtMs;
    });
    await _syncRepository.markRecordPending(
      entityType: prefsEntity,
      recordId: id,
      localUpdatedAt: nowMs,
    );
    SyncEventBus.notifyLocalChange();
    return CurrencyPref(
      id: id,
      certificationId: pref.certificationId,
      ruleId: pref.ruleId,
      lapseDaysOverride: pref.lapseDaysOverride,
      leadDaysOverride: pref.leadDaysOverride,
      countedDiveTypeIds: pref.countedDiveTypeIds,
      countedDiveModes: pref.countedDiveModes,
      muted: pref.muted,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
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
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  CurrencyPref _mapPref(CurrencyPrefRow row) => CurrencyPref(
    id: row.id,
    certificationId: row.certificationId,
    ruleId: row.ruleId,
    lapseDaysOverride: row.lapseDaysOverride,
    leadDaysOverride: row.leadDaysOverride,
    countedDiveTypeIds: row.countedDiveTypeIds == null
        ? null
        : CurrencyScopeCodec.decodeStrings(row.countedDiveTypeIds!),
    countedDiveModes: row.countedDiveModes == null
        ? null
        : CurrencyScopeCodec.decodeModes(row.countedDiveModes!),
    unreadableMapping:
        (row.countedDiveTypeIds != null &&
            !CurrencyScopeCodec.isReadableStrings(row.countedDiveTypeIds!)) ||
        (row.countedDiveModes != null &&
            !CurrencyScopeCodec.isReadableModes(row.countedDiveModes!)),
    muted: row.muted,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
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
