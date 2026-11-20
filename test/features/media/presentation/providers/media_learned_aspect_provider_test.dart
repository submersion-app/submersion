import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import '../support/media_widget_harness.dart';

MediaItem _item(
  String id, {
  int? width = 4000,
  int? height = 3000,
  MediaType type = MediaType.photo,
}) => MediaItem(
  id: id,
  mediaType: type,
  sourceType: MediaSourceType.localFile,
  width: width,
  height: height,
  takenAt: DateTime.utc(2026, 5, 2),
  createdAt: DateTime.utc(2026, 5, 2),
  updatedAt: DateTime.utc(2026, 5, 2),
);

/// Shapes learned from decoded library thumbnails (issue #4738).
void main() {
  late FakeAspectCacheRepository repository;
  late ProviderContainer container;

  Future<MediaLearnedAspectsNotifier> start([
    Map<String, LearnedAspect> stored = const {},
  ]) async {
    repository = FakeAspectCacheRepository(stored);
    container = ProviderContainer(
      overrides: [
        mediaAspectCacheRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mediaLearnedAspectsProvider.future);
    return container.read(mediaLearnedAspectsProvider.notifier);
  }

  Map<String, LearnedAspect> learned() =>
      container.read(mediaLearnedAspectsProvider).requireValue;

  testWidgets('a cache that cannot be read starts with nothing learned', (
    tester,
  ) async {
    repository = FakeAspectCacheRepository.failing();
    container = ProviderContainer(
      overrides: [
        mediaAspectCacheRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await tester.runAsync(
        () => container.read(mediaLearnedAspectsProvider.future),
      ),
      isEmpty,
    );
  });

  testWidgets('loads the stored shapes', (tester) async {
    await tester.runAsync(
      () => start({'a': (ratio: 0.75, width: 4000, height: 3000)}),
    );

    expect(learned(), {'a': (ratio: 0.75, width: 4000, height: 3000)});
  });

  testWidgets('a decode matching the item records nothing', (tester) async {
    final notifier = await tester.runAsync(start);

    notifier!.report(_item('a'), const Size(400, 300));
    await tester.pump();

    expect(learned(), isEmpty);
    expect(repository.writes, isEmpty);
  });

  testWidgets('rotated decodes are learned together after the frame', (
    tester,
  ) async {
    final notifier = await tester.runAsync(start);

    notifier!.report(_item('a'), const Size(300, 400));
    notifier.report(_item('b', width: null, height: null), const Size(1, 2));
    expect(learned(), isEmpty, reason: 'held until the frame ends');
    await tester.pump();

    final expected = {
      'a': (ratio: 0.75, width: 4000, height: 3000),
      'b': (ratio: 0.5, width: null, height: null),
    };
    expect(learned(), expected);
    expect(repository.writes, [expected]);
  });

  testWidgets('a report pending when the provider goes away does nothing', (
    tester,
  ) async {
    final notifier = await tester.runAsync(start);

    notifier!.report(_item('a'), const Size(300, 400));
    container.dispose();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.writes, isEmpty);
  });

  testWidgets('a document is never learned', (tester) async {
    final notifier = await tester.runAsync(start);

    notifier!.report(
      _item('d', type: MediaType.document),
      const Size(400, 300),
    );
    await tester.pump();

    expect(learned(), isEmpty);
  });

  testWidgets('a video learns from its poster', (tester) async {
    final notifier = await tester.runAsync(start);

    notifier!.report(
      _item('v', width: 1920, height: 1080, type: MediaType.video),
      const Size(1080, 1920),
    );
    await tester.pump();

    expect(learned()['v']?.ratio, closeTo(1080 / 1920, 1e-9));
  });

  testWidgets('a zero-sized decode is ignored', (tester) async {
    final notifier = await tester.runAsync(start);

    notifier!.report(_item('a'), Size.zero);
    await tester.pump();

    expect(learned(), isEmpty);
  });

  testWidgets('a decode already learned is not written again', (tester) async {
    final notifier = await tester.runAsync(
      () => start({'a': (ratio: 0.75, width: 4000, height: 3000)}),
    );

    notifier!.report(_item('a'), const Size(300, 400));
    await tester.pump();

    expect(repository.writes, isEmpty);
  });
}
