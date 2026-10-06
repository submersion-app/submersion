import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// Restores certification currency rows from a parsed UDDF full backup
/// (issue #2267).
///
/// Custom rules restore with no selection step, as custom dive roles do: a
/// rule keeps its id unless a row with that id is already here. A custom
/// rule the importing diver already owns (or nobody owns) is reused. A
/// built-in, or another diver's rule, under the same id is left alone and
/// the file's rule lands as a copy under a new id, with the prefs and events
/// that name it following: a file's rules are always custom, so a collision
/// with a seeded id must not discard the file's definition.
///
/// Prefs and events ride along with the certifications the import created,
/// as service records ride along with equipment: a row whose
/// `certificationRef` the import did not create a certification for (not
/// selected, or matched to an existing card) is skipped, so a re-import
/// never copies a card's history onto it twice. Each restored pref and event
/// takes a new id for the same reason.
class CurrencyRestorer {
  CurrencyRestorer(this._repository);

  final CertificationCurrencyRepository _repository;
  final _uuid = const Uuid();
  static final _log = LoggerService.forClass(CurrencyRestorer);

  /// Restores [rules], then the [prefs] and [events] whose
  /// `certificationRef` is a key of [certIdMapping]. Returns how many rows
  /// were written. One bad row is logged and skipped; it never aborts the
  /// import.
  Future<int> restore({
    required List<Map<String, dynamic>> rules,
    required List<Map<String, dynamic>> prefs,
    required List<Map<String, dynamic>> events,
    required String diverId,
    required Map<String, String> certIdMapping,
  }) async {
    if (rules.isEmpty && prefs.isEmpty && events.isEmpty) return 0;
    var count = 0;
    final ruleIdMapping = <String, String>{};

    final Map<String, CurrencyRule> here;
    try {
      here = {for (final r in await _repository.getRules()) r.id: r};
    } catch (e, stackTrace) {
      _log.error(
        'Failed to list currency rules; currency not restored',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }

    for (final data in rules) {
      final id = data['id'] as String?;
      if (id == null) continue;
      final existing = here[id];
      if (existing != null &&
          !existing.isBuiltIn &&
          (existing.diverId == null || existing.diverId == diverId)) {
        ruleIdMapping[id] = id;
        continue;
      }
      final newId = existing == null ? id : _uuid.v4();
      try {
        await _repository.createRule(_rule(data, newId, diverId));
        ruleIdMapping[id] = newId;
        count++;
      } catch (e, stackTrace) {
        _log.error(
          'Failed to restore currency rule: $id',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    final now = DateTime.now();
    for (final data in prefs) {
      final certId = certIdMapping[data['certificationRef']];
      final ruleId = data['ruleId'] as String?;
      if (certId == null || ruleId == null) continue;
      try {
        await _repository.upsertPref(
          CurrencyPref(
            id: _uuid.v4(),
            certificationId: certId,
            ruleId: ruleIdMapping[ruleId] ?? ruleId,
            lapseDaysOverride: data['lapseDaysOverride'] as int?,
            leadDaysOverride: data['leadDaysOverride'] as int?,
            countedDiveTypeIds: switch (data['countedDiveTypeIds']) {
              final String raw => CurrencyScopeCodec.decodeStrings(raw),
              _ => null,
            },
            countedDiveModes: switch (data['countedDiveModes']) {
              final String raw => CurrencyScopeCodec.decodeModes(raw),
              _ => null,
            },
            muted: data['muted'] as bool? ?? false,
            createdAt: now,
            updatedAt: now,
          ),
        );
        count++;
      } catch (e, stackTrace) {
        _log.error(
          'Failed to restore currency pref: ${data['id']}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    for (final data in events) {
      final certId = certIdMapping[data['certificationRef']];
      final date = data['eventDate'];
      if (certId == null || date is! DateTime) continue;
      final ruleId = data['ruleId'] as String?;
      try {
        await _repository.createEvent(
          CurrencyEvent(
            id: _uuid.v4(),
            certificationId: certId,
            ruleId: ruleId == null ? null : ruleIdMapping[ruleId] ?? ruleId,
            eventType: CurrencyEventType.parse(data['eventType'] as String),
            eventDate: date,
            provider: data['provider'] as String?,
            notes: data['notes'] as String? ?? '',
            createdAt: now,
            updatedAt: now,
          ),
        );
        count++;
      } catch (e, stackTrace) {
        _log.error(
          'Failed to restore currency event: ${data['id']}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    return count;
  }

  CurrencyRule _rule(Map<String, dynamic> data, String id, String diverId) {
    final now = DateTime.now();
    return CurrencyRule(
      id: id,
      diverId: diverId,
      name: data['name'] as String,
      clockKind: CurrencyClockKind.parse(data['clockKind'] as String),
      agencies: CurrencyScopeCodec.decodeAgencies(
        data['applicableAgencies'] as String,
      ),
      levels: CurrencyScopeCodec.decodeLevels(
        data['applicableLevels'] as String,
      ),
      lapseDays: data['lapseDays'] as int,
      leadDays: data['leadDays'] as int,
      countedDiveTypeIds: CurrencyScopeCodec.decodeStrings(
        data['countedDiveTypeIds'] as String,
      ),
      countedDiveModes: CurrencyScopeCodec.decodeModes(
        data['countedDiveModes'] as String,
      ),
      advisoryText: data['advisoryText'] as String?,
      supersedesRuleId: data['supersedesRuleId'] as String?,
      createdAt: now,
      updatedAt: now,
    );
  }
}
