import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';

void main() {
  test('the container owns the recorder and disposes it', () {
    final container = ProviderContainer();
    final recorder = container.read(mediaServingRecorderProvider);
    var notifications = 0;
    recorder.addListener(() => notifications++);

    recorder.record('m1', thumbnail: false, servedFrom: ServedFrom.localDisk);
    expect(notifications, 1);

    container.dispose();

    // Disposed: a late write from a resolution that outlived the container is
    // dropped instead of asserting inside notifyListeners.
    recorder.record('m2', thumbnail: false, servedFrom: ServedFrom.localDisk);
    expect(notifications, 1);
    expect(recorder.lastFor('m2', thumbnail: false), isNull);
  });

  test('each container gets its own recorder', () {
    final a = ProviderContainer();
    final b = ProviderContainer();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    expect(
      identical(
        a.read(mediaServingRecorderProvider),
        b.read(mediaServingRecorderProvider),
      ),
      isFalse,
    );
  });
}
