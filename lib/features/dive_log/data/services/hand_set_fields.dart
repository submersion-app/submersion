import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/database.dart';

/// A computer-written value of a dive that the diver can set by hand (issue
/// #4909). A re-parse and a resync write these from the fresh parse; once
/// the diver has set one, both keep it unless the diver chooses the parse.
///
/// The name is the key stored in `dives.hand_set_fields`, so it never
/// changes. A field can span columns: the start is `entry_time` and
/// `dive_date_time`, the diluent its O2 and helium.
enum HandSetField {
  maxDepth,
  avgDepth,
  runtime,
  entryTime,
  exitTime,
  bottomTime,
  waterTemp,
  diveMode,
  gradientFactorLow,
  gradientFactorHigh,
  decoAlgorithm,
  decoConservatism,
  diluent;

  /// The field stored under [key], or null for a key this version does not
  /// know (written by a newer peer).
  static HandSetField? fromKey(String key) {
    for (final field in values) {
      if (field.name == key) return field;
    }
    return null;
  }

  /// This field's value in [row], one comparable object across its columns.
  ///
  /// Read as the dive page reads it, so the page writing back what it read
  /// is no change: a diluent without helium is one with none, and a mode
  /// this version does not know is open circuit.
  Object? valueIn(Dive row) => switch (this) {
    maxDepth => row.maxDepth,
    avgDepth => row.avgDepth,
    runtime => row.runtime,
    entryTime => (row.entryTime, row.diveDateTime),
    exitTime => row.exitTime,
    bottomTime => row.bottomTime,
    waterTemp => row.waterTemp,
    diveMode => DiveMode.fromCode(row.diveMode).code,
    gradientFactorLow => row.gradientFactorLow,
    gradientFactorHigh => row.gradientFactorHigh,
    decoAlgorithm => row.decoAlgorithm,
    decoConservatism => row.decoConservatism,
    diluent => switch (row.diluentO2) {
      null => null,
      final o2 => (o2, row.diluentHe ?? 0.0),
    },
  };

  /// [companion] with this field's columns left as stored.
  DivesCompanion leaveOut(DivesCompanion companion) => switch (this) {
    maxDepth => companion.copyWith(maxDepth: const Value.absent()),
    avgDepth => companion.copyWith(avgDepth: const Value.absent()),
    runtime => companion.copyWith(runtime: const Value.absent()),
    entryTime => companion.copyWith(
      entryTime: const Value.absent(),
      diveDateTime: const Value.absent(),
    ),
    exitTime => companion.copyWith(exitTime: const Value.absent()),
    bottomTime => companion.copyWith(bottomTime: const Value.absent()),
    waterTemp => companion.copyWith(waterTemp: const Value.absent()),
    diveMode => companion.copyWith(diveMode: const Value.absent()),
    gradientFactorLow => companion.copyWith(
      gradientFactorLow: const Value.absent(),
    ),
    gradientFactorHigh => companion.copyWith(
      gradientFactorHigh: const Value.absent(),
    ),
    decoAlgorithm => companion.copyWith(decoAlgorithm: const Value.absent()),
    decoConservatism => companion.copyWith(
      decoConservatism: const Value.absent(),
    ),
    diluent => companion.copyWith(
      diluentO2: const Value.absent(),
      diluentHe: const Value.absent(),
    ),
  };
}

/// Reads and writes the `dives.hand_set_fields` text: a JSON list of
/// [HandSetField] keys. Keys are kept as text, so a key a newer peer wrote
/// survives a write by this version.
abstract final class HandSetMarks {
  /// The keys in [text]; none for null, empty or unreadable text.
  static Set<String> decode(String? text) {
    if (text == null || text.isEmpty) return {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return {};
      return {
        for (final key in decoded)
          if (key is String) key,
      };
    } on FormatException {
      return {};
    }
  }

