// file_picker 12's saveFile writes the bytes itself and returns a Uri, so
// every `save*ToFile` here now ends in `savedFileLocation(result)` instead of
// writing the file a second time. These pin that seam per service: the caller
// gets a usable location back, and the picker is told the real mime type
// (v12 accepts `allowedExtensions` but never forwards it, so a dropped
// mimeType would silently stop save dialogs filtering by type).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/core/services/export/excel/pre_dive_excel_export_service.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/mock_file_picker_platform.dart';

final _l10n = l10nForLocaleTag('en');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;
  late Directory workDir;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('save_location_test');
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  /// Points the picker at a real destination and returns that path.
  String chooses(String name) {
    final target = '${workDir.path}/$name';
    picker.saveFileResult = Uri.file(target);
    return target;
  }

  final dives = [
    Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime(2026, 1, 15, 9),
      runtime: const Duration(minutes: 44),
      maxDepth: 22.0,
    ),
  ];

  final sites = [const DiveSite(id: 's1', name: 'Blue Hole', description: '')];

  group('returns the chosen location and writes the file', () {
    test('dives CSV', () async {
      final target = chooses('dives.csv');

      expect(await CsvExportService().saveDivesCsvToFile(dives), target);
      expect(await File(target).readAsString(), isNotEmpty);
      expect(picker.lastSavedFileName, endsWith('.csv'));
    });

    test('sites CSV', () async {
      final target = chooses('sites.csv');
      expect(await CsvExportService().saveSitesCsvToFile(sites), target);
      expect(await File(target).exists(), isTrue);
    });

    test('equipment CSV', () async {
      final target = chooses('equipment.csv');
      expect(await CsvExportService().saveEquipmentCsvToFile(const []), target);
      expect(await File(target).exists(), isTrue);
    });

    test('UDDF', () async {
      final target = chooses('dives.uddf');
      expect(await UddfExportService().saveDivesToUddfFile(dives), target);
      expect(await File(target).readAsString(), contains('uddf'));
    });

    test('full UDDF', () async {
      final target = chooses('all.uddf');
      expect(
        await UddfFullExportService().saveAllDataToUddfFile(dives: dives),
        target,
      );
      expect(await File(target).exists(), isTrue);
    });

    test('KML, alongside the skipped-site count', () async {
      final target = chooses('sites.kml');

      final (path, skipped) = await KmlExportService().saveKmlToFile(
        sites: [
          const DiveSite(
            id: 's1',
            name: 'Blue Hole',
            description: '',
            location: GeoPoint(1.0, 2.0),
          ),
        ],
        dives: const [],
        depthUnit: DepthUnit.meters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      expect(path, target);
      expect(skipped, 0);
    });

    test('pre-dive checklist XLSX', () async {
      final target = chooses('checklists.xlsx');

      expect(
        await PreDiveExcelExportService().saveToFile(
          sessions: const [],
          itemsBySession: const {},
          dateFormat: DateFormatPreference.yyyymmdd,
        ),
        target,
      );
      expect(await File(target).exists(), isTrue);
    });

    test('workbook XLSX', () async {
      final target = chooses('logbook.xlsx');

      expect(
        await ExcelExportService().saveExcelToFile(
          dives: dives,
          sites: sites,
          equipment: const [],
          depthUnit: DepthUnit.meters,
          temperatureUnit: TemperatureUnit.celsius,
          pressureUnit: PressureUnit.bar,
          volumeUnit: VolumeUnit.liters,
          dateFormat: DateFormatPreference.yyyymmdd,
        ),
        target,
      );
      expect(await File(target).exists(), isTrue);
    });

    test('profile image PNG', () async {
      final target = chooses('profile.png');
      final png = [0x89, 0x50, 0x4E, 0x47];

      expect(await saveImageToFile(png, 'profile.png'), target);
      expect(await File(target).readAsBytes(), png);
    });

    test('PDF bytes', () async {
      final target = chooses('logbook.pdf');
      final pdf = '%PDF-1.4'.codeUnits;

      expect(await savePdfToFile(pdf, 'logbook.pdf'), target);
      expect(await File(target).readAsBytes(), pdf);
    });

    test('debug log file', () async {
      final source = File('${workDir.path}/submersion.log');
      await source.writeAsString('boot\nsync ok\n');
      final target = chooses('submersion-debug-logs.txt');

      expect(
        await saveLogFile(_FixedLogFileService(source.path), _l10n),
        target,
      );
      expect(await File(target).readAsString(), contains('sync ok'));
    });

    test('a missing debug log file never opens the dialog', () async {
      picker.saveFileResult = Uri.file('${workDir.path}/unused.txt');

      expect(
        await saveLogFile(
          _FixedLogFileService('${workDir.path}/absent.log'),
          _l10n,
        ),
        isNull,
      );
      expect(picker.lastSavedFileName, isNull);
    });
  });

  group('a cancelled dialog returns null and writes nothing', () {
    test('across every service', () async {
      picker.saveFileResult = null;

      expect(await CsvExportService().saveDivesCsvToFile(dives), isNull);
      expect(await UddfExportService().saveDivesToUddfFile(dives), isNull);
      expect(
        await UddfFullExportService().saveAllDataToUddfFile(dives: dives),
        isNull,
      );
      expect(
        await PreDiveExcelExportService().saveToFile(
          sessions: const [],
          itemsBySession: const {},
          dateFormat: DateFormatPreference.yyyymmdd,
        ),
        isNull,
      );
      expect(workDir.listSync(), isEmpty);
    });
  });

  test('an Android content Uri is surfaced as the Uri, not a path', () async {
    // SAF saves come back as content://; `savedFileLocation` must not try to
    // turn those into a filesystem path.
    picker.saveFileResult = Uri.parse('content://downloads/doc/77');

    expect(
      await CsvExportService().saveDivesCsvToFile(dives),
      'content://downloads/doc/77',
    );
  });
}

/// Points [saveLogFile] at a log we control, without running the real
/// service's initialize()/rotation machinery.
class _FixedLogFileService extends LogFileService {
  _FixedLogFileService(this._path) : super(logDirectory: '/unused');

  final String _path;

  @override
  String get logFilePath => _path;
}
