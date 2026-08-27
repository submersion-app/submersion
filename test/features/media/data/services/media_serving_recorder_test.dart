import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  test('records and reads back a successful resolution', () {
    final r = MediaServingRecorder(now: () => DateTime.utc(2026, 8, 16));

    r.record(
      'm1',
      thumbnail: false,
      servedFrom: ServedFrom.storeCache,
      servedTier: ServedTier.original,
    );

    final obs = r.lastFor('m1', thumbnail: false)!;
    expect(obs.servedFrom, ServedFrom.storeCache);
    expect(obs.servedTier, ServedTier.original);
    expect(obs.failure, isNull);
    expect(obs.storeFallbackUsed, isFalse);
    expect(obs.observedAt, DateTime.utc(2026, 8, 16));
  });

  test('thumbnail and original observations do not overwrite each other', () {
    final r = MediaServingRecorder();

    r.record('m1', thumbnail: true, servedFrom: ServedFrom.storeCache);
    r.record('m1', thumbnail: false, servedFrom: ServedFrom.storeNetwork);

    expect(r.lastFor('m1', thumbnail: true)!.servedFrom, ServedFrom.storeCache);
    expect(
      r.lastFor('m1', thumbnail: false)!.servedFrom,
      ServedFrom.storeNetwork,
    );
  });

  test('records a failure with no source', () {
    final r = MediaServingRecorder();

    r.record(
      'm1',
      thumbnail: false,
      failure: UnavailableKind.notFound,
      storeFallbackUsed: true,
    );

    final obs = r.lastFor('m1', thumbnail: false)!;
    expect(obs.servedFrom, isNull);
    expect(obs.failure, UnavailableKind.notFound);
    expect(obs.storeFallbackUsed, isTrue);
  });

  test('returns null for an item never observed', () {
    expect(MediaServingRecorder().lastFor('nope', thumbnail: false), isNull);
  });

  test('evicts least recently recorded beyond maxEntries', () {
    final r = MediaServingRecorder(maxEntries: 2);

    r.record('a', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('b', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('c', thumbnail: false, servedFrom: ServedFrom.localDisk);

    expect(r.entryCount, 2);
    expect(r.lastFor('a', thumbnail: false), isNull);
    expect(r.lastFor('b', thumbnail: false), isNotNull);
    expect(r.lastFor('c', thumbnail: false), isNotNull);
  });

  test('re-recording an id refreshes its recency', () {
    final r = MediaServingRecorder(maxEntries: 2);

    r.record('a', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('b', thumbnail: false, servedFrom: ServedFrom.localDisk);
    r.record('a', thumbnail: false, servedFrom: ServedFrom.storeCache);
    r.record('c', thumbnail: false, servedFrom: ServedFrom.localDisk);

    expect(r.lastFor('a', thumbnail: false)!.servedFrom, ServedFrom.storeCache);
    expect(r.lastFor('b', thumbnail: false), isNull);
  });

  test('notifies listeners on record', () {
    final r = MediaServingRecorder();
    var notifications = 0;
    r.addListener(() => notifications++);

    r.record('m1', thumbnail: false, servedFrom: ServedFrom.localDisk);

    expect(notifications, 1);
  });

  // A resolution can outlive the container that owns the recorder: a
  // FutureProvider still in flight when a ProviderContainer is disposed runs
  // its continuation afterwards and records into a notifier that is already
  // gone. notifyListeners asserts in that state, so the write has to be
  // dropped rather than attempted.
  test('recording after dispose is a no-op rather than a throw', () {
    final r = MediaServingRecorder()..dispose();

    expect(
      () => r.record('m1', thumbnail: false, servedFrom: ServedFrom.localDisk),
      returnsNormally,
    );
    expect(r.lastFor('m1', thumbnail: false), isNull);
  });
}
