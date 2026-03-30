import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';

void main() {
  late PresetRegistry registry;

  setUp(() {
    registry = PresetRegistry(builtInPresets: builtInCsvPresets);
  });

  // ======================== detectPreset ========================

  group('detectPreset', () {
    test(
      'detects Subsurface from real headers (25 headers from actual file)',
      () {
        const subsurfaceHeaders = [
          'dive number',
          'date',
          'time',
          'duration [min]',
          'sac [l/min]',
          'maxdepth [m]',
          'avgdepth [m]',
          'mode',
          'airtemp [C]',
          'watertemp [C]',
          'cylinder size (1) [l]',
          'startpressure (1) [bar]',
          'endpressure (1) [bar]',
          'o2 (1) [%]',
          'he (1) [%]',
          'location',
          'gps',
          'divemaster',
          'buddy',
          'suit',
          'rating',
          'visibility',
          'notes',
          'weight [kg]',
          'tags',
        ];

        final matches = registry.detectPreset(subsurfaceHeaders);

        expect(matches, isNotEmpty);
        expect(matches.first.preset.id, 'subsurface');
        expect(matches.first.score, greaterThan(0.9));
      },
    );

    test('detects MacDive from its headers', () {
      const macdiveHeaders = [
        'Dive No',
        'Date',
        'Time',
        'Location',
        'Max. Depth',
        'Avg. Depth',
        'Bottom Time',
        'Water Temp',
        'Air Temp',
        'Visibility',
        'Dive Type',
        'Rating',
        'Notes',
        'Buddy',
        'Dive Master',
      ];

      final matches = registry.detectPreset(macdiveHeaders);

      expect(matches, isNotEmpty);
      expect(matches.first.preset.id, 'macdive');
      expect(matches.first.score, closeTo(1.0, 0.001));
    });

    test('returns empty for unrecognized headers', () {
      const unknownHeaders = [
        'foo',
        'bar',
        'baz',
        'completely_unrelated',
        'nonsense_column',
      ];

      final matches = registry.detectPreset(unknownHeaders);

      expect(matches, isEmpty);
    });

    test('ranks matches by score descending', () {
      // Add two user presets that will both match the same headers, but at
      // different scores, to verify ranking is descending.
      registry.addUserPreset(
        const CsvPreset(
          id: 'rank-high',
          name: 'Rank High',
          source: PresetSource.userSaved,
          signatureHeaders: ['alpha', 'beta', 'gamma'],
          matchThreshold: 0.5,
          mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
        ),
      );
      registry.addUserPreset(
        const CsvPreset(
          id: 'rank-low',
          name: 'Rank Low',
          source: PresetSource.userSaved,
          signatureHeaders: ['alpha', 'beta', 'gamma', 'delta', 'epsilon'],
          matchThreshold: 0.4,
          mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
        ),
      );

      // 3/3 for rank-high (1.0), 3/5 for rank-low (0.6)
      const headers = ['alpha', 'beta', 'gamma'];

      final matches = registry.detectPreset(headers);

      // Both user presets should appear, rank-high first
      final highIdx = matches.indexWhere((m) => m.preset.id == 'rank-high');
      final lowIdx = matches.indexWhere((m) => m.preset.id == 'rank-low');
      expect(highIdx, isNot(-1));
      expect(lowIdx, isNot(-1));
      expect(highIdx, lessThan(lowIdx));

      // Verify full list is sorted descending
      for (var i = 0; i < matches.length - 1; i++) {
        expect(
          matches[i].score,
          greaterThanOrEqualTo(matches[i + 1].score),
          reason:
              'Match at index $i should have score >= match at index ${i + 1}',
        );
      }
    });

    test('includes user presets in detection', () {
      const customPreset = CsvPreset(
        id: 'custom-app',
        name: 'Custom App',
        source: PresetSource.userSaved,
        signatureHeaders: [
          'custom_date',
          'custom_depth',
          'custom_duration',
          'custom_site',
        ],
        matchThreshold: 0.5,
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );
      registry.addUserPreset(customPreset);

      final matches = registry.detectPreset([
        'custom_date',
        'custom_depth',
        'custom_duration',
        'custom_site',
      ]);

      expect(matches, isNotEmpty);
      expect(matches.any((m) => m.preset.id == 'custom-app'), isTrue);
    });

    test(
      'match result contains correct matchedHeaders and totalSignatureHeaders',
      () {
        const macdiveHeaders = [
          'Dive No',
          'Date',
          'Time',
          'Location',
          'Max. Depth',
          'Avg. Depth',
          'Bottom Time',
          'Water Temp',
          'Air Temp',
          'Visibility',
          'Dive Type',
          'Rating',
          'Notes',
          'Buddy',
          'Dive Master',
        ];

        final matches = registry.detectPreset(macdiveHeaders);
        final macdiveMatch = matches.firstWhere(
          (m) => m.preset.id == 'macdive',
        );

        expect(macdiveMatch.matchedHeaders, 15);
        expect(macdiveMatch.totalSignatureHeaders, 15);
      },
    );

    test('detection is case-insensitive', () {
      // MacDive headers in uppercase - still should match
      final upperHeaders = [
        'DIVE NO',
        'DATE',
        'TIME',
        'LOCATION',
        'MAX. DEPTH',
        'AVG. DEPTH',
        'BOTTOM TIME',
        'WATER TEMP',
        'AIR TEMP',
        'VISIBILITY',
        'DIVE TYPE',
        'RATING',
        'NOTES',
        'BUDDY',
        'DIVE MASTER',
      ];

      final matches = registry.detectPreset(upperHeaders);

      expect(matches, isNotEmpty);
      expect(matches.first.preset.id, 'macdive');
    });
  });

  // ======================== getPreset ========================

  group('getPreset', () {
    test('returns built-in preset by ID', () {
      final preset = registry.getPreset('subsurface');

      expect(preset, isNotNull);
      expect(preset!.id, 'subsurface');
      expect(preset.name, 'Subsurface');
    });

    test('returns null for unknown ID', () {
      final preset = registry.getPreset('nonexistent-preset-id');

      expect(preset, isNull);
    });

    test('returns correct preset for each built-in ID', () {
      final ids = [
        'subsurface',
        'macdive',
        'diving_log',
        'divemate',
        'garmin_connect',
        'shearwater_cloud',
        'submersion_native',
      ];

      for (final id in ids) {
        final preset = registry.getPreset(id);
        expect(preset, isNotNull, reason: 'Preset $id not found');
        expect(preset!.id, id);
      }
    });
  });

  // ======================== user preset management ========================

  group('user preset management', () {
    test('adds and retrieves user preset', () {
      const userPreset = CsvPreset(
        id: 'my-custom-preset',
        name: 'My Custom Preset',
        source: PresetSource.userSaved,
        signatureHeaders: ['MyDate', 'MyDepth'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      registry.addUserPreset(userPreset);

      final retrieved = registry.getPreset('my-custom-preset');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'my-custom-preset');
      expect(retrieved.name, 'My Custom Preset');
    });

    test('removes user preset', () {
      const userPreset = CsvPreset(
        id: 'to-be-removed',
        name: 'To Be Removed',
        source: PresetSource.userSaved,
        signatureHeaders: ['RemoveMe'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      registry.addUserPreset(userPreset);
      expect(registry.getPreset('to-be-removed'), isNotNull);

      registry.removeUserPreset('to-be-removed');
      expect(registry.getPreset('to-be-removed'), isNull);
    });

    test('lists all presets - count increases after add', () {
      final countBefore = registry.allPresets.length;
      expect(countBefore, builtInCsvPresets.length);

      const userPreset = CsvPreset(
        id: 'extra-preset',
        name: 'Extra Preset',
        source: PresetSource.userSaved,
        signatureHeaders: ['ExtraHeader'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      registry.addUserPreset(userPreset);

      expect(registry.allPresets.length, countBefore + 1);
    });

    test('removing built-in preset ID has no effect', () {
      final countBefore = registry.allPresets.length;

      registry.removeUserPreset('subsurface');

      expect(registry.allPresets.length, countBefore);
      expect(registry.getPreset('subsurface'), isNotNull);
    });

    test('adding multiple user presets all appear in allPresets', () {
      for (var i = 0; i < 3; i++) {
        registry.addUserPreset(
          CsvPreset(
            id: 'user-preset-$i',
            name: 'User Preset $i',
            source: PresetSource.userSaved,
            signatureHeaders: ['Header$i'],
            mappings: const {
              'primary': FieldMapping(name: 'Primary', columns: []),
            },
          ),
        );
      }

      expect(registry.allPresets.length, builtInCsvPresets.length + 3);
      for (var i = 0; i < 3; i++) {
        expect(registry.getPreset('user-preset-$i'), isNotNull);
      }
    });
  });

  // ======================== identifyFileRole ========================

  group('identifyFileRole', () {
    test('identifies dive_list role for Subsurface dive list headers', () {
      final subsurface = registry.getPreset('subsurface')!;
      const headers = [
        'dive number',
        'maxdepth [m]',
        'sac [l/min]',
        'cylinder size (1) [l]',
        'date',
        'time',
      ];

      final role = registry.identifyFileRole(subsurface, headers);

      expect(role, isNotNull);
      expect(role!.roleId, 'dive_list');
    });

    test('identifies dive_profile role for Subsurface profile headers', () {
      final subsurface = registry.getPreset('subsurface')!;
      const headers = [
        'sample time (min)',
        'sample depth (m)',
        'sample temperature (C)',
        'dive number',
      ];

      final role = registry.identifyFileRole(subsurface, headers);

      expect(role, isNotNull);
      expect(role!.roleId, 'dive_profile');
    });

    test('returns null for preset with no file roles', () {
      final macdive = registry.getPreset('macdive')!;
      const headers = ['Dive No', 'Date', 'Max. Depth'];

      final role = registry.identifyFileRole(macdive, headers);

      expect(role, isNull);
    });

    test('returns null when no role matches above threshold', () {
      final subsurface = registry.getPreset('subsurface')!;
      const headers = ['completely', 'unrelated', 'headers'];

      final role = registry.identifyFileRole(subsurface, headers);

      expect(role, isNull);
    });
  });

  // ======================== allPresets ========================

  group('allPresets', () {
    test('returns all built-in presets initially', () {
      expect(registry.allPresets.length, builtInCsvPresets.length);
    });

    test('returns presets in built-in first, user second order', () {
      const userPreset = CsvPreset(
        id: 'user-last',
        name: 'User Last',
        source: PresetSource.userSaved,
        signatureHeaders: ['UserHeader'],
        mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
      );

      registry.addUserPreset(userPreset);

      final all = registry.allPresets;
      final userIndex = all.indexWhere((p) => p.id == 'user-last');
      expect(userIndex, all.length - 1);
    });

    test(
      'allPresets returns unmodifiable view (built-ins intact after user ops)',
      () {
        registry.addUserPreset(
          const CsvPreset(
            id: 'temp',
            name: 'Temp',
            source: PresetSource.userSaved,
            signatureHeaders: ['TempHeader'],
            mappings: {'primary': FieldMapping(name: 'Primary', columns: [])},
          ),
        );
        registry.removeUserPreset('temp');

        // Built-ins should all still be present
        for (final builtIn in builtInCsvPresets) {
          expect(registry.getPreset(builtIn.id), isNotNull);
        }
      },
    );
  });

  // ======================== PresetMatch fields ========================

  group('PresetMatch', () {
    test('PresetMatch equality is value-based', () {
      const match1 = PresetMatch(
        preset: CsvPreset(
          id: 'macdive',
          name: 'MacDive',
          signatureHeaders: [],
          mappings: {},
        ),
        score: 1.0,
        matchedHeaders: 15,
        totalSignatureHeaders: 15,
      );
      const match2 = PresetMatch(
        preset: CsvPreset(
          id: 'macdive',
          name: 'MacDive',
          signatureHeaders: [],
          mappings: {},
        ),
        score: 1.0,
        matchedHeaders: 15,
        totalSignatureHeaders: 15,
      );

      expect(match1, match2);
    });
  });
}
