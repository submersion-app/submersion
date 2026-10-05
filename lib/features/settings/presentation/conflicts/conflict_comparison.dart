import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_finding_message.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

enum ConflictComparisonState {
  /// Both versions exist and disagree on at least one field.
  differing,

  /// The other device deleted the record; this device still has it.
  remoteDeleted,

  /// This device deleted the record; the other device still has it.
  localDeleted,

  /// Both versions exist and agree on everything a diver can see.
  sameContent,
}

/// One field the two versions disagree on.
@immutable
class FieldDifference {
  const FieldDifference({
    required this.key,
    required this.label,
    required this.kind,
    required this.localValue,
    required this.remoteValue,
    required this.localDisplay,
    required this.remoteDisplay,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final Object? localValue;
  final Object? remoteValue;
  final String localDisplay;
  final String remoteDisplay;
}

/// One field shown with a single value.
@immutable
class ShownField {
  const ShownField({
    required this.key,
    required this.label,
    required this.display,
  });

  final String key;
  final String label;
  final String display;
}

/// Everything the dialog shows about one conflict.
@immutable
class ConflictComparison {
  const ConflictComparison({
    required this.state,
    this.differences = const [],
    this.unchanged = const [],
    this.survivingValues = const [],
  });

  final ConflictComparisonState state;

  /// [ConflictComparisonState.differing] only.
  final List<FieldDifference> differences;

  /// Fields both versions agree on.
  final List<ShownField> unchanged;

  /// In a deletion state, the record as the side that still has it has it.
  final List<ShownField> survivingValues;
}

/// Fields a diver recognizes a record by, so they lead the list.
const _preferredOrder = <String>[
  'name',
  'title',
  'diveNumber',
  'diveDateTime',
  'date',
  'location',
  'maxDepth',
  'runtime',
  'bottomTime',
  'duration',
  'notes',
  'description',
];

/// Key of the synthetic row that carries a quality finding's sentence.
const _findingKey = '_finding';

/// Raw finding columns the finding sentence replaces.
const _findingColumns = {'detectorId', 'detectorVersion', 'params', 'category'};

const _equality = DeepCollectionEquality();

/// JSON decodes 26.0 as 26, so numbers compare by value.
bool _same(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  return _equality.equals(a, b);
}

/// Compares the two versions of [conflict] field by field.
///
/// Only keys present on both sides are compared. A key the remote map omits
/// keeps its local value under every choice ("Keep remote" overlays the
/// remote map onto the local row), so it is not something the diver can
/// lose; a key only the remote has belongs to a newer schema this build does
/// not store.
ConflictComparison buildConflictComparison({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required SyncConflict conflict,
}) {
  final entity = conflict.entityType;
  final local = conflict.localData;
  final remote = conflict.remoteData;
  final localRefs = {for (final r in conflict.localReferences) r.field: r};
  final remoteRefs = {for (final r in conflict.remoteReferences) r.field: r};

  // Each column's label and kind, resolved once however often it is asked.
  final fields = <String, ConflictField>{};
  ConflictField fieldOf(String key) =>
      fields.putIfAbsent(key, () => conflictFieldFor(entity, key));

  String labelFor(String key) {
    final target = ConflictReferenceResolver.targetTypeFor(entity, key);
    if (target == null) return fieldOf(key).label(l10n);
    final reference =
        localRefs[key] ??
        remoteRefs[key] ??
        ConflictReference(field: key, targetType: target, recordId: '');
    return conflictReferenceLabel(l10n, reference);
  }

  String display(
    String key,
    Object? value,
    Map<String, ConflictReference> refs,
  ) {
    if (value == null) return l10n.settings_conflict_notSet;
    final reference = refs[key];
    if (reference != null) {
      return conflictReferenceValue(l10n, units, reference);
    }
    return formatConflictValue(
      l10n: l10n,
      units: units,
      field: fieldOf(key),
      value: value,
    );
  }

  bool opaque(String key) => fieldOf(key).kind == FieldKind.opaque;

  // A deleted record's values: an opaque payload has nothing a diver could
  // read, so it is left out rather than shown as a bare placeholder.
  List<ShownField> shown(
    Map<String, dynamic> data,
    Map<String, ConflictReference> refs,
  ) => _sorted(
    [
      for (final entry in data.entries)
        if (_compared(entry.key) && entry.value != null && !opaque(entry.key))
          ShownField(
            key: entry.key,
            label: labelFor(entry.key),
            display: display(entry.key, entry.value, refs),
          ),
    ],
    (f) => f.key,
    (f) => f.label,
  );

  if (remote['_deleted'] == true) {
    return ConflictComparison(
      state: ConflictComparisonState.remoteDeleted,
      survivingValues: shown(local, localRefs),
    );
  }
  if (local.isEmpty) {
    return ConflictComparison(
      state: ConflictComparisonState.localDeleted,
      survivingValues: shown(remote, remoteRefs),
    );
  }

  final differences = <FieldDifference>[];
  final unchanged = <ShownField>[];
  final hidden = <String>{};

  // A finding stores facts, not prose; its sentence says what it is. Its raw
  // columns are hidden only once both sentences were built, or the diver
  // would be left with less than the columns gave them.
  if (entity == 'qualityFindings') {
    final localMessage = conflictFindingMessage(l10n, units, local);
    final remoteMessage = conflictFindingMessage(l10n, units, remote);
    if (localMessage != null && remoteMessage != null) {
      hidden.addAll(_findingColumns);
      final l = '${localMessage.title}: ${localMessage.detail}';
      final r = '${remoteMessage.title}: ${remoteMessage.detail}';
      final label = l10n.settings_conflict_ref_finding;
      if (l == r) {
        unchanged.add(ShownField(key: _findingKey, label: label, display: l));
      } else {
        differences.add(
          FieldDifference(
            key: _findingKey,
            label: label,
            kind: FieldKind.shortText,
            localValue: l,
            remoteValue: r,
            localDisplay: l,
            remoteDisplay: r,
          ),
        );
      }
    }
  }

  for (final entry in local.entries) {
    final key = entry.key;
    if (!_compared(key) || hidden.contains(key)) continue;
    if (!remote.containsKey(key) || _same(entry.value, remote[key])) {
      if (entry.value != null) {
        unchanged.add(
          ShownField(
            key: key,
            label: labelFor(key),
            // The formatter says "Changed" for an opaque payload, which is
            // right in the differences and wrong here.
            display: opaque(key)
                ? l10n.settings_conflict_same
                : display(key, entry.value, localRefs),
          ),
        );
      }
      continue;
    }
    differences.add(
      FieldDifference(
        key: key,
        label: labelFor(key),
        kind: fieldOf(key).kind,
        localValue: entry.value,
        remoteValue: remote[key],
        localDisplay: display(key, entry.value, localRefs),
        remoteDisplay: display(key, remote[key], remoteRefs),
      ),
    );
  }

  final sortedDifferences = _sorted(differences, (d) => d.key, (d) => d.label);
  return ConflictComparison(
    state: sortedDifferences.isEmpty
        ? ConflictComparisonState.sameContent
        : ConflictComparisonState.differing,
    differences: sortedDifferences,
    unchanged: _sorted(unchanged, (f) => f.key, (f) => f.label),
  );
}

/// Bookkeeping and tombstone markers are never shown. `deletedAt` only ever
/// arrives on a remote tombstone: no synced table has such a column.
bool _compared(String key) =>
    !conflictBookkeepingColumns.contains(key) &&
    !key.startsWith('_') &&
    key != 'deletedAt';

List<T> _sorted<T>(
  List<T> items,
  String Function(T) key,
  String Function(T) label,
) {
  int rank(T item) {
    if (key(item) == _findingKey) return -1;
    final i = _preferredOrder.indexOf(key(item));
    return i < 0 ? _preferredOrder.length : i;
  }

  return List.unmodifiable(
    [...items]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : label(a).compareTo(label(b));
    }),
  );
}
