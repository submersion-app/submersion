import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/card_photo_repository.dart';
import 'package:submersion/features/dive_log/data/services/card_focus_analyzer.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_picker.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';
import 'package:submersion/features/dive_log/presentation/providers/card_photo_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

class _FakeCardPhotoRepository extends CardPhotoRepository {
  _FakeCardPhotoRepository(this.photos);

  Map<String, List<CardPhoto>> photos;
  int reads = 0;
  final diverIds = <String?>[];
  final changes = StreamController<void>.broadcast();

  @override
  Stream<void> watchChanges() => changes.stream;

  @override
  Future<Map<String, List<CardPhoto>>> getCardPhotosByDive({
    required String? diverId,
  }) async {
    reads++;
    diverIds.add(diverId);
    return photos;
  }
}

/// The diver the list is shown for, as a test can change it.
final _diver = StateProvider<String?>((ref) => 'me');

const _a = CardPhoto(mediaId: 'a');
const _b = CardPhoto(
  mediaId: 'b',
  focusBoxes: [FocusBox(x: 0.2, y: 0.1, width: 0.3, height: 0.3)],
);
const _c = CardPhoto(mediaId: 'c');
const _d = CardPhoto(mediaId: 'd');
const _e = CardPhoto(mediaId: 'e');

void main() {
  late _FakeCardPhotoRepository photos;
  late ProviderContainer container;

  setUp(() {
    photos = _FakeCardPhotoRepository({
      'd1': const [_a],
      'd2': const [_b, _c],
      'd5': const [_a, _b, _c, _d, _e],
    });
    container = ProviderContainer(
      overrides: [
        cardPhotoRepositoryProvider.overrideWithValue(photos),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => ref.watch(_diver),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await photos.changes.close();
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

    expect(map.keys, unorderedEquals(['d1', 'd2', 'd5']));
    expect(map['d2'], [_b, _c]);
    expect(photos.reads, 1);
  });

  test('a photo change reads the photos again', () async {
    final sub = container.listen(cardPhotosByDiveProvider, (_, _) {});
    addTearDown(sub.close);
    await loaded();

    photos.photos = {
      'd3': const [_c],
    };
    photos.changes.add(null);

    final map = await loaded(reads: 2);
    expect(map.keys, ['d3']);
  });

  test('the photos are read for the active diver', () async {
    final sub = container.listen(cardPhotosByDiveProvider, (_, _) {});
    addTearDown(sub.close);
    await loaded();

    expect(photos.diverIds, ['me']);
  });

  test('a people tag change reads the photos again', () async {
    final sub = container.listen(cardPhotosByDiveProvider, (_, _) {});
    addTearDown(sub.close);
    await loaded();

    photos.photos = {
      'd1': const [_b],
    };
    photos.changes.add(null);

    final map = await loaded(reads: 2);
    expect(map['d1'], [_b]);
  });

  test('switching diver reads the photos again for the new one', () async {
    final sub = container.listen(cardPhotosByDiveProvider, (_, _) {});
    addTearDown(sub.close);
    await loaded();

    container.read(_diver.notifier).state = 'other';

    await loaded(reads: 2);
    expect(photos.diverIds, ['me', 'other']);
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

  group('a photo that cannot be drawn', () {
    void markFailed(String mediaId) =>
        container.read(failedCardPhotosProvider.notifier).markFailed(mediaId);

    Future<CardPhoto?> photoFor(String diveId) async {
      final sub = container.listen(cardPhotoForDiveProvider(diveId), (_, _) {});
      addTearDown(sub.close);
      await loaded();
      return container.read(cardPhotoForDiveProvider(diveId));
    }

    test("is passed over for another of the dive's photos", () async {
      final first = await photoFor('d2');
      markFailed(first!.mediaId);

      final next = container.read(cardPhotoForDiveProvider('d2'));
      expect(next, isNotNull);
      expect(next, isNot(first));
    });

    test(
      'leaves the card without a photo once the dive has no other',
      () async {
        markFailed('a');

        expect(await photoFor('d1'), isNull);
      },
    );

    test('three failures and the card stops trying photos', () async {
      final tried = <String>[];
      CardPhoto? photo = await photoFor('d5');
      for (var i = 0; i < 3; i++) {
        expect(photo, isNotNull, reason: 'attempt ${i + 1}');
        tried.add(photo!.mediaId);
        markFailed(photo.mediaId);
        photo = container.read<CardPhoto?>(cardPhotoForDiveProvider('d5'));
      }

      // Two of the five were never tried, but the card gives up on photos.
      expect(tried.toSet(), hasLength(3));
      expect(photo, isNull);
    });

    test(
      "a failure on another dive leaves this one's photo as it was",
      () async {
        final before = await photoFor('d2');
        markFailed('a');

        expect(container.read(cardPhotoForDiveProvider('d2')), same(before));
      },
    );

    test('is remembered once', () {
      final notifier = container.read(failedCardPhotosProvider.notifier);
      notifier.markFailed('a');
      final state = container.read(failedCardPhotosProvider);
      notifier.markFailed('a');

      expect(container.read(failedCardPhotosProvider), same(state));
      expect(state, {'a'});
    });
  });
}
