import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding_subjects.dart';

/// Resolves the sources and tanks findings name into what a diver knows them
/// by (issue #4209).
///
/// Each read binds its id list as one JSON array and expands it with
/// `json_each`, so a library with hundreds of findings stays one statement
/// with one variable. Both reads watch their tables: a renamed computer, a
/// set-primary or a tank reassigned from the inbox relabel the open cards.
class QualityFindingSubjectQuery {
  QualityFindingSubjectQuery([AppDatabase? db]) : _dbOverride = db;

  final AppDatabase? _dbOverride;
  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Source id to label: the saved computer's name, else its manufacturer
  /// and model, else the model the recording carries. A source with none of
  /// them is left out, and the caller keeps its unnamed copy.
  Stream<Map<String, String>> watchSourceLabels(List<String> sourceIds) {
    if (sourceIds.isEmpty) return Stream.value(const {});
    return _db
        .customSelect(
          'SELECT s.id AS id, s.computer_model AS recorded_model, '
          'c.name AS name, c.manufacturer AS manufacturer, c.model AS model '
          'FROM dive_data_sources s '
          'LEFT JOIN dive_computers c ON c.id = s.computer_id '
          'WHERE s.id IN (SELECT value FROM json_each(?1))',
          variables: [Variable.withString(jsonEncode(sourceIds))],
          readsFrom: {_db.diveDataSources, _db.diveComputers},
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows)
              r.read<String>('id'): ?_sourceLabel(
                name: r.read<String?>('name'),
                manufacturer: r.read<String?>('manufacturer'),
                model: r.read<String?>('model'),
                recordedModel: r.read<String?>('recorded_model'),
              ),
          },
        );
  }

  /// Tank id to its position among its dive's tanks and its name. The
  /// position counts the dive's tanks ordered by tank order, so it matches
  /// the "Tank n" the dive's own screens give the n-th tank of that list.
  /// They sort by tank order alone, which leaves equal orders in table
  /// order, so ties break by rowid here, not by id.
  Stream<Map<String, QualityTankRef>> watchTanks(List<String> tankIds) {
    if (tankIds.isEmpty) return Stream.value(const {});
    return _db
        .customSelect(
          'SELECT t.id AS id, t.tank_name AS name, '
          '(SELECT COUNT(*) FROM dive_tanks o WHERE o.dive_id = t.dive_id '
          'AND (o.tank_order < t.tank_order '
          'OR (o.tank_order = t.tank_order AND o.rowid < t.rowid))) + 1 '
          'AS number '
          'FROM dive_tanks t '
          'WHERE t.id IN (SELECT value FROM json_each(?1))',
          variables: [Variable.withString(jsonEncode(tankIds))],
          readsFrom: {_db.diveTanks},
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows)
              r.read<String>('id'): QualityTankRef(
                number: r.read<int>('number'),
                name: _nonBlank(r.read<String?>('name')),
              ),
          },
        );
  }
}

/// The saved computer's name as `DiveComputer.displayName` gives it (its
/// name, else "manufacturer model", else either alone), so a source reads
/// the same as the computer-name lookup it stands in for. Without a saved
/// computer, the model the recording carries.
String? _sourceLabel({
  required String? name,
  required String? manufacturer,
  required String? model,
  required String? recordedModel,
}) {
  final saved = _nonBlank(name);
  if (saved != null) return saved;
  final maker = _nonBlank(manufacturer);
  final savedModel = _nonBlank(model);
  if (maker != null && savedModel != null) return '$maker $savedModel';
  return savedModel ?? maker ?? _nonBlank(recordedModel);
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
