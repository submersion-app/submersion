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

    group('tank pressure export', () {
      test('writes tankpressure elements when tankPressures provided', () {
        final dive = Dive(
          id: 'dive-tp',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 20.0,
          tanks: const [DiveTank(id: 'tank-1')],
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 0.0),
            DiveProfilePoint(timestamp: 60, depth: 10.0),
            DiveProfilePoint(timestamp: 120, depth: 20.0),
          ],
        );

        final tankPressures = {
          'tank-1': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-1',
              timestamp: 0,
              pressure: 200.0,
            ),
            const TankPressurePoint(
              id: 'tp2',
              tankId: 'tank-1',
              timestamp: 60,
              pressure: 190.0,
            ),
            const TankPressurePoint(
              id: 'tp3',
              tankId: 'tank-1',
              timestamp: 120,
              pressure: 180.0,
            ),
          ],
        };

        final builder = XmlBuilder();
        builder.element(
          'root',
          nest: () {
            UddfExportBuilders.buildDiveElement(
              builder,
              dive,
              null,
              const [],
              const [],
              const [],
              const [],
              null,
              const [],
              tankPressures: tankPressures,
            );
          },
        );

        final doc = builder.buildDocument();
        final xml = doc.toXmlString();

        // Should contain tankpressure elements
        expect(xml, contains('tankpressure'));

        // Verify pressure values are converted to Pascals (bar * 100000)
        // 200.0 bar -> 20000000.0 Pa
        expect(xml, contains('20000000.0'));
        // 190.0 bar -> 19000000.0 Pa
        expect(xml, contains('19000000.0'));
        // 180.0 bar -> 18000000.0 Pa
        expect(xml, contains('18000000.0'));
      });

      test('matches pressure within 2-second tolerance window', () {
        // Profile point at t=60, pressure point at t=61 (within 3-second
        // threshold: diff must be < 3, so diff of 1 matches)
        final dive = Dive(
          id: 'dive-tp-tol',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 20.0,
          tanks: const [DiveTank(id: 'tank-1')],
          profile: const [DiveProfilePoint(timestamp: 60, depth: 15.0)],
        );

        final tankPressures = {
          'tank-1': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-1',
              timestamp: 61, // 1 second off - should match
              pressure: 195.0,
            ),
          ],
        };

        final builder = XmlBuilder();
        builder.element(
          'root',
          nest: () {
            UddfExportBuilders.buildDiveElement(
              builder,
              dive,
              null,
              const [],
              const [],
              const [],
              const [],
              null,
              const [],
              tankPressures: tankPressures,
            );
          },
        );

        final xml = builder.buildDocument().toXmlString();

        // 195.0 bar -> 19500000.0 Pa
        expect(xml, contains('19500000.0'));
      });

      test('does not match pressure beyond tolerance window', () {
        // Profile point at t=60, pressure point at t=65 (diff=5, >= 3
        // threshold so no match)
        final dive = Dive(
          id: 'dive-tp-no-match',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 20.0,
          tanks: const [DiveTank(id: 'tank-1')],
          profile: const [DiveProfilePoint(timestamp: 60, depth: 15.0)],
        );

        final tankPressures = {
          'tank-1': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-1',
              timestamp: 65, // 5 seconds off - should NOT match
              pressure: 195.0,
            ),
          ],
        };

        final builder = XmlBuilder();
        builder.element(
          'root',
          nest: () {
            UddfExportBuilders.buildDiveElement(
              builder,
              dive,
              null,
              const [],
              const [],
              const [],
              const [],
              null,
              const [],
              tankPressures: tankPressures,
            );
          },
        );

        final xml = builder.buildDocument().toXmlString();

        // Should NOT contain tankpressure because no match found
        expect(xml, isNot(contains('tankpressure')));
      });

      test('handles empty pressure list for a tank', () {
        final dive = Dive(
          id: 'dive-tp-empty',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 20.0,
          tanks: const [DiveTank(id: 'tank-1')],
          profile: const [DiveProfilePoint(timestamp: 60, depth: 15.0)],
        );

        final tankPressures = <String, List<TankPressurePoint>>{'tank-1': []};

        final builder = XmlBuilder();
        builder.element(
          'root',
          nest: () {
            UddfExportBuilders.buildDiveElement(
              builder,
              dive,
              null,
              const [],
              const [],
              const [],
              const [],
              null,
              const [],
              tankPressures: tankPressures,
            );
          },
        );

        final xml = builder.buildDocument().toXmlString();

        // Empty pressure list returns null, so no tankpressure element
        expect(xml, isNot(contains('tankpressure')));
      });

      test(
        'selects closest pressure point when multiple are within window',
        () {
          // Profile point at t=60, two pressure points at t=59 (diff=1) and
          // t=61 (diff=1). The first one encountered with smallest diff wins;
          // since both have diff=1, the first in iteration order is kept.
          final dive = Dive(
            id: 'dive-tp-closest',
            diveNumber: 1,
            dateTime: DateTime(2026, 3, 28, 10, 0),
            bottomTime: const Duration(minutes: 30),
            maxDepth: 20.0,
            tanks: const [DiveTank(id: 'tank-1')],
            profile: const [DiveProfilePoint(timestamp: 60, depth: 15.0)],
          );

          // Point at t=61 (diff=1) should match, point at t=58 (diff=2) also
          // within window but further. The closer one (t=61) should be used.
          final tankPressures = {
            'tank-1': [
              const TankPressurePoint(
                id: 'tp1',
                tankId: 'tank-1',
                timestamp: 58, // diff=2
                pressure: 190.0,
              ),
              const TankPressurePoint(
                id: 'tp2',
                tankId: 'tank-1',
                timestamp: 61, // diff=1 - closer
                pressure: 188.0,
              ),
            ],
          };

          final builder = XmlBuilder();
          builder.element(
            'root',
            nest: () {
              UddfExportBuilders.buildDiveElement(
                builder,
                dive,
                null,
                const [],
                const [],
                const [],
                const [],
                null,
                const [],
                tankPressures: tankPressures,
              );
            },
          );

          final xml = builder.buildDocument().toXmlString();

          // 188.0 bar (closest point) -> 18800000.0 Pa
          expect(xml, contains('18800000.0'));
          // 190.0 bar should NOT be present as it was further away
          expect(xml, isNot(contains('19000000.0')));
        },
      );

      test('handles multiple tanks with pressure data', () {
        final dive = Dive(
          id: 'dive-tp-multi',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 20.0,
          tanks: const [
            DiveTank(id: 'tank-1'),
            DiveTank(id: 'tank-2'),
          ],
          profile: const [DiveProfilePoint(timestamp: 60, depth: 15.0)],
        );

        final tankPressures = {
          'tank-1': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-1',
              timestamp: 60,
              pressure: 200.0,
            ),
          ],
          'tank-2': [
            const TankPressurePoint(
              id: 'tp2',
              tankId: 'tank-2',
              timestamp: 60,
              pressure: 150.0,
            ),
          ],
        };

        final builder = XmlBuilder();
        builder.element(
          'root',
          nest: () {
            UddfExportBuilders.buildDiveElement(
              builder,
              dive,
              null,
              const [],
              const [],
              const [],
              const [],
              null,
              const [],
              tankPressures: tankPressures,
            );
          },
        );

        final xml = builder.buildDocument().toXmlString();

        // Both tanks should have pressure values written
        // 200.0 bar -> 20000000.0 Pa
        expect(xml, contains('20000000.0'));
        // 150.0 bar -> 15000000.0 Pa
        expect(xml, contains('15000000.0'));
      });

      test('no tankpressure elements when tankPressures is null', () {
        final dive = Dive(
          id: 'dive-tp-null',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 20.0,
          tanks: const [DiveTank(id: 'tank-1')],
          profile: const [DiveProfilePoint(timestamp: 60, depth: 15.0)],
        );

        final builder = XmlBuilder();
        builder.element(
          'root',
          nest: () {
            UddfExportBuilders.buildDiveElement(
              builder,
              dive,
              null,
              const [],
              const [],
              const [],
              const [],
              null,
              const [],
              // tankPressures not passed, defaults to null
            );
          },
        );

        final xml = builder.buildDocument().toXmlString();

        expect(xml, isNot(contains('tankpressure')));
      });
    });
  });
}
