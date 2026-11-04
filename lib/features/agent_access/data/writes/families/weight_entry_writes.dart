import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';

/// A diver's weight log, through the repository the weight sheet uses. An
/// entry is the day it was measured, kept as that day's local midnight as
/// the sheet's date picker keeps it, a weight and an optional height.
class WeightEntryWrites extends WritableEntry {
  WeightEntryWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'weight_entries';

  @override
  String get table => 'diver_weight_entries';

  @override
  String get note =>
      'measured_at is written as a day, YYYY-MM-DD, from 1950 to today; a '
      'read shows that day\'s start as an instant.';

  @override
  late final Map<String, FieldCodec> fields = {
    'measured_at': const FieldCodec.calendarDate(),
    'weight_kg': const FieldCodec.number(min: 0.1, max: 500),
    'height_cm': const FieldCodec.number(min: 30, max: 300, nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'measured_at', 'weight_kg'};

  /// The day a read's instant falls on here, the form a write takes.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => {
    ...document,
    'measured_at': switch (document['measured_at']) {
      final String at => calendarDate(DateTime.parse(at).toLocal()),
      _ => null,
    },
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final day = calendarDay(check.values['measured_at']);
    final now = DateTime.now();
    if (day == null ||
        (!day.isBefore(DateTime(1950)) &&
            !day.isAfter(DateTime(now.year, now.month, now.day)))) {
      return null;
    }
    return const PlanBlock(
      BlockReason.invalidValue,
      'measured_at: a day from 1950-01-01 to today.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final day = calendarDay(values['measured_at'])!;
    return (await _r.weightEntries.createEntry(
      DiverWeightEntry(
        id: '',
        diverId: diverId,
        measuredAt: day,
        weightKg: (values['weight_kg']! as num).toDouble(),
        heightCm: (values['height_cm'] as num?)?.toDouble(),
        createdAt: day,
        updatedAt: day,
      ),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _entry(id);
    final v = update.values;
    await _r.weightEntries.updateEntry(
      DiverWeightEntry(
        id: id,
        diverId: current.diverId,
        measuredAt: v.containsKey('measured_at')
            ? calendarDay(v['measured_at'])!
            : current.measuredAt,
        weightKg: (v['weight_kg'] as num?)?.toDouble() ?? current.weightKg,
        heightCm: v.containsKey('height_cm')
            ? (v['height_cm'] as num?)?.toDouble()
            : current.heightCm,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.weightEntries.deleteEntry(id);

  Future<DiverWeightEntry> _entry(String id) async {
    final rows = await _r.db
        .customSelect(
          'SELECT diver_id FROM diver_weight_entries WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    final entries = rows.isEmpty
        ? const <DiverWeightEntry>[]
        : await _r.weightEntries.getEntriesForDiver(
            rows.single.read<String>('diver_id'),
          );
    return entries.where((e) => e.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Weight entry $id no longer exists.',
          details: {'id': id},
        ));
  }
}
