import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';

/// Feeds dives to the shared EntityTableView (#2984). Carries the context
/// the dive columns need that a field enum cannot: the RMV gas model, the
/// dive-type label resolver and the computed surface intervals.
class DiveFieldAdapter extends EntityFieldAdapter<Dive, DiveField> {
  DiveFieldAdapter({
    this.gasModel = GasModel.real,
    this.diveTypeLabel,
    this.surfaceIntervals = const {},
  });

  final GasModel gasModel;
  final String Function(String id)? diveTypeLabel;

  /// `diveSurfaceIntervalsProvider`'s map (stored, else computed). A dive
  /// missing from it (still loading, or the read failed) shows its stored
  /// value.
  final Map<String, Duration?> surfaceIntervals;

  @override
  List<DiveField> get allFields => DiveField.values;

  @override
  Map<String, List<DiveField>> get fieldsByCategory => {
    for (final c in DiveFieldCategory.values)
      c.name: DiveField.fieldsForCategory(c),
  };

  @override
  dynamic extractValue(DiveField field, Dive entity) {
    if (field == DiveField.surfaceInterval &&
        surfaceIntervals.containsKey(entity.id)) {
      return surfaceIntervals[entity.id];
    }
    return field.extractFromDive(
      entity,
      gasModel: gasModel,
      diveTypeLabel: diveTypeLabel,
    );
  }

  @override
  String formatValue(DiveField field, dynamic value, UnitFormatter units) =>
      field.formatValue(value, units);

  @override
  DiveField fieldFromName(String name) =>
      diveFieldFromName(name) ?? DiveField.diveNumber;
}

/// The dive table's stored config as the shared table reads it. Same JSON
/// shape, so nothing stored changes.
extension TableViewConfigEntityView on TableViewConfig {
  EntityTableViewConfig<DiveField> toEntityConfig() =>
      EntityTableViewConfig<DiveField>(
        columns: [
          for (final c in columns)
            EntityTableColumnConfig<DiveField>(
              field: c.field,
              width: c.width,
              isPinned: c.isPinned,
            ),
        ],
        sortField: sortField,
        sortAscending: sortAscending,
      );
}
