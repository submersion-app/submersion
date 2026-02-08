import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Handles Excel export with multiple worksheet sheets.
class ExcelExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');

  /// Export all dive data to Excel format and share via system sheet.
  ///
  /// Creates an Excel workbook with four sheets:
  /// - Dives: All dive logs with details
  /// - Sites: All dive sites
  /// - Equipment: All equipment items
  /// - Statistics: Summary statistics and breakdowns
  Future<String> exportToExcel({
    required List<Dive> dives,
    required List<DiveSite> sites,
    required List<EquipmentItem> equipment,
    required DepthUnit depthUnit,
    required TemperatureUnit temperatureUnit,
    required PressureUnit pressureUnit,
    required VolumeUnit volumeUnit,
    required DateFormatPreference dateFormat,
  }) async {
    final bytes = await generateExcelBytes(
      dives: dives,
      sites: sites,
      equipment: equipment,
      depthUnit: depthUnit,
      temperatureUnit: temperatureUnit,
      pressureUnit: pressureUnit,
      volumeUnit: volumeUnit,
      dateFormat: dateFormat,
    );

    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'submersion_export_$dateStr.xlsx';

    return saveAndShareFileBytes(
      bytes,
      fileName,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Generate Excel bytes without sharing.
  Future<List<int>> generateExcelBytes({
    required List<Dive> dives,
    required List<DiveSite> sites,
    required List<EquipmentItem> equipment,
    required DepthUnit depthUnit,
    required TemperatureUnit temperatureUnit,
    required PressureUnit pressureUnit,
    required VolumeUnit volumeUnit,
    required DateFormatPreference dateFormat,
  }) async {
    final excel = xl.Excel.createExcel();

    excel.delete('Sheet1');

    _buildDivesSheet(
      excel,
      dives,
      depthUnit,
      temperatureUnit,
      pressureUnit,
      volumeUnit,
      dateFormat,
    );
    _buildSitesSheet(excel, sites, depthUnit);
    _buildEquipmentSheet(excel, equipment, dateFormat);
    _buildStatisticsSheet(
      excel,
      dives,
      sites,
      equipment,
      depthUnit,
      temperatureUnit,
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    return bytes;
  }

  /// Save Excel file to a user-selected location.
  Future<String?> saveExcelToFile({
    required List<Dive> dives,
    required List<DiveSite> sites,
    required List<EquipmentItem> equipment,
    required DepthUnit depthUnit,
    required TemperatureUnit temperatureUnit,
    required PressureUnit pressureUnit,
    required VolumeUnit volumeUnit,
    required DateFormatPreference dateFormat,
  }) async {
    final bytes = await generateExcelBytes(
      dives: dives,
      sites: sites,
      equipment: equipment,
      depthUnit: depthUnit,
      temperatureUnit: temperatureUnit,
      pressureUnit: pressureUnit,
      volumeUnit: volumeUnit,
      dateFormat: dateFormat,
    );

    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'submersion_export_$dateStr.xlsx';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Excel File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );

    if (result == null) return null;

    if (!Platform.isAndroid) {
      final file = File(result);
      await file.writeAsBytes(Uint8List.fromList(bytes));
    }

    return result;
  }

  // ==================== Sheet Builders ====================

  void _buildDivesSheet(
    xl.Excel excel,
    List<Dive> dives,
    DepthUnit depthUnit,
    TemperatureUnit temperatureUnit,
    PressureUnit pressureUnit,
    VolumeUnit volumeUnit,
    DateFormatPreference dateFormat,
  ) {
    final sheet = excel['Dives'];

    final headers = [
      'Dive Number',
      'Date',
      'Time',
      'Site',
      'Location',
      'Max Depth (${depthUnit.symbol})',
      'Avg Depth (${depthUnit.symbol})',
      'Bottom Time (min)',
      'Runtime (min)',
      'Water Temp (${temperatureUnit.symbol})',
      'Air Temp (${temperatureUnit.symbol})',
      'Visibility',
      'Dive Type',
      'Dive Mode',
      'Buddy',
      'Dive Master',
      'Rating',
      'Start Pressure (${pressureUnit.symbol})',
      'End Pressure (${pressureUnit.symbol})',
      'Tank Volume (${volumeUnit.symbol})',
      'O2 %',
      'He %',
      'Notes',
    ];

    for (var col = 0; col < headers.length; col++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = xl.TextCellValue(
        headers[col],
      );
    }

    for (var row = 0; row < dives.length; row++) {
      final dive = dives[row];
      final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;

      final rowData = <dynamic>[
        dive.diveNumber ?? '',
        formatDateForExport(dive.dateTime, dateFormat),
        _timeFormat.format(dive.dateTime),
        dive.site?.name ?? '',
        dive.site?.locationString ?? '',
        convertDepth(dive.maxDepth, depthUnit),
        convertDepth(dive.avgDepth, depthUnit),
        dive.duration?.inMinutes ?? '',
        dive.runtime?.inMinutes ?? '',
        convertTemperature(dive.waterTemp, temperatureUnit),
        convertTemperature(dive.airTemp, temperatureUnit),
        dive.visibility?.displayName ?? '',
        dive.diveTypeName,
        dive.diveMode.displayName,
        dive.buddy,
        dive.diveMaster,
        dive.rating ?? '',
        convertPressure(tank?.startPressure?.toDouble(), pressureUnit),
        convertPressure(tank?.endPressure?.toDouble(), pressureUnit),
        convertVolume(tank?.volume, volumeUnit),
        tank?.gasMix.o2.toStringAsFixed(0) ?? '',
        tank?.gasMix.he.toStringAsFixed(0) ?? '',
        dive.notes.replaceAll('\n', ' '),
      ];

      for (var col = 0; col < rowData.length; col++) {
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: row + 1,
              ),
            )
            .value = _toCellValue(
          rowData[col],
        );
      }
    }
  }

  void _buildSitesSheet(
    xl.Excel excel,
    List<DiveSite> sites,
    DepthUnit depthUnit,
  ) {
    final sheet = excel['Sites'];

    final headers = [
      'Name',
      'Country',
      'Region',
      'Latitude',
      'Longitude',
      'Min Depth (${depthUnit.symbol})',
      'Max Depth (${depthUnit.symbol})',
      'Water Type',
      'Typical Current',
      'Entry Type',
      'Difficulty',
      'Rating',
      'Description',
      'Hazards',
      'Access Notes',
      'Notes',
    ];

    for (var col = 0; col < headers.length; col++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = xl.TextCellValue(
        headers[col],
      );
    }

    for (var row = 0; row < sites.length; row++) {
      final site = sites[row];

      final rowData = <dynamic>[
        site.name,
        site.country ?? '',
        site.region ?? '',
        site.location?.latitude.toStringAsFixed(6) ?? '',
        site.location?.longitude.toStringAsFixed(6) ?? '',
        convertDepth(site.minDepth, depthUnit),
        convertDepth(site.maxDepth, depthUnit),
        site.conditions?.waterType ?? '',
        site.conditions?.typicalCurrent ?? '',
        site.conditions?.entryType ?? '',
        site.difficulty?.displayName ?? '',
        site.rating?.toStringAsFixed(1) ?? '',
        site.description.replaceAll('\n', ' '),
        site.hazards ?? '',
        site.accessNotes ?? '',
        site.notes.replaceAll('\n', ' '),
      ];

      for (var col = 0; col < rowData.length; col++) {
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: row + 1,
              ),
            )
            .value = _toCellValue(
          rowData[col],
        );
      }
    }
  }

  void _buildEquipmentSheet(
    xl.Excel excel,
    List<EquipmentItem> equipment,
    DateFormatPreference dateFormat,
  ) {
    final sheet = excel['Equipment'];

    final headers = [
      'Name',
      'Type',
      'Brand',
      'Model',
      'Serial Number',
      'Size',
      'Status',
      'Purchase Date',
      'Last Service',
      'Next Service Due',
      'Active',
      'Notes',
    ];

    for (var col = 0; col < headers.length; col++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = xl.TextCellValue(
        headers[col],
      );
    }

    for (var row = 0; row < equipment.length; row++) {
      final item = equipment[row];

      final rowData = <dynamic>[
        item.name,
        item.type.displayName,
        item.brand ?? '',
        item.model ?? '',
        item.serialNumber ?? '',
        item.size ?? '',
        item.status.displayName,
        item.purchaseDate != null
            ? formatDateForExport(item.purchaseDate!, dateFormat)
            : '',
        item.lastServiceDate != null
            ? formatDateForExport(item.lastServiceDate!, dateFormat)
            : '',
        item.nextServiceDue != null
            ? formatDateForExport(item.nextServiceDue!, dateFormat)
            : '',
        item.isActive ? 'Yes' : 'No',
        item.notes.replaceAll('\n', ' '),
      ];

      for (var col = 0; col < rowData.length; col++) {
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: row + 1,
              ),
            )
            .value = _toCellValue(
          rowData[col],
        );
      }
    }
  }

  void _buildStatisticsSheet(
    xl.Excel excel,
    List<Dive> dives,
    List<DiveSite> sites,
    List<EquipmentItem> equipment,
    DepthUnit depthUnit,
    TemperatureUnit temperatureUnit,
  ) {
    final sheet = excel['Statistics'];
    var currentRow = 0;

    void addHeader(String text) {
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = xl.TextCellValue(
        text,
      );
      currentRow++;
    }

    void addStat(String label, dynamic value) {
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = xl.TextCellValue(
        label,
      );
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = _toCellValue(
        value,
      );
      currentRow++;
    }

    // Summary Stats
    addHeader('SUMMARY STATISTICS');
    currentRow++;

    addStat('Total Dives', dives.length);
    addStat('Total Dive Sites', sites.length);
    addStat('Total Equipment Items', equipment.length);

    if (dives.isNotEmpty) {
      final totalMinutes = dives.fold<int>(
        0,
        (sum, d) => sum + (d.duration?.inMinutes ?? 0),
      );
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      addStat('Total Bottom Time', '${hours}h ${mins}m');

      final sortedDives = [...dives]
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      addStat('First Dive', _dateFormat.format(sortedDives.first.dateTime));
      addStat('Last Dive', _dateFormat.format(sortedDives.last.dateTime));

      final deepestDive = dives.reduce(
        (a, b) => (a.maxDepth ?? 0) > (b.maxDepth ?? 0) ? a : b,
      );
      if (deepestDive.maxDepth != null) {
        final depthValue = convertDepth(deepestDive.maxDepth, depthUnit);
        addStat('Deepest Dive', '$depthValue ${depthUnit.symbol}');
      }

      final longestDive = dives.reduce(
        (a, b) =>
            (a.duration?.inMinutes ?? 0) > (b.duration?.inMinutes ?? 0) ? a : b,
      );
      if (longestDive.duration != null) {
        addStat('Longest Dive', '${longestDive.duration!.inMinutes} min');
      }

      final divesWithTemp = dives.where((d) => d.waterTemp != null).toList();
      if (divesWithTemp.isNotEmpty) {
        final coldestDive = divesWithTemp.reduce(
          (a, b) => a.waterTemp! < b.waterTemp! ? a : b,
        );
        final tempValue = convertTemperature(
          coldestDive.waterTemp,
          temperatureUnit,
        );
        addStat('Coldest Dive', '$tempValue ${temperatureUnit.symbol}');
      }
    }

    currentRow += 2;

    // Dives by Year
    if (dives.isNotEmpty) {
      addHeader('DIVES BY YEAR');
      currentRow++;

      final divesByYear = <int, List<Dive>>{};
      for (final dive in dives) {
        final year = dive.dateTime.year;
        divesByYear.putIfAbsent(year, () => []).add(dive);
      }

      final sortedYears = divesByYear.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final year in sortedYears) {
        final yearDives = divesByYear[year]!;
        final yearMinutes = yearDives.fold<int>(
          0,
          (sum, d) => sum + (d.duration?.inMinutes ?? 0),
        );
        final yearHours = yearMinutes ~/ 60;
        final yearMins = yearMinutes % 60;
        addStat(
          '$year',
          '${yearDives.length} dives (${yearHours}h ${yearMins}m)',
        );
      }

      currentRow += 2;
    }

    // Dives by Month (current year)
    if (dives.isNotEmpty) {
      final currentYear = DateTime.now().year;
      final currentYearDives = dives
          .where((d) => d.dateTime.year == currentYear)
          .toList();

      if (currentYearDives.isNotEmpty) {
        addHeader('DIVES BY MONTH ($currentYear)');
        currentRow++;

        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];

        for (var month = 1; month <= 12; month++) {
          final monthDives = currentYearDives
              .where((d) => d.dateTime.month == month)
              .length;
          if (monthDives > 0) {
            addStat(months[month - 1], monthDives);
          }
        }

        currentRow += 2;
      }
    }

    // Gas Usage
    if (dives.isNotEmpty) {
      addHeader('GAS USAGE');
      currentRow++;

      var airCount = 0;
      var eanCount = 0;
      var trimixCount = 0;
      var ccrCount = 0;
      var scrCount = 0;

      for (final dive in dives) {
        if (dive.diveMode == DiveMode.ccr) {
          ccrCount++;
        } else if (dive.diveMode == DiveMode.scr) {
          scrCount++;
        } else if (dive.tanks.isNotEmpty) {
          final primaryTank = dive.tanks.first;
          if (primaryTank.gasMix.he > 0) {
            trimixCount++;
          } else if (primaryTank.gasMix.o2 > 22) {
            eanCount++;
          } else {
            airCount++;
          }
        } else {
          airCount++;
        }
      }

      addStat('Air Dives', airCount);
      addStat('Nitrox (EANx) Dives', eanCount);
      addStat('Trimix Dives', trimixCount);
      addStat('CCR Dives', ccrCount);
      addStat('SCR Dives', scrCount);

      currentRow += 2;
    }

    // Special Dive Types
    if (dives.isNotEmpty) {
      addHeader('SPECIAL DIVES');
      currentRow++;

      final nightDives = dives
          .where((d) => d.diveTypeName.toLowerCase().contains('night'))
          .length;
      final deepDives = dives.where((d) => (d.maxDepth ?? 0) > 30).length;
      final coldDives = dives.where((d) => (d.waterTemp ?? 100) < 10).length;
      final driftDives = dives
          .where((d) => d.diveTypeName.toLowerCase().contains('drift'))
          .length;
      final wrecks = dives
          .where((d) => d.diveTypeName.toLowerCase().contains('wreck'))
          .length;

      addStat('Night Dives', nightDives);
      addStat('Deep Dives (>30m)', deepDives);
      addStat('Cold Water Dives (<10\u00B0C)', coldDives);
      addStat('Drift Dives', driftDives);
      addStat('Wreck Dives', wrecks);

      currentRow += 2;
    }

    // Top 5 Sites
    if (dives.isNotEmpty) {
      addHeader('TOP 5 MOST-VISITED SITES');
      currentRow++;

      final siteCounts = <String, int>{};
      for (final dive in dives) {
        final siteName = dive.site?.name ?? 'Unknown';
        siteCounts[siteName] = (siteCounts[siteName] ?? 0) + 1;
      }

      final sortedSites = siteCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var i = 0; i < sortedSites.length && i < 5; i++) {
        addStat(sortedSites[i].key, '${sortedSites[i].value} dives');
      }

      currentRow += 2;
    }

    // Equipment Usage
    if (dives.isNotEmpty && equipment.isNotEmpty) {
      addHeader('EQUIPMENT USAGE');
      currentRow++;

      final equipmentCounts = <String, int>{};
      for (final dive in dives) {
        for (final item in dive.equipment) {
          equipmentCounts[item.name] = (equipmentCounts[item.name] ?? 0) + 1;
        }
      }

      if (equipmentCounts.isNotEmpty) {
        final sortedEquipment = equipmentCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (var i = 0; i < sortedEquipment.length && i < 10; i++) {
          addStat(sortedEquipment[i].key, '${sortedEquipment[i].value} dives');
        }
      } else {
        addStat('No equipment logged on dives', '');
      }
    }
  }

  // ==================== Helpers ====================

  xl.CellValue _toCellValue(dynamic value) {
    if (value == null || value == '') {
      return xl.TextCellValue('');
    } else if (value is int) {
      return xl.IntCellValue(value);
    } else if (value is double) {
      return xl.DoubleCellValue(value);
    } else {
      return xl.TextCellValue(value.toString());
    }
  }
}
