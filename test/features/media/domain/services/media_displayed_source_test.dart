import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_displayed_source.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _item(MediaSourceType type) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: type,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

ServingFacts _served(ServedFrom from) => ServingFacts.from(
  ServingObservation(
    servedFrom: from,
    servedTier: ServedTier.thumbnail,
    failure: null,
    storeFallbackUsed: false,
    observedAt: DateTime.utc(2026),
  ),
);

void main() {
  test('an observation wins over the row type', () {
    // The whole point of showing the SERVED source: a gallery row whose asset
    // was deleted is served from the cloud store, and saying "photo library"
    // there would describe a lookup that failed.
    expect(
      displayedSourceFor(
        _item(MediaSourceType.platformGallery),
        _served(ServedFrom.storeNetwork),
      ),
      ServedFrom.storeNetwork,
    );
  });

  test('an unobserved item falls back to what its type implies', () {
    // Without this the badge would pop in a frame after the thumbnail, which
    // on a scrolling grid reads as flicker rather than as information.
    expect(
      displayedSourceFor(
        _item(MediaSourceType.platformGallery),
        ServingFacts.unobserved,
      ),
      ServedFrom.platformGallery,
    );
  });

  group('every source type maps to a source', () {
    const expected = {
      MediaSourceType.platformGallery: ServedFrom.platformGallery,
      MediaSourceType.localFile: ServedFrom.localDisk,
      MediaSourceType.networkUrl: ServedFrom.networkUrl,
      MediaSourceType.manifestEntry: ServedFrom.networkUrl,
      MediaSourceType.serviceConnector: ServedFrom.connectorNetwork,
      MediaSourceType.mediaStore: ServedFrom.storeNetwork,
      MediaSourceType.signature: ServedFrom.embedded,
    };

    for (final type in MediaSourceType.values) {
      test('$type', () {
        expect(expectedSourceFor(type), expected[type]);
      });
    }
  });

  test('the fallback never guesses a cache hit', () {
    // A cache hit is a fact about THIS session. Only an observation can
    // establish it, so the fallback picks the network variants.
    for (final type in MediaSourceType.values) {
      expect(
        expectedSourceFor(type),
        isNot(anyOf(ServedFrom.storeCache, ServedFrom.connectorCache)),
      );
    }
  });
}
