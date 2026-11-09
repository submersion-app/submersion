import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../helpers/test_database.dart';

/// Gear photos live only in the Gear gallery (issue #3355): a row linked to
/// gear and to nothing else leaves every ordinary library view, while a row
/// a dive or site also holds stays, because it is that dive's photo too.
void main() {
  late AppDatabase db;
  late MediaRepository media;
  late MediaLibraryRepository library;
  late String gearOnlyId;
  late String diveGearId;
  late String plainId;

  setUp(() async {
    db = await setUpTestDatabase();
    media = MediaRepository();
    library = MediaLibraryRepository();
    final item = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 1, dateTime: DateTime.utc(2026, 11, 3)),
    );

    Future<String> add({String? equipmentId, String? diveId}) async {
      final at = DateTime.utc(2026, 11, 3);
      final saved = await media.createMedia(
        MediaItem(
          id: '',
          equipmentId: equipmentId,
          diveId: diveId,
          filePath: '/photos/${DateTime.now().microsecondsSinceEpoch}.jpg',
          mediaType: MediaType.photo,
          latitude: 20.5,
          longitude: -87.0,
          takenAt: at,
          createdAt: at,
          updatedAt: at,
        ),
      );
      return saved.id;
    }

    gearOnlyId = await add(equipmentId: item.id);
    diveGearId = await add(equipmentId: item.id, diveId: dive.id);
    plainId = await add(diveId: dive.id);
  });

  tearDown(tearDownTestDatabase);

  test(
    'library hides gear-only rows but keeps dive-linked gear rows',
    () async {
      final page = await library.getPage(diverId: null);
      final ids = page.entries.map((e) => e.item.id).toSet();

      expect(ids, {diveGearId, plainId});
      expect(ids, isNot(contains(gearOnlyId)));
    },
  );

  test('scope count leaves gear-only rows out', () async {
    expect(await library.countInScope(diverId: null), 2);
  });

  test('map leaves gear-only rows out', () async {
    final points = await library.getMapPoints(diverId: null);

    expect(points.map((p) => p.entry.item.id), isNot(contains(gearOnlyId)));
    expect(points, hasLength(2));
  });

  test('source type counts leave gear-only rows out', () async {
    final counts = await library.countBySourceType();

    expect(counts.values.fold<int>(0, (a, b) => a + b), 2);
    expect(db, isNotNull);
  });
}
