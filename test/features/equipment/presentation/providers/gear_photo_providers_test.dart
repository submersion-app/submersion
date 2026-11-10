import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// The gear photo providers (issue #3355) read through to the repository,
/// and the Gear gallery shows only gear the viewing diver can see.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> item(String name, String diverId) =>
      EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          diverId: diverId,
          name: name,
          type: EquipmentType.regulator,
        ),
      );

  Future<MediaItem> photo(String equipmentId, {String? observationId}) {
    final at = DateTime.utc(2026, 11, 3);
    return MediaRepository().createMedia(
      MediaItem(
        id: '',
        equipmentId: equipmentId,
        observationId: observationId,
        filePath: '/photos/${DateTime.now().microsecondsSinceEpoch}.jpg',
        mediaType: MediaType.photo,
        takenAt: at,
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  test('the gallery shows only the viewing diver\'s gear', () async {
    final mine = await item('Mine', 'd1');
    final theirs = await item('Theirs', 'd2');
    await photo(mine.id);
    await photo(theirs.id);

    final groups = await container.read(gearGalleryProvider.future);

    expect(groups.map((g) => g.name), ['Mine']);
  });

  test('the item providers read through to the repository', () async {
    final reg = await item('Reg', 'd1');
    final checkIn = await EquipmentObservationRepository().create(
      equipmentId: reg.id,
      observedAt: DateTime.utc(2026, 11, 3),
      status: ObservationStatus.ok,
    );
    final idPhoto = await photo(reg.id);
    final finding = await photo(reg.id, observationId: checkIn.id);
    await GearPhotoRepository().setCover(reg.id, idPhoto.id);

    expect(
      (await container.read(
        identificationPhotosProvider(reg.id).future,
      )).map((m) => m.id),
      [idPhoto.id],
    );
    expect(
      (await container.read(
        checkInPhotosProvider(reg.id).future,
      ))[checkIn.id]!.single.id,
      finding.id,
    );
    expect(
      (await container.read(
        observationPhotosProvider(checkIn.id).future,
      )).single.id,
      finding.id,
    );
    expect(
      (await container.read(
        equipmentCoverProvider((
          equipmentId: reg.id,
          coverMediaId: idPhoto.id,
        )).future,
      ))?.id,
      idPhoto.id,
    );
  });
}
