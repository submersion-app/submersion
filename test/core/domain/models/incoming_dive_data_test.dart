import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

void main() {
  group('IncomingDiveData.fromDownloadedDive', () {
    test('maps all fields from DownloadedDive and DiveComputer', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19, 22, 23),
        durationSeconds: 60,
        maxDepth: 2.2,
        avgDepth: 1.5,
        minTemperature: 26.0,
        profile: [
          const ProfileSample(timeSeconds: 0, depth: 0.0),
          const ProfileSample(timeSeconds: 30, depth: 2.2),
          const ProfileSample(timeSeconds: 60, depth: 0.0),
        ],
      );
      final computer = DiveComputer(
        id: 'c1',
        name: 'Eric',
        model: 'Teric',
        manufacturer: 'Shearwater',
        serialNumber: '2354046563',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = IncomingDiveData.fromDownloadedDive(
        dive,
        computer: computer,
      );

      expect(result.startTime, DateTime(2026, 3, 19, 22, 23));
      expect(result.maxDepth, 2.2);
      expect(result.avgDepth, 1.5);
      expect(result.durationSeconds, 60);
      expect(result.waterTemp, 26.0);
      expect(result.computerModel, 'Shearwater Teric');
      expect(result.computerSerial, '2354046563');
      expect(result.profile, hasLength(3));
      expect(result.profile[1].timestamp, 30);
      expect(result.profile[1].depth, 2.2);
    });

    test('handles null computer gracefully', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19),
        durationSeconds: 120,
        maxDepth: 10.0,
        profile: const [],
      );

      final result = IncomingDiveData.fromDownloadedDive(dive);

      expect(result.computerModel, isNull);
      expect(result.computerSerial, isNull);
      expect(result.profile, isEmpty);
    });
  });

  group('IncomingDiveData.fromImportMap', () {
    test('maps all fields from import map', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19, 22, 23),
        'maxDepth': 15.5,
        'avgDepth': 10.2,
        'runtime': const Duration(minutes: 45),
        'duration': const Duration(minutes: 42),
        'waterTemp': 24.0,
        'diveComputerModel': 'Teric',
        'diveComputerSerial': '12345',
        'siteName': 'Blue Hole',
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.startTime, DateTime(2026, 3, 19, 22, 23));
      expect(result.maxDepth, 15.5);
      expect(result.avgDepth, 10.2);
      expect(result.durationSeconds, 45 * 60); // prefers runtime
      expect(result.waterTemp, 24.0);
      expect(result.computerModel, 'Teric');
      expect(result.computerSerial, '12345');
      expect(result.siteName, 'Blue Hole');
    });

    test('falls back to duration when runtime is null', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'maxDepth': 10.0,
        'duration': const Duration(minutes: 30),
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.durationSeconds, 30 * 60);
    });

    test('converts profile map list to DiveProfilePoint', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'maxDepth': 10.0,
        'profile': [
          {'timestamp': 0, 'depth': 0.0},
          {'timestamp': 60, 'depth': 10.0},
        ],
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.profile, hasLength(2));
      expect(result.profile[0].timestamp, 0);
      expect(result.profile[1].depth, 10.0);
    });

    test('handles missing optional fields', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'maxDepth': 5.0,
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.avgDepth, isNull);
      expect(result.waterTemp, isNull);
      expect(result.computerModel, isNull);
      expect(result.computerSerial, isNull);
      expect(result.siteName, isNull);
      expect(result.profile, isEmpty);
    });
  });
}
