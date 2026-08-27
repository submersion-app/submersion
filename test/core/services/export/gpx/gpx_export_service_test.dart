import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/gpx/gpx_export_service.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

GpsTrack _track() {
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: startSec * 1000,
    endTime: (startSec + 60) * 1000,
    pointCount: 2,
    points: [
      GpsTrackPoint(timestamp: startSec, latitude: 20.5, longitude: -87.25),
      GpsTrackPoint(
        timestamp: startSec + 60,
        latitude: 20.51,
        longitude: -87.26,
      ),
    ],
  );
}

void main() {
  late MockFilePickerPlatform mockPicker;
  late FilePickerPlatform originalPicker;
  late Directory tempDir;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    mockPicker = MockFilePickerPlatform();
    FilePickerPlatform.instance = mockPicker;
    tempDir = Directory.systemTemp.createTempSync('gpx_export_test');
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('GpxExportService', () {
    late GpxExportService service;
    setUp(() => service = GpxExportService());

    test('names the file from the track date in wall-clock UTC', () {
      expect(service.fileNameFor(_track()), 'submersion_track_2026-05-22.gpx');
    });

    test('saveTrackToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await service.saveTrackToFile(_track()), isNull);
    });

    test('saveTrackToFile writes GPX to the chosen path', () async {
      final target = '${tempDir.path}/track.gpx';
      mockPicker.saveFileResult = Uri.file(target);

      final result = await service.saveTrackToFile(_track());

      expect(result, target);
      final written = File(target).readAsStringSync();
      expect(written, contains('<gpx'));
      expect('<trkpt'.allMatches(written).length, 2);
    });
  });

  group('KmlExportService track save', () {
    late KmlExportService service;
    setUp(() => service = KmlExportService());

    test('saveTrackKmlToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await service.saveTrackKmlToFile(_track()), isNull);
    });

    test('saveTrackKmlToFile writes a gx:Track to the chosen path', () async {
      final target = '${tempDir.path}/track.kml';
      mockPicker.saveFileResult = Uri.file(target);

      final result = await service.saveTrackKmlToFile(_track());

      expect(result, target);
      final written = File(target).readAsStringSync();
      expect(written, contains('<gx:Track>'));
      expect('<gx:coord>'.allMatches(written).length, 2);
    });
  });
}
