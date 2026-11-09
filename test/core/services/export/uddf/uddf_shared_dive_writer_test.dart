import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_shared_dive_writer.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// The dives-only export's `<dive>` element, moved into its own writer by
/// issue #4249 so the streamed export can build one dive at a time. These
/// pin the optional values it writes.
void main() {
  final dive = Dive(
    id: 'dive-a',
    diveNumber: 12,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    airTemp: 24,
    surfacePressure: 1.013,
    surfaceInterval: const Duration(minutes: 75),
    diveCenter: DiveCenter(
      id: 'center-1',
      name: 'Reef Divers',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    waterTemp: 21,
    rating: 4,
    waterType: WaterType.salt,
    currentDirection: CurrentDirection.north,
    currentStrength: CurrentStrength.light,
    swellHeight: 0.5,
    exitMethod: EntryMethod.boat,
    weightAmount: 6,
    weightType: WeightType.belt,
    sightings: const [
      MarineSighting(
        id: 'sighting-1',
        speciesId: 'turtle',
        speciesName: 'Green turtle',
        abundance: SightingAbundance.exact,
        count: 2,
        notes: 'Resting under the ledge',
      ),
    ],
    notes: 'Slack tide',
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 1, temperature: 22, gf99: 10),
      DiveProfilePoint(timestamp: 60, depth: 12),
    ],
  );

  XmlElement write({
    UddfExportOptions options = const UddfExportOptions(),
    Map<String, List<TankPressurePoint>>? tankPressures,
    Dive? of,
  }) {
    final builder = XmlBuilder();
    UddfSharedDiveWriter.write(
      builder,
      of ?? dive,
      options: options,
      tankPressures: tankPressures,
    );
    return builder.buildFragment().children.whereType<XmlElement>().single;
  }

  String? textOf(XmlElement root, String name) =>
      root.findAllElements(name).firstOrNull?.innerText;

  test('writes the values recorded before the dive', () {
    final before = write().getElement('informationbeforedive')!;

    expect(textOf(before, 'divenumber'), '12');
    expect(double.parse(textOf(before, 'airtemperature')!), 297.15);
    expect(
      double.parse(textOf(before, 'atmosphericpressure')!),
      closeTo(101300, 1e-6),
    );
    expect(textOf(before, 'passedtime'), '4500');
    expect(
      before.findElements('link').map((l) => l.getAttribute('ref')),
      contains('center_center-1'),
    );
  });

  test('writes the values recorded after the dive', () {
    final after = write().getElement('informationafterdive')!;

    expect(double.parse(textOf(after, 'lowesttemperature')!), 294.15);
    expect(textOf(after, 'ratingvalue'), '4');
    expect(textOf(after, 'watertype'), 'salt');
    expect(textOf(after, 'currentdirection'), 'north');
    expect(textOf(after, 'currentstrength'), 'light');
    expect(textOf(after, 'swellheight'), '0.5');
    expect(textOf(after, 'exittype'), 'boat');
    expect(textOf(after.getElement('weightused')!, 'amount'), '6.0');
    expect(textOf(after.getElement('weightused')!, 'type'), 'belt');
    final sighting = after.findAllElements('sighting').single;
    expect(sighting.getAttribute('speciesref'), 'species_turtle');
    expect(sighting.getAttribute('count'), '2');
    expect(sighting.innerText, 'Resting under the ledge');
    expect(textOf(after.getElement('notes')!, 'para'), 'Slack tide');
  });

  test('writes a REEF group as abundance with no count (issue #4337)', () {
    final grouped = dive.copyWith(
      sightings: const [
        MarineSighting(
          id: 'sighting-2',
          speciesId: 'jack',
          speciesName: 'Bigeye trevally',
          abundance: SightingAbundance.abundant,
        ),
      ],
    );
    final sighting = write(
      of: grouped,
    ).getElement('informationafterdive')!.findAllElements('sighting').single;

    expect(sighting.getAttribute('abundance'), 'abundant');
    expect(sighting.getAttribute('count'), isNull);
  });

  test('writes each sample with its temperature, GF99 and tank pressure', () {
    final waypoints = write(
      tankPressures: {
        'tank-a': const [
          TankPressurePoint(tankId: 'tank-a', timestamp: 0, pressure: 200),
        ],
      },
    ).findAllElements('waypoint').toList();

    expect(waypoints, hasLength(2));
    expect(double.parse(textOf(waypoints.first, 'temperature')!), 295.15);
    expect(textOf(waypoints.first, 'gradientfactor'), '10');
    expect(
      waypoints.first.getElement('tankpressure')!.getAttribute('ref'),
      'tank_tank-a',
    );
    expect(waypoints.last.getElement('tankpressure'), isNull);
  });
}
