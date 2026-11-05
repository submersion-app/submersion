import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/card_photo_repository.dart';
import 'package:submersion/features/dive_log/data/services/card_focus_analyzer.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_picker.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';
import 'package:submersion/features/dive_log/presentation/providers/card_photo_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

class _FakeCardPhotoRepository extends CardPhotoRepository {
  _FakeCardPhotoRepository(this.photos);

  Map<String, List<CardPhoto>> photos;
  int reads = 0;

  @override
  Future<Map<String, List<CardPhoto>>> getCardPhotosByDive() async {
    reads++;
    return photos;
  }
}

class _FakeMediaRepository extends MediaRepository {
  final changes = StreamController<void>.broadcast();

  @override
  Stream<void> watchMediaChanges() => changes.stream;
}

const _a = CardPhoto(mediaId: 'a');
const _b = CardPhoto(
  mediaId: 'b',
  focusBoxes: [FocusBox(x: 0.2, y: 0.1, width: 0.3, height: 0.3)],
);
const _c = CardPhoto(mediaId: 'c');

void main() {
  late _FakeCardPhotoRepository photos;
  late _FakeMediaRepository media;
  late ProviderContainer container;

  setUp(() {
    photos = _FakeCardPhotoRepository({
      'd1': const [_a],
      'd2': const [_b, _c],
    });
    media = _FakeMediaRepository();
    container = ProviderContainer(
      overrides: [
        cardPhotoRepositoryProvider.overrideWithValue(photos),
        mediaRepositoryProvider.overrideWithValue(media),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await media.changes.close();
  });

  /// Waits until [cardPhotosByDiveProvider] has read [reads] times and
  /// holds a value.
  Future<Map<String, List<CardPhoto>>> loaded({int reads = 1}) async {
    for (var i = 0; i < 100; i++) {
      final value = container.read(cardPhotosByDiveProvider);
      if (photos.reads >= reads && value.hasValue && !value.isLoading) {
        return value.value!;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('the card photos never loaded');
  }

  test('the real providers build their own repository and analyser', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);

    expect(plain.read(cardPhotoRepositoryProvider), isA<CardPhotoRepository>());
    expect(plain.read(cardFocusAnalyzerProvider), isA<CardFocusAnalyzer>());
    // One analyser for every card, so its cache is shared.
    expect(
      plain.read(cardFocusAnalyzerProvider),
      same(plain.read(cardFocusAnalyzerProvider)),
    );
  });

  test('every dive\'s photos are read once for the whole log', () async {
    final sub = container.listen(cardPhotosByDiveProvider, (_, _) {});
    addTearDown(sub.close);

    final map = await loaded();

    expect(map.keys, unorderedEquals(['d1', 'd2']));
    expect(map['d2'], [_b, _c]);
    expect(photos.reads, 1);
  });

  test('a media change reads the photos again', () async {
    final sub = container.listen(cardPhotosByDiveProvider, (_, _) {});
    addTearDown(sub.close);
    await loaded();

    photos.photos = {
      'd3': const [_c],
    };
    media.changes.add(null);

    final map = await loaded(reads: 2);
    expect(map.keys, ['d3']);
  });

  test('a dive with one photo shows it', () async {
    final sub = container.listen(cardPhotoForDiveProvider('d1'), (_, _) {});
    addTearDown(sub.close);
    await loaded();

    expect(container.read(cardPhotoForDiveProvider('d1')), _a);
  });

  test('a dive with several photos shows the one the picker chooses', () async {
    final sub = container.listen(cardPhotoForDiveProvider('d2'), (_, _) {});
    addTearDown(sub.close);
    await loaded();

    expect(
      container.read(cardPhotoForDiveProvider('d2')),
      pickCardPhoto('d2', const [_b, _c]),
    );
  });

  test('a dive with no photos has none', () async {
    final sub = container.listen(cardPhotoForDiveProvider('none'), (_, _) {});
    addTearDown(sub.close);
    await loaded();

    expect(container.read(cardPhotoForDiveProvider('none')), isNull);
  });

  test('while the photos load, no dive has one', () {
    expect(container.read(cardPhotoForDiveProvider('d1')), isNull);
  });
}
