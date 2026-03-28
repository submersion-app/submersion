import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  late KmlExportService service;

  setUp(() {
    service = KmlExportService();
  });

  group('generateKmlContent', () {
    test('includes bottomTime in dive descriptions', () async {
      const site = DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        description: 'Amazing dive site',
        location: GeoPoint(17.3, -87.5),
        country: 'Belize',
        notes: '',
        photoIds: [],
      );

      final dives = [
        Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
          site: site,
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      final (kmlContent, skipped) = await service.generateKmlContent(
        sites: [site],
        dives: dives,
        depthUnit: DepthUnit.meters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      expect(kmlContent, contains('45min'));
      expect(kmlContent, contains('Blue Hole'));
      expect(skipped, 0);
    });

    test('handles dives with null bottomTime', () async {
      const site = DiveSite(
        id: 'site-1',
        name: 'Reef',
        description: '',
        location: GeoPoint(10.0, -80.0),
        notes: '',
        photoIds: [],
      );

      final dives = [
        Dive(
          id: 'dive-1',
          dateTime: DateTime(2026, 3, 28, 10, 0),
          maxDepth: 20.0,
          site: site,
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      final (kmlContent, _) = await service.generateKmlContent(
        sites: [site],
        dives: dives,
        depthUnit: DepthUnit.meters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      // Null bottomTime should show '?'
      expect(kmlContent, contains('?'));
    });
  });
}
