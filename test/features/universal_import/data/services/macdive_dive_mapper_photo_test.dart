import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

MacDiveRawLogbook _logbook({
  required List<MacDiveRawDive> dives,
  required List<MacDiveRawDiveImage> images,
}) {
  return MacDiveRawLogbook(
    dives: dives,
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveImages: images,
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}

void main() {
  test('maps ZDIVEIMAGE rows to imageRefs keyed by dive UUID', () {
    final payload = MacDiveDiveMapper.toPayload(
      _logbook(
        dives: const [
          MacDiveRawDive(pk: 1, uuid: 'dive-uuid-1'),
          MacDiveRawDive(pk: 2, uuid: 'dive-uuid-2'),
        ],
        images: const [
          MacDiveRawDiveImage(
            pk: 1,
            uuid: 'img-1',
            diveFk: 1,
            position: 0,
            caption: 'Shark!',
            path: '/Users/test/Pictures/Diving/shark.jpg',
            originalPath: '/old/shark.jpg',
          ),
          MacDiveRawDiveImage(
            pk: 2,
            uuid: 'img-2',
            diveFk: 2,
            position: 1,
            path: '/Users/test/Pictures/Diving/turtle.jpg',
          ),
        ],
      ),
    );

    expect(payload.imageRefs.length, 2);
    final shark = payload.imageRefs.firstWhere((r) => r.caption == 'Shark!');
    expect(shark.diveSourceUuid, 'dive-uuid-1');
    expect(shark.originalPath, '/Users/test/Pictures/Diving/shark.jpg');
    expect(shark.position, 0);
    expect(shark.sourceUuid, 'img-1');
  });

  test('drops photos whose dive FK has no UUID (orphan rows)', () {
    final payload = MacDiveDiveMapper.toPayload(
      _logbook(
        dives: const [MacDiveRawDive(pk: 1, uuid: 'dive-uuid-1')],
        images: const [
          MacDiveRawDiveImage(
            pk: 9,
            uuid: 'img-9',
            diveFk: 999,
            path: '/x.jpg',
          ),
        ],
      ),
    );
    expect(payload.imageRefs, isEmpty);
  });

  test('falls back to originalPath when path is null; drops if both null', () {
    final payload = MacDiveDiveMapper.toPayload(
      _logbook(
        dives: const [MacDiveRawDive(pk: 1, uuid: 'dive-uuid-1')],
        images: const [
          MacDiveRawDiveImage(
            pk: 1,
            uuid: 'img-1',
            diveFk: 1,
            originalPath: '/orig/only.jpg',
          ),
          MacDiveRawDiveImage(pk: 2, uuid: 'img-2', diveFk: 1),
        ],
      ),
    );
    expect(payload.imageRefs.length, 1);
    expect(payload.imageRefs.single.originalPath, '/orig/only.jpg');
  });
}
