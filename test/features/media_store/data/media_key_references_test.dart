import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_key_reference.dart';
import 'package:submersion/features/media_store/data/media_key_references.dart';

MediaKeyReference ref({
  String ext = 'jpg',
  bool video = false,
  bool original = false,
  bool rendition = false,
}) => MediaKeyReference(
  originalExtension: ext,
  isVideo: video,
  hasOriginalStamp: original,
  hasRenditionStamp: rendition,
);

void main() {
  test('an unreferenced hash is not referenced', () {
    for (final ns in StoreNamespace.values) {
      expect(
        isKeyReferenced(namespace: ns, extension: 'jpg', refs: const []),
        isFalse,
      );
    }
  });

  test('a row with no upload stamp keeps every object under its hash', () {
    final refs = [ref(ext: 'jpg', rendition: true), ref(ext: 'png')];
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.objects,
        extension: 'bin',
        refs: refs,
      ),
      isTrue,
    );
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.renditions,
        extension: 'mp4',
        refs: refs,
      ),
      isTrue,
    );
  });

  test('keeps every extension some row still resolves to', () {
    final refs = [
      ref(ext: 'jpg', original: true),
      ref(ext: 'jpeg', original: true),
    ];
    for (final ext in ['jpg', 'jpeg']) {
      expect(
        isKeyReferenced(
          namespace: StoreNamespace.objects,
          extension: ext,
          refs: refs,
        ),
        isTrue,
        reason: ext,
      );
    }
  });

  test('drops an extension no stamped row resolves to', () {
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.objects,
        extension: 'bin',
        refs: [ref(ext: 'jpg', original: true)],
      ),
      isFalse,
    );
  });

  test('drops the original once every row is stamped compressed only', () {
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.objects,
        extension: 'jpg',
        refs: [ref(ext: 'jpg', rendition: true)],
      ),
      isFalse,
    );
    // A second row still on the original keeps it.
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.objects,
        extension: 'jpg',
        refs: [
          ref(ext: 'jpg', rendition: true),
          ref(ext: 'jpg', original: true),
        ],
      ),
      isTrue,
    );
  });

  test('drops the rendition once every row is stamped original only', () {
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.renditions,
        extension: 'jpg',
        refs: [ref(ext: 'jpg', original: true)],
      ),
      isFalse,
    );
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.renditions,
        extension: 'jpg',
        refs: [ref(ext: 'jpg', rendition: true)],
      ),
      isTrue,
    );
  });

  test('a video rendition is mp4, so a jpg rendition beside it goes', () {
    final refs = [ref(ext: 'mov', video: true, rendition: true)];
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.renditions,
        extension: 'mp4',
        refs: refs,
      ),
      isTrue,
    );
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.renditions,
        extension: 'jpg',
        refs: refs,
      ),
      isFalse,
    );
  });

  test('thumbs are always referenced', () {
    expect(
      isKeyReferenced(
        namespace: StoreNamespace.thumbs,
        extension: 'jpg',
        refs: [ref(original: true)],
      ),
      isTrue,
    );
  });
}
