import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

import '../../../helpers/temp_dir.dart';

void main() {
  late Directory support;
  late IdentificationCropStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('crop_store_test');
    store = IdentificationCropStore(supportPath: () async => support.path);
  });
  tearDown(() => deleteTempDir(support));

  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  test(
    'crops live under species_id/crops/<media>/<identification>.jpg',
    () async {
      final file = await store.fileFor('m1', 'i1');
      expect(
        file.path,
        p.join(support.path, 'species_id', 'crops', 'm1', 'i1.jpg'),
      );
      expect(
        (await store.root()).path,
        p.join(support.path, 'species_id', 'crops'),
      );
    },
  );

  test('a written crop is present and reads back', () async {
    await store.write('m1', 'i1', jpeg);
    expect(await (await store.fileFor('m1', 'i1')).readAsBytes(), jpeg);
    expect(await store.allPresent('m1', ['i1']), isTrue);
  });

  test('one missing crop means not all present', () async {
    await store.write('m1', 'i1', jpeg);
    expect(await store.allPresent('m1', ['i1', 'i2']), isFalse);
  });

  test('a photo analysed here is remembered until its folder goes', () async {
    expect(await store.wasAnalysedHere('m1'), isFalse);
    await store.markAnalysed('m1');
    expect(await store.wasAnalysedHere('m1'), isTrue);
    expect(await store.wasAnalysedHere('m2'), isFalse);
    await store.deleteMedia(['m1']);
    expect(await store.wasAnalysedHere('m1'), isFalse);
  });

  test('writes and deletes are announced by media id', () async {
    final seen = <String>[];
    final sub = store.watchChanges().listen(seen.add);
    await store.write('m1', 'i1', jpeg);
    await store.delete('m1', ['i1']);
    await store.deleteMedia(['m2']);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, ['m1', 'm1', 'm2']);
  });

  test('no identifications means nothing is missing', () async {
    expect(await store.allPresent('m1', const []), isTrue);
  });

  test('deleting media removes its folder and nothing else', () async {
    await store.write('m1', 'i1', jpeg);
    await store.write('m2', 'i2', jpeg);
    await store.deleteMedia(['m1']);
    expect(
      await Directory(
        p.join(support.path, 'species_id', 'crops', 'm1'),
      ).exists(),
      isFalse,
    );
    expect(await store.allPresent('m2', ['i2']), isTrue);
  });

  test('deleting some crops leaves the rest', () async {
    await store.write('m1', 'i1', jpeg);
    await store.write('m1', 'i2', jpeg);
    await store.delete('m1', ['i1']);
    expect(await store.allPresent('m1', ['i2']), isTrue);
    expect(await store.allPresent('m1', ['i1']), isFalse);
  });

  test('deleting a photo\'s crops counts zero bytes', () async {
    await store.write('m1', 'i1', jpeg);
    expect(await store.sizeBytes(), jpeg.length);
    await store.deleteMedia(['m1']);
    expect(await store.sizeBytes(), 0);
  });

  test('crop files are listed by media, without the analysed mark or a '
      'half-written crop (issue #4890)', () async {
    await store.write('m1', 'i1', jpeg);
    await store.write('m1', 'i2', jpeg);
    await store.write('m2', 'i3', jpeg);
    await store.markAnalysed('m1');
    await store.markAnalysed('m3');
    await File(
      p.join((await store.root()).path, 'm2', 'i4.jpg.tmp'),
    ).writeAsBytes(jpeg);

    final listed = await store.fileIds();

    expect(listed.keys, unorderedEquals(['m1', 'm2']));
    expect(listed['m1'], unorderedEquals(['i1', 'i2']));
    expect(listed['m2'], ['i3']);
  });

  test('a crop another cleanup removes mid-way does not stop the rest '
      '(issue #4890)', () async {
    final racing = _RacingStore(supportPath: () async => support.path);
    addTearDown(racing.dispose);
    await racing.write('m1', 'i2', jpeg);

    await expectLater(racing.deleteFiles('m1', ['gone', 'i2']), completes);

    expect(await racing.allPresent('m1', ['i2']), isFalse);
  });

  test('a folder that cannot be read lists no crops', () async {
    expect(
      await IdentificationCropStore.cropIdsIn(
        Directory(p.join(support.path, 'never-made')),
      ),
      isEmpty,
    );
  });

  test('deleting crop files removes only those, announced once', () async {
    await store.write('m1', 'i1', jpeg);
    await store.write('m1', 'i2', jpeg);
    final seen = <String>[];
    final sub = store.watchChanges().listen(seen.add);
    addTearDown(sub.cancel);

    await store.deleteFiles('m1', ['i1', 'absent']);
    await store.deleteFiles('m1', ['absent']);
    await pumpEventQueue();

    expect(await store.allPresent('m1', ['i1']), isFalse);
    expect(await store.allPresent('m1', ['i2']), isTrue);
    expect(seen, ['m1']);
  });

  test('an id that could leave the folder is refused', () async {
    expect(() => store.fileFor('..', 'i1'), throwsArgumentError);
    expect(() => store.fileFor('m1', p.join('a', 'b')), throwsArgumentError);
  });
}

/// A store whose crop `gone` is removed by another cleanup between the
/// check that it exists and its delete.
class _RacingStore extends IdentificationCropStore {
  _RacingStore({required super.supportPath});

  @override
  Future<File> fileFor(String mediaId, String identificationId) async =>
      identificationId == 'gone'
      ? _VanishedFile()
      : super.fileFor(mediaId, identificationId);
}

class _VanishedFile extends Fake implements File {
  @override
  String get path => 'gone.jpg';

  @override
  Future<bool> exists() async => true;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      Future.error(PathNotFoundException(path, const OSError('gone', 2)));
}
