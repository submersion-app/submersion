import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_attribute_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Writes the equipment CSV. [write]'s `componentNames` maps an assembly's
/// id to its parts' names in template order (issue #1487); items absent
/// from it get an empty cell. Free-text cells go through [sanitizeCsvField]
/// so a spreadsheet never evaluates them as formulas; the importer reverses
/// it.
class CsvEquipmentWriter {
  CsvEquipmentWriter(this.units);

  final CsvExportUnits units;

  // Curated keys already covered by dedicated columns; excluded from the
  // combined Attributes column to avoid duplication. Custom fields are never
  // excluded even if their key collides with one of these, because the
  // dedicated columns read curated attributes only, so a custom "size"
  // would otherwise be dropped from the export entirely.
  static const _dedicatedAttrKeys = {
    EquipmentAttrKeys.size,
    EquipmentAttrKeys.thicknessMm,
    EquipmentAttrKeys.buoyancyKg,
    EquipmentAttrKeys.dryWeightKg,
  };

  String _date(DateTime? date) => date == null ? '' : units.date(date);

  String write(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
  }) {
    final rows = <List<dynamic>>[
      [
        'Name',
        'Type',
        'Brand',
        'Model',
        'Serial Number',
        'Size',
        'Thickness',
        units.dateHeader('Purchase Date'),
        units.dateHeader('Last Service'),
        units.dateHeader('Next Service Due'),
        units.header(CsvColumns.buoyancy),
        units.header(CsvColumns.dryWeight),
        'Attributes',
        'Components',
        'Active',
        'Notes',
      ],
    ];

    for (final item in equipment) {
      rows.add([
        sanitizeCsvField(item.name),
        item.type.displayName,
        sanitizeCsvField(item.brand),
        sanitizeCsvField(item.model),
        sanitizeCsvField(item.serialNumber),
        sanitizeCsvField(item.size),
        sanitizeCsvField(item.thickness),
        _date(item.purchaseDate),
        _date(item.lastServiceDate),
        _date(item.nextServiceDue),
        units.value(CsvColumns.buoyancy, item.buoyancyKg),
        units.value(CsvColumns.dryWeight, item.weightKg),
        sanitizeCsvField(
          joinAttributePairs(
            item.attributes
                .where(
                  (a) =>
                      a.hasValue &&
                      (a.isCustom || !_dedicatedAttrKeys.contains(a.key)),
                )
                .map((a) => formatAttributePair(a, units)),
          ),
        ),
        sanitizeCsvField(
          componentNames[item.id] == null
              ? null
              : joinCsvList(componentNames[item.id]!),
        ),
        item.isActive ? 'Yes' : 'No',
        sanitizeCsvField(item.notes.replaceAll('\n', ' ')),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
