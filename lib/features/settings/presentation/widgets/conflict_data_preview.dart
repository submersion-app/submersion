import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_unit_formatters.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(ConflictDataPreview);

/// One labelled line of a conflict's data preview.
typedef ConflictPreviewRow = ({String label, String value});

/// Sync bookkeeping present on nearly every record. None of it helps a user
/// choose between two versions.
const _alwaysHidden = <String>{
  'id',
  'hlc',
  'deviceId',
  'originDeviceId',
  'syncedAt',
};

/// Fields an entity renders some other way, and so must not repeat as raw
/// columns. Quality findings store facts, not prose: `detectorId` and `params`
/// become a localized sentence, so the raw values would only be noise -- but
/// only once that sentence has actually been built.
const _entityHidden = <String, Set<String>>{
  'qualityFindings': {'detectorId', 'detectorVersion', 'params', 'category'},
};

/// Fields worth leading with when an entity has them, carried over from the
/// original preview so dives, sites and gear keep reading the way they did.
const _preferredFields = <String>[
  'name',
  'title',
  'description',
  'date',
  'location',
  'maxDepth',
  'duration',
  'notes',
];

/// A record's data preview: the record's own recognizable fields, then its
/// resolved references, then whatever column the two versions disagree about.
/// A junction row has no recognizable field of its own, so its references
/// lead.
class ConflictDataPreview extends ConsumerWidget {
  const ConflictDataPreview({
    super.key,
    required this.entityType,
    required this.data,
    required this.references,
    this.counterpart = const {},
  });

  final String entityType;
  final Map<String, dynamic> data;
  final List<ConflictReference> references;

