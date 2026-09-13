import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_attribute_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's equipment CSV export (either unit mode) back into
/// equipment maps, attributes and assembly parts included.
class SubmersionEquipmentCsvParser implements ImportParser {
  const SubmersionEquipmentCsvParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionEquipmentCsv,
  ];

  static Map<String, dynamic> _attribute(CsvAttribute a) => {
    'key': a.key,
    'isCustom': a.isCustom,
    'valueText': a.valueText,
    'valueNum': a.valueNum,
  };

  /// A calendar date from the file as local midnight, the way the app's
  /// date pickers store equipment dates.
  static DateTime? _local(DateTime? utcDate) => utcDate == null
      ? null
      : DateTime(utcDate.year, utcDate.month, utcDate.day);

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final dateFormat = table.dateFormatOf('Purchase Date');
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(const [
        CsvColumns.buoyancy,
        CsvColumns.dryWeight,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.equipment,
        ),
    ];
    final items = <Map<String, dynamic>>[];
    final componentCells = <int, String>{};

    for (final (i, row) in table.rows.indexed) {
      final name = table.text(row, 'Name');
      if (name == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 2} has no equipment name and was skipped',
            entityType: ImportEntityType.equipment,
            itemIndex: i,
            field: 'Name',
          ),
        );
        continue;
      }

      warnings.addAll(
        table.cellWarnings(
          row,
          i,
          ImportEntityType.equipment,
          numbers: const ['Buoyancy', 'Dry Weight'],
          dates: const ['Purchase Date', 'Last Service', 'Next Service Due'],
        ),
      );
      final attributes = <Map<String, dynamic>>[];
      final thickness = table.text(row, 'Thickness');
      if (thickness != null) {
        attributes.add({
          'key': EquipmentAttrKeys.thicknessMm,
          'isCustom': false,
          'valueText': thickness,
          'valueNum': parsePrimaryThickness(thickness),
        });
      }
      for (final (column, key) in const [
        (CsvColumns.buoyancy, EquipmentAttrKeys.buoyancyKg),
        (CsvColumns.dryWeight, EquipmentAttrKeys.dryWeightKg),
      ]) {
        final kg = table.quantity(row, column);
        if (kg != null) {
          attributes.add({'key': key, 'isCustom': false, 'valueNum': kg});
        }
      }
      for (final pair in splitAttributePairs(
        table.text(row, 'Attributes') ?? '',
      )) {
        final parsed = parseAttributePair(pair, dateFormat: dateFormat);
        if (parsed == null) {
          warnings.add(
            ImportWarning(
              severity: ImportWarningSeverity.warning,
              message: 'Attribute "$pair" of "$name" could not be read',
              entityType: ImportEntityType.equipment,
              itemIndex: items.length,
              field: 'Attributes',
            ),
          );
        } else {
          attributes.add(_attribute(parsed));
        }
      }

      final lastService = table.date(row, 'Last Service');
      final nextDue = table.date(row, 'Next Service Due');
      // Both are UTC midnights, so the difference is whole days even
      // across a daylight-saving change.
      final interval = lastService != null && nextDue != null
          ? nextDue.difference(lastService).inDays
          : null;
      final active = table.text(row, 'Active')?.toLowerCase();

      final components = table.text(row, 'Components');
      if (components != null) componentCells[items.length] = components;

      items.add(
        <String, dynamic>{
          'uddfId': 'csv-equipment-$i',
          'name': name,
          'type':
              (enumByDisplayName(
                        EquipmentType.values,
                        (v) => v.displayName,
                        table.text(row, 'Type'),
                      ) ??
                      EquipmentType.other)
                  .name,
          'brand': table.text(row, 'Brand'),
          'model': table.text(row, 'Model'),
          'serialNumber': table.text(row, 'Serial Number'),
          'size': table.text(row, 'Size'),
          'purchaseDate': _local(table.date(row, 'Purchase Date')),
          'lastServiceDate': _local(lastService),
          'serviceIntervalDays': interval != null && interval > 0
              ? interval
              : null,
          'isActive': active == 'yes' ? true : (active == 'no' ? false : null),
          'notes': table.text(row, 'Notes'),
          if (attributes.isNotEmpty) 'attributes': attributes,
        }..removeWhere((_, value) => value == null),
      );
    }

    _resolveComponents(items, componentCells, warnings);

    return ImportPayload(
      entities: {if (items.isNotEmpty) ImportEntityType.equipment: items},
      warnings: warnings,
    );
  }

  /// The Components column lists part names; each resolves to the one row
  /// of this file with that name. A missing or ambiguous name is skipped
  /// with a warning rather than guessed.
  static void _resolveComponents(
    List<Map<String, dynamic>> items,
    Map<int, String> cells,
    List<ImportWarning> warnings,
  ) {
    final idsByName = <String, List<String>>{};
    for (final item in items) {
      idsByName
          .putIfAbsent(item['name'] as String, () => [])
          .add(item['uddfId'] as String);
    }
    for (final MapEntry(key: index, value: cell) in cells.entries) {
      final owner = items[index]['name'];
      final parts = <Map<String, dynamic>>[];
      for (final name in cell.split('; ').map((s) => s.trim())) {
        if (name.isEmpty) continue;
        final ids = idsByName[name] ?? const [];
        if (ids.length != 1) {
          warnings.add(
            ImportWarning(
              severity: ImportWarningSeverity.warning,
              message: ids.isEmpty
                  ? 'Part "$name" of "$owner" is not in this file and was '
                        'not linked'
                  : 'Part "$name" of "$owner" matches several items and '
                        'was not linked',
              entityType: ImportEntityType.equipment,
              itemIndex: index,
              field: 'Components',
            ),
          );
          continue;
        }
        parts.add({
          'componentRef': ids.single,
          'role': '',
          'sortOrder': parts.length,
        });
      }
      if (parts.isNotEmpty) items[index]['components'] = parts;
    }
  }
}
