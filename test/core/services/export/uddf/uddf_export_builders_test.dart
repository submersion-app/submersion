import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('UddfExportBuilders.buildDiveElement', () {
    test('generates synthetic profile from bottomTime when no profile', () {
      // Dive with bottomTime and maxDepth but NO profile data
      // This triggers the else branch at line 351
      final dive = Dive(
        id: 'dive-no-profile',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        bottomTime: const Duration(minutes: 45),
        maxDepth: 25.0,
        avgDepth: 18.0,
        waterTemp: 22.0,
        tanks: const [],
        profile: const [], // Empty profile!
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );

      final builder = XmlBuilder();
      builder.element(
        'root',
        nest: () {
          UddfExportBuilders.buildDiveElement(
            builder,
            dive,
            null, // buddies
            const [], // diveBuddyList
            const [], // diveTags
            const [], // profileEvents
            const [], // diveWeights
            null, // trips
            const [], // gasSwitches
          );
        },
      );

      final xml = builder.buildDocument().toXmlString();

      // Should contain synthesized waypoints from bottomTime
      expect(xml, contains('waypoint'));
      expect(xml, contains('divetime'));
      expect(xml, contains('depth'));
    });
  });
}
