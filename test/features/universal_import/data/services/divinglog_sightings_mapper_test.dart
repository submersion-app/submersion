import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_sightings_mapper.dart';

DivingLogLogbook logbook({
  Map<int, DivingLogRawSpecies> species = const {},
  Map<int, List<int>> links = const {},
  Map<int, List<DivingLogRawPicture>> pictures = const {},
}) => DivingLogLogbook(
  dives: const [DivingLogRawDive(id: 1)],
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  speciesById: species,
  speciesIdsByLogId: links,
  picturesByLogId: pictures,
);

void main() {
  group('sightings', () {
    test('builds a speciesRef the importer can read back as a name', () {
      final book = logbook(
        species: {
          99: const DivingLogRawSpecies(
            id: 99,
            commonName: 'Giant Manta Ray',
            scientificName: 'Mobula birostris',
          ),
        },
        links: {
          1: [99],
        },
      );
      final sightings = DivingLogSightingsMapper.sightingsFor(
        book,
        book.dives.single,
      );
      expect(sightings, hasLength(1));
      // UddfEntityImporter._speciesNameFromRef strips `species_`, splits on
      // underscores and title cases, so this round trips to the name.
      expect(sightings.single['speciesRef'], 'species_giant_manta_ray');
      // The importer creates the species row from these, so the original
      // spelling has to travel rather than be derived back out of the ref.
      expect(sightings.single['speciesName'], 'Giant Manta Ray');
      expect(sightings.single['speciesScientificName'], 'Mobula birostris');
    });

    test('skips a link whose species row is missing', () {
      final book = logbook(
        links: {
          1: [99],
        },
      );
      expect(
        DivingLogSightingsMapper.sightingsFor(book, book.dives.single),
        isEmpty,
      );
    });

    test('skips a species with no common name', () {
      final book = logbook(
        species: {99: const DivingLogRawSpecies(id: 99)},
        links: {
          1: [99],
        },
      );
      expect(
        DivingLogSightingsMapper.sightingsFor(book, book.dives.single),
        isEmpty,
      );
    });

    test('returns nothing for a dive with no links', () {
      expect(
        DivingLogSightingsMapper.sightingsFor(
          logbook(),
          const DivingLogRawDive(id: 1),
        ),
        isEmpty,
      );
    });
  });

  group('media', () {
    test('builds a media entry in the shared photo contract', () {
      final book = logbook(
        pictures: {
          1: [
            const DivingLogRawPicture(
              id: 1,
              logId: 1,
              path: '/photos/dive1.jpg',
              description: 'manta',
            ),
          ],
        },
      );
      final media = DivingLogSightingsMapper.mediaFor(
        book,
        book.dives.single,
        4,
      );
      expect(media, hasLength(1));
      expect(media.single['filename'], '/photos/dive1.jpg');
      expect(media.single['caption'], 'manta');
      expect(media.single['_diveIndex'], 4);
      expect(media.single['offsetSeconds'], isNull);
      expect(media.single['latitude'], isNull);
      expect(media.single['longitude'], isNull);
    });

    test('skips a picture row with no path', () {
      final book = logbook(
        pictures: {
          1: [const DivingLogRawPicture(id: 1, logId: 1)],
        },
      );
      expect(
        DivingLogSightingsMapper.mediaFor(book, book.dives.single, 0),
        isEmpty,
      );
    });
  });
}