  /// [keys] as stored, sorted so equal sets write equal text; null for none.
  static String? encode(Set<String> keys) =>
      keys.isEmpty ? null : jsonEncode(keys.toList()..sort());

  /// The known fields among [keys].
  static Set<HandSetField> fieldsOf(Set<String> keys) => {
    for (final key in keys) ?HandSetField.fromKey(key),
  };
}

/// Whether the diver has set any value of [diveId] by hand. A preview asks
/// first, so a dive with none is never parsed twice.
Future<bool> hasHandSetMarks(AppDatabase db, String diveId) async {
  final row =
      await (db.selectOnly(db.dives)
            ..addColumns([db.dives.handSetFields])
            ..where(db.dives.id.equals(diveId)))
          .getSingleOrNull();
  return HandSetMarks.decode(row?.read(db.dives.handSetFields)).isNotEmpty;
}

/// Clears the marks of [fields] on [diveId], after a write that replaced
/// their values with ones the diver did not set (a download filling a
/// planned dive). Other marks, a newer peer's included, stay. Call it
/// inside that write's transaction.
Future<void> clearHandSetMarks(
  AppDatabase db,
  String diveId,
  Set<HandSetField> fields,
) async {
  final row =
      await (db.selectOnly(db.dives)
            ..addColumns([db.dives.handSetFields])
            ..where(db.dives.id.equals(diveId)))
          .getSingleOrNull();
  final keys = HandSetMarks.decode(row?.read(db.dives.handSetFields));
  final remaining = keys.difference({for (final field in fields) field.name});
  if (remaining.length == keys.length) return;
  await (db.update(db.dives)..where((t) => t.id.equals(diveId))).write(
    DivesCompanion(handSetFields: Value(HandSetMarks.encode(remaining))),
  );
}

/// Sets the marks of [targetId], a dive a merge or split has just written,
/// from [sources], the dives as they were before it (issue #4909).
///
/// A mark follows the value it marked: a field is marked on the target when
/// its value there equals that of a source that had it marked, so a value
/// the operation carried across stays the diver's and one it recomputed (a
/// combined runtime, a split dive's depths) does not. A key this version
/// does not know is carried as it is. The target's own marks are replaced.
/// Call it inside the operation's transaction.
Future<void> carryHandSetMarks(
  AppDatabase db,
  String targetId,
  Iterable<Dive> sources,
) async {
  final target = await (db.select(
    db.dives,
  )..where((t) => t.id.equals(targetId))).getSingleOrNull();
  if (target == null) return;
  bool carries(String key, Dive source) => switch (HandSetField.fromKey(key)) {
    null => true,
    final field => field.valueIn(source) == field.valueIn(target),
  };
  final carried = HandSetMarks.encode({
    for (final source in sources)
      for (final key in HandSetMarks.decode(source.handSetFields))
        if (carries(key, source)) key,
  });
  if (carried == target.handSetFields) return;
  await (db.update(db.dives)..where((t) => t.id.equals(targetId))).write(
    DivesCompanion(handSetFields: Value(carried)),
  );
}

/// The fields whose columns differ between [before] and [after].
Set<HandSetField> changedHandSetFields(Dive before, Dive after) => {
  for (final field in HandSetField.values)
    if (field.valueIn(before) != field.valueIn(after)) field,
};

/// A value the diver set by hand that a parse would have replaced.
class HandSetChange {
  const HandSetChange({
    required this.field,
    required this.storedValue,
    required this.parsedValue,
  });

  final HandSetField field;

  /// The value as stored, the diver's, in [HandSetField.valueIn]'s shape.
  final Object? storedValue;

  /// What the parse would write in its place.
  final Object? parsedValue;
}

