import 'dart:typed_data';

import 'package:characters/characters.dart';

import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/utils/byte_format.dart';

/// The most of a text value the feed shows.
const int kChangeLogFeedClip = 200;

/// Reads a logged column the way the conflict dialog reads a synced one: the
/// diver's units and language, and a record's name in place of an id. A value
/// keeps its SQLite type, so a blob is shown as a size and long text can be
/// clipped, because a feed row must never lay out a huge string.
class ChangeLogValueFormatter {
  const ChangeLogValueFormatter({
    required this.l10n,
    required this.units,
    this.references = const {},
  });

  final AppLocalizations l10n;
  final UnitFormatter units;

  /// Foreign keys resolved ahead of time, by [changeLogReferenceKey].
  final Map<String, List<ConflictReference>> references;

  String label(String table, String column) =>
      conflictFieldFor(columnJsonKey(table), columnJsonKey(column)).label(l10n);

  String value(String table, String column, Object? value, {int? clip}) {
    if (value == null) return l10n.settings_conflict_notSet;
    if (value is Uint8List) {
      return l10n.changeLog_value_data(formatBytes(value.length));
    }
    final entity = changeLogEntityType(table);
    final key = columnJsonKey(column);
    final refs = references[changeLogReferenceKey(entity, key, value)];
    final text = refs != null && refs.isNotEmpty
        ? refs.map((r) => conflictReferenceValue(l10n, units, r)).join(', ')
        : formatConflictValue(
            l10n: l10n,
            units: units,
            field: conflictFieldFor(entity, key),
            value: value,
          );
    if (clip == null || text.characters.length <= clip) return text;
    return '${text.characters.take(clip)}…';
  }
}
