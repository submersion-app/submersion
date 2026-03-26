import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

void main() {
  group('IncomingDiveData constructor', () {
    test('default values for optional fields', () {
      const data = IncomingDiveData();

      expect(data.startTime, isNull);
      expect(data.maxDepth, isNull);
      expect(data.avgDepth, isNull);
      expect(data.durationSeconds, isNull);
      expect(data.waterTemp, isNull);
      expect(data.computerName, isNull);
      expect(data.computerModel, isNull);
      expect(data.computerSerial, isNull);
      expect(data.profile, isEmpty);
      expect(data.siteName, isNull);
    });

    test('stores all provided values', () {
      final data = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 30.0,
        avgDepth: 15.5,
        durationSeconds: 3600,
        waterTemp: 24.0,
        computerName: 'My Computer',
        computerModel: 'Teric',
        computerSerial: 'ABC123',
        siteName: 'Blue Hole',
      );

      expect(data.startTime, DateTime(2026, 3, 19, 10, 0));
      expect(data.maxDepth, 30.0);
      expect(data.avgDepth, 15.5);
      expect(data.durationSeconds, 3600);
      expect(data.waterTemp, 24.0);
      expect(data.computerName, 'My Computer');
      expect(data.computerModel, 'Teric');
      expect(data.computerSerial, 'ABC123');
      expect(data.siteName, 'Blue Hole');
    });
  });

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

      expect(result.computerName, isNull);
      expect(result.computerModel, isNull);
      expect(result.computerSerial, isNull);
      expect(result.profile, isEmpty);
    });

    test('maps computerName from DiveComputer.displayName', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19),
        durationSeconds: 60,
        maxDepth: 5.0,
        profile: const [],
      );
      final computer = DiveComputer(
        id: 'c1',
        name: 'My Perdix',
        model: 'Perdix 2',
        manufacturer: 'Shearwater',
        serialNumber: 'SN999',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = IncomingDiveData.fromDownloadedDive(
        dive,
        computer: computer,
      );

      // displayName returns name when non-empty
      expect(result.computerName, 'My Perdix');
      expect(result.computerModel, 'Shearwater Perdix 2');
      expect(result.computerSerial, 'SN999');
    });

    test('handles minimal DownloadedDive with null optional fields', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 1, 1),
        durationSeconds: 300,
        maxDepth: 3.0,
        // avgDepth: null (default)
        // minTemperature: null (default)
        profile: const [],
      );

      final result = IncomingDiveData.fromDownloadedDive(dive);

      expect(result.startTime, DateTime(2026, 1, 1));
      expect(result.maxDepth, 3.0);
      expect(result.avgDepth, isNull);
      expect(result.durationSeconds, 300);
      expect(result.waterTemp, isNull);
    });

    test('profile samples are correctly converted to DiveProfilePoints', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19),
        durationSeconds: 180,
        maxDepth: 20.0,
        profile: const [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 60, depth: 10.0),
          ProfileSample(timeSeconds: 120, depth: 20.0),
          ProfileSample(timeSeconds: 180, depth: 0.0),
        ],
      );

      final result = IncomingDiveData.fromDownloadedDive(dive);

      expect(result.profile, hasLength(4));
      expect(result.profile[0].timestamp, 0);
      expect(result.profile[0].depth, 0.0);
      expect(result.profile[2].timestamp, 120);
      expect(result.profile[2].depth, 20.0);
    });

    test('siteName is not set from DownloadedDive', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19),
        durationSeconds: 60,
        maxDepth: 5.0,
        profile: const [],
      );

      final result = IncomingDiveData.fromDownloadedDive(dive);

      expect(result.siteName, isNull);
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

    // --- Additional coverage ---

    test('prefers runtime over duration when both are present', () {
      final data = <String, dynamic>{
        'runtime': const Duration(minutes: 50),
        'duration': const Duration(minutes: 40),
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.durationSeconds, 50 * 60);
    });

    test(
      'durationSeconds is null when both runtime and duration are missing',
      () {
        final data = <String, dynamic>{
          'dateTime': DateTime(2026, 3, 19),
          'maxDepth': 5.0,
        };

        final result = IncomingDiveData.fromImportMap(data);

        expect(result.durationSeconds, isNull);
      },
    );

    test('handles completely empty map', () {
      final data = <String, dynamic>{};

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.startTime, isNull);
      expect(result.maxDepth, isNull);
      expect(result.avgDepth, isNull);
      expect(result.durationSeconds, isNull);
      expect(result.waterTemp, isNull);
      expect(result.computerModel, isNull);
      expect(result.computerSerial, isNull);
      expect(result.siteName, isNull);
      expect(result.profile, isEmpty);
    });

    test('handles integer num values for depth fields', () {
      final data = <String, dynamic>{
        'maxDepth': 15, // int, not double
        'avgDepth': 10, // int, not double
        'waterTemp': 24, // int, not double
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.maxDepth, 15.0);
      expect(result.avgDepth, 10.0);
      expect(result.waterTemp, 24.0);
    });

    test('profile with integer depth values converts correctly', () {
      final data = <String, dynamic>{
        'profile': [
          {'timestamp': 0, 'depth': 0},
          {'timestamp': 60, 'depth': 15}, // int depth
          {'timestamp': 120, 'depth': 0},
        ],
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.profile, hasLength(3));
      expect(result.profile[1].depth, 15.0);
      expect(result.profile[1].depth, isA<double>());
    });

    test('null profile key results in empty profile list', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'profile': null,
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.profile, isEmpty);
    });

    test('computerName is not set by fromImportMap', () {
      final data = <String, dynamic>{
        'diveComputerModel': 'Teric',
        'diveComputerSerial': '12345',
      };

      final result = IncomingDiveData.fromImportMap(data);

      // fromImportMap does not populate computerName
      expect(result.computerName, isNull);
      expect(result.computerModel, 'Teric');
      expect(result.computerSerial, '12345');
    });

    test('startTime maps from dateTime key', () {
      final dt = DateTime(2026, 6, 15, 14, 30);
      final data = <String, dynamic>{'dateTime': dt};

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.startTime, dt);
    });
  });
}
