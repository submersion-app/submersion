import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';

import '../../../helpers/in_memory_media_object_store.dart';

void main() {
  test('ensure writes a marker when absent and is stable afterwards', () async {
    final store = InMemoryMediaObjectStore();
    final markers = StoreMarkerStore(store: store);

    final first = await markers.ensure();
    expect(first.created, isTrue);
    expect(first.marker.storeId, isNotEmpty);
    expect(first.marker.formatVersion, 1);
    expect(store.objects.containsKey(StoreKeys.markerKey), isTrue);

    final second = await markers.ensure();
    expect(second.created, isFalse);
    expect(second.marker.storeId, first.marker.storeId);
  });

  test('read returns null when no marker exists and parses an existing '
      'one', () async {
    final store = InMemoryMediaObjectStore();
    final markers = StoreMarkerStore(store: store);
    expect(await markers.read(), isNull);
    await markers.ensure();
    final marker = await markers.read();
    expect(marker, isNotNull);
    expect(marker!.storeId, isNotEmpty);
  });

  test('corrupt marker json reads as null', () async {
    final store = InMemoryMediaObjectStore();
    store.objects[StoreKeys.markerKey] = 'not json'.codeUnits;
    final markers = StoreMarkerStore(store: store);
    expect(await markers.read(), isNull);
  });
}
