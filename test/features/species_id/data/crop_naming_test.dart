import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/services/crop_naming.dart';

import 'pack_fixture.dart';

/// Naming a scan's crops in a worker that holds the candidate table once
/// (issue #4675).
void main() {
  final crops = [
    (embedding: Float32List.fromList([1, 0, 0]), shorterSide: 300),
    (embedding: Float32List.fromList([0, 0.2, 1]), shorterSide: 300),
  ];

  test('the worker names crops as the one-off call does', () async {
    final pack = fixturePack();
    final worker = await CropNamingWorker.start(pack, 1462);
    addTearDown(worker.close);
    expect(await worker.name(crops), await nameCrops(pack, crops, 1462));
    // And again, from the same table.
    expect(await worker.name(crops.reversed.toList()), hasLength(2));
    expect(await worker.name(const []), isEmpty);
  });

  test('a closed worker refuses rather than waiting forever', () async {
    final worker = await CropNamingWorker.start(fixturePack(), null);
    await worker.close();
    await expectLater(worker.name(crops), throwsStateError);
  });

  test('a worker that stops while naming fails the call, and nothing is '
      'left unhandled', () async {
    final worker = await CropNamingWorker.start(fixturePack(), null);
    final closing = worker.close();
    await expectLater(worker.name(crops), throwsStateError);
    await closing;
  });

  test('a worker that dies before it is ready fails to start rather than '
      'waiting forever', () async {
    final good = fixturePack();
    // A table that does not fit its candidates: the namer refuses it.
    final broken = LoadedPack(
      pack: good.pack,
      candidates: good.candidates,
      textEmbeddings: Float32List(1),
      regions: good.regions,
    );
    await expectLater(
      CropNamingWorker.start(broken, null).timeout(const Duration(seconds: 10)),
      throwsStateError,
    );
  });
}