/// [parse], the dive row a re-parse or resync would write over [stored],
/// with every field the diver set by hand left as stored, unless named in
/// [replace].
///
/// [replace] holds the changes the diver chose the parse for, as a preview
/// showed them. One whose stored value has changed since (a sync, another
/// edit) is kept: the diver never saw the value it would now replace.
///
/// [kept] lists, in [HandSetField] order, each kept field the parse would
/// have changed: what the preview offers and the bulk re-parse counts. A
/// field in [replace] takes the parse and loses its mark, written in the
/// returned companion; with no mark lost, the marks column is left alone.
({DivesCompanion companion, List<HandSetChange> kept}) keepHandSetFields(
  DivesCompanion parse,
  Dive stored, {
  Iterable<HandSetChange> replace = const [],
}) {
  final keys = HandSetMarks.decode(stored.handSetFields);
  final marked = HandSetMarks.fieldsOf(keys);
  if (marked.isEmpty) return (companion: parse, kept: const []);
  final replacing = {
    for (final change in replace)
      if (change.field.valueIn(stored) == change.storedValue) change.field,
  };

  // In HandSetField order, the marked fields this write leaves as stored.
  final keeping = [
    for (final field in HandSetField.values)
      if (marked.contains(field) && !replacing.contains(field)) field,
  ];
  final written = stored.copyWithCompanion(parse);
  final kept = [
    for (final field in keeping)
      if (field.valueIn(stored) != field.valueIn(written))
        HandSetChange(
          field: field,
          storedValue: field.valueIn(stored),
          parsedValue: field.valueIn(written),
        ),
  ];
  final left = keeping.fold(parse, (c, field) => field.leaveOut(c));
  final companion = _exitFollowsKeptTimes(left, stored, marked, replacing);
  final remaining = keys.difference({
    for (final field in replacing)
      if (marked.contains(field)) field.name,
  });
  if (remaining.length != keys.length) {
    return (
      companion: companion.copyWith(
        handSetFields: Value(HandSetMarks.encode(remaining)),
      ),
      kept: List.unmodifiable(kept),
    );
  }
  return (companion: companion, kept: List.unmodifiable(kept));
}

/// [companion] with its exit at the dive's start plus runtime, when the
/// start or the runtime is the diver's and the exit is not: the parse
/// computed its exit from its own start and duration, which a kept value
/// no longer matches. A companion writing no exit is left alone.
DivesCompanion _exitFollowsKeptTimes(
  DivesCompanion companion,
  Dive stored,
  Set<HandSetField> marked,
  Set<HandSetField> replace,
) {
  bool kept(HandSetField field) =>
      marked.contains(field) && !replace.contains(field);
  if (!companion.exitTime.present || kept(HandSetField.exitTime)) {
    return companion;
  }
  if (!kept(HandSetField.entryTime) && !kept(HandSetField.runtime)) {
    return companion;
  }
  final written = stored.copyWithCompanion(companion);
  final runtime = written.runtime;
  if (runtime == null) return companion;
  final start = written.entryTime ?? written.diveDateTime;
  return companion.copyWith(exitTime: Value(start + runtime * 1000));
}

/// Marks, on each dive of [before], the fields the diver's write just
/// changed: [before] are the rows as read before it, and the rows as stored
/// now are compared with them. Marks only grow here; a field already marked
/// stays marked. Call it inside the write's transaction, so the mark is in
/// the same History entry and reverts with it.
Future<void> markHandSetChanges(AppDatabase db, Iterable<Dive> before) async {
  final byId = {for (final row in before) row.id: row};
  if (byId.isEmpty) return;
  final after = await (db.select(
    db.dives,
  )..where((t) => t.id.isIn(byId.keys))).get();
  for (final row in after) {
    final changed = changedHandSetFields(byId[row.id]!, row);
    if (changed.isEmpty) continue;
    final keys = HandSetMarks.decode(row.handSetFields);
    final marked = keys.union({for (final field in changed) field.name});
    if (marked.length == keys.length) continue;
    await (db.update(db.dives)..where((t) => t.id.equals(row.id))).write(
      DivesCompanion(handSetFields: Value(HandSetMarks.encode(marked))),
    );
  }
}
