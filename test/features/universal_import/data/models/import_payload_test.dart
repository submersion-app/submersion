import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

void main() {
  test('defaults imageRefs to empty', () {
    const payload = ImportPayload(entities: {});
    expect(payload.imageRefs, isEmpty);
  });

  test('carries imageRefs', () {
    const payload = ImportPayload(
      entities: {},
      imageRefs: [
        ImportImageRef(originalPath: '/photos/a.jpg', diveSourceUuid: 'dive-1'),
      ],
    );
    expect(payload.imageRefs.length, 1);
    expect(payload.imageRefs.first.filename, 'a.jpg');
  });

  test('imageRefs-only payload is not empty', () {
    const payload = ImportPayload(
      entities: {ImportEntityType.dives: []},
      imageRefs: [
        ImportImageRef(originalPath: '/photos/a.jpg', diveSourceUuid: 'd'),
      ],
    );
    expect(payload.isEmpty, isFalse);
    expect(payload.isNotEmpty, isTrue);
  });

  test('truly empty payload is empty', () {
    const payload = ImportPayload(entities: {ImportEntityType.dives: []});
    expect(payload.isEmpty, isTrue);
  });

  test('imageRefs participates in equality', () {
    const a = ImportPayload(
      entities: {},
      imageRefs: [
        ImportImageRef(originalPath: '/p/a.jpg', diveSourceUuid: 'd'),
      ],
    );
    const b = ImportPayload(entities: {});
    expect(a == b, isFalse);
  });
}