  /// The other side of the same conflict, so the preview can surface the
  /// columns the two versions disagree about.
  final Map<String, dynamic> counterpart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return Text(
        context.l10n.settings_conflict_noDataAvailable,
        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    final rows = conflictPreviewRows(
      l10n: context.l10n,
      units: UnitFormatter(ref.watch(settingsProvider)),
      entityType: entityType,
      data: data,
      references: references,
      counterpart: counterpart,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    '${row.label}:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(row.value, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Builds the preview lines for one side of a conflict.
///
/// Order is: the record's own preferred fields, its resolved references, then
/// the columns whose value differs from [counterpart] (the other side of the
/// same conflict). A junction entity has no preferred field, so its references
/// lead. Bookkeeping and already-rendered columns are dropped throughout.
///
/// [counterpart] is what makes the differing column visible: a dive whose two
/// versions share a name but disagree on `diveNumber` would otherwise show
/// only the name, leaving nothing to choose between.
List<ConflictPreviewRow> conflictPreviewRows({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required String entityType,
  required Map<String, dynamic> data,
  required List<ConflictReference> references,
  Map<String, dynamic> counterpart = const {},
}) {
  final message = entityType == 'qualityFindings'
      ? _findingMessage(l10n, units, data)
      : null;

  final hidden = {
    ..._alwaysHidden,
    // Only drop the columns a rendered sentence replaced. If the row could
    // not be read, hiding them too would leave the user with less than the
    // raw preview gave them.
    if (message != null) ...?_entityHidden[entityType],
    for (final reference in references) reference.field,
  };
  final preferred = _preferredScalars(data, hidden);
  final differing = _differingScalars(
    data,
    counterpart,
    hidden,
    preferred.keys.toSet(),
  );

  // Difference and context are both needed: the differing column is what the
  // user is choosing between, but a junction or finding row still has to say
  // what it is. Preferred fields lead, the differing columns follow, and a
  // record with no preferred field then fills up with its remaining columns.
  final scalars = <String, dynamic>{...preferred};
  for (final entry in differing.entries) {
    scalars.putIfAbsent(entry.key, () => entry.value);
  }
  if (preferred.isEmpty) {
    for (final entry in _remainingScalars(data, hidden).entries) {
      if (scalars.length >= 6) break;
      scalars.putIfAbsent(entry.key, () => entry.value);
    }
  }

  ConflictPreviewRow scalarRow(MapEntry<String, dynamic> entry) => (
    label: entry.key,
    value: formatConflictScalar(l10n, units, entry.key, entry.value),
  );

  // A named entity leads with its own name; a junction row has no preferred
  // field, so its references lead instead.
  final rows = <ConflictPreviewRow>[
    for (final entry in preferred.entries) scalarRow(entry),
    for (final reference in references)
      (
        label: conflictReferenceLabel(l10n, reference),
        value: conflictReferenceValue(l10n, units, reference),
      ),
  ];

  if (message != null) {
    rows.add((
      label: l10n.settings_conflict_ref_finding,
      value: '${message.title}: ${message.detail}',
    ));
  }

  for (final entry in scalars.entries) {
    if (preferred.containsKey(entry.key)) continue; // already led the preview
    rows.add(scalarRow(entry));
  }
  return rows;
}

/// Columns stored in metres, bar and Celsius. Rendering them raw would show a
/// metric number to an imperial diver, so each goes through the diver's own
/// formatter.
const _depthFields = <String>{'maxDepth', 'avgDepth', 'depth'};
const _pressureFields = <String>{
  'startPressure',
  'endPressure',
  'workingPressure',
};
const _temperatureFields = <String>{
  'waterTemp',
  'airTemp',
  'temperature',
  'minTemp',
};

/// Columns stored as a count of seconds.
const _durationFields = <String>{'bottomTime', 'runtime', 'duration'};

/// Renders a value the way the app renders it elsewhere: measurements in the
/// diver's units, epoch millis as a date, a flag as yes/no. Everything else
/// prints as stored.
String formatConflictScalar(
  AppLocalizations l10n,
  UnitFormatter units,
  String key,
  Object value,
) {
  if (value is bool) {
    return value ? l10n.common_action_yes : l10n.common_action_no;
  }
  if (value is num) {
    if (_depthFields.contains(key)) return units.formatDepth(value.toDouble());
    if (_pressureFields.contains(key)) {
      return units.formatPressure(value.toDouble());
    }
    if (_temperatureFields.contains(key)) {
      return units.formatTemperature(value.toDouble());
    }
    if (_durationFields.contains(key)) return _formatSeconds(value.toInt());
  }
  if (value is int && _isTimestamp(key, value)) {
    return units.formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(value),
      l10n: l10n,
    );
  }
  return value.toString();
}

/// A stored count of seconds as "1h 5m" or "45min".
///
/// Anything under a minute keeps its seconds instead of collapsing to "0min".
/// The dive field formatter renders those as "--" (unavailable), which is
/// right for a dive summary and wrong here: two versions differing only in a
/// sub-minute value would render identically in the one dialog whose whole
/// job is telling them apart. A negative value takes the same path and shows
/// itself rather than wrapping into a plausible-looking positive minute count.
String _formatSeconds(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}min';
}

/// True for a column that stores a moment rather than a duration. Both the
/// name and the magnitude must agree: `bottomTime` and `runtime` are seconds,
/// so only values large enough to be Unix millis are treated as dates.
///
/// The magnitude is absolute, because a moment before 1970 is a negative
/// count. Those are real here rather than hypothetical: the clock-offset
/// detector exists to flag dives "dated before 1950", so the epochs most
/// likely to reach this dialog after a bad import are exactly the negative
/// ones. Comparing the signed value would print them raw.
bool _isTimestamp(String key, int value) {
  const millisFloor = 100000000000; // ~1973 either side of the epoch
  final named =
      key.endsWith('At') || key.endsWith('Time') || key.endsWith('Date');
  return named && value.abs() >= millisFloor;
}

bool _usable(Map<String, dynamic> data, Set<String> hidden, String key) =>
    !hidden.contains(key) && data[key] != null;

Map<String, dynamic> _preferredScalars(
  Map<String, dynamic> data,
  Set<String> hidden,
) => {
  for (final key in _preferredFields)
    if (data.containsKey(key) && _usable(data, hidden, key)) key: data[key],
};

/// Columns this side disagrees with the other side about. These are the ones
/// a user is actually choosing between, so they are shown even when they are
/// not on the preferred list.
Map<String, dynamic> _differingScalars(
  Map<String, dynamic> data,
  Map<String, dynamic> counterpart,
  Set<String> hidden,
  Set<String> alreadyShown,
) {
  final differing = <String, dynamic>{};
  for (final entry in data.entries) {
    if (differing.length >= 5) break;
    if (alreadyShown.contains(entry.key)) continue;
    if (!_usable(data, hidden, entry.key)) continue;
    if (counterpart[entry.key] != entry.value) {
      differing[entry.key] = entry.value;
    }
  }
  return differing;
}

/// Nothing recognizable: show the first few columns that survived the filter,
/// which for a junction row is what is left after its foreign keys.
Map<String, dynamic> _remainingScalars(
  Map<String, dynamic> data,
  Set<String> hidden,
) {
  final fallback = <String, dynamic>{};
  for (final entry in data.entries) {
    if (fallback.length >= 5) break;
    if (_usable(data, hidden, entry.key)) fallback[entry.key] = entry.value;
  }
  return fallback;
}

/// Rebuilds a finding from its synced row so the data-quality renderer can
/// turn its numeric params into a localized sentence.
///
/// Returns null when the row cannot be read as a finding (a category from a
/// newer schema, malformed params); the preview then falls back to showing the
/// raw columns, which is what it did before.
QualityFindingMessage? _findingMessage(
  AppLocalizations l10n,
  UnitFormatter units,
  Map<String, dynamic> data,
) {
  final detectorId = data['detectorId'];
  if (detectorId is! String || detectorId.isEmpty) return null;
  try {
    final finding = QualityFinding(
      id: data['id'] as String? ?? '',
      diveId: data['diveId'] as String? ?? '',
      detectorId: detectorId,
      detectorVersion: (data['detectorVersion'] as num?)?.toInt() ?? 0,
      category: QualityCategory.values.byName(data['category'] as String),
      severity: QualitySeverity.values.byName(data['severity'] as String),
      status: QualityStatus.values.byName(data['status'] as String),
      params:
          jsonDecode(data['params'] as String? ?? '{}') as Map<String, Object?>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
    return buildFindingMessage(l10n, finding, qualityUnitFormattersFor(units));
  } on ArgumentError catch (e) {
    _log.warning('Conflict preview could not read a finding row', error: e);
    return null;
  } on FormatException catch (e) {
    _log.warning('Conflict preview could not read a finding row', error: e);
    return null;
  } on TypeError catch (e) {
    _log.warning('Conflict preview could not read a finding row', error: e);
    return null;
  }
}
