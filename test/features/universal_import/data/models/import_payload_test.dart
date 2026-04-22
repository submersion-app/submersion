import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

void main() {
  group('ImportPayload.imageRefs', () {
    test('defaults to empty list', () {
      const payload = ImportPayload(entities: {});
      expect(payload.imageRefs, isEmpty);
    });

    test('carries passed-in image refs', () {
      const payload = ImportPayload(
        entities: {},
        imageRefs: [
          ImportImageRef(
            originalPath: '/photos/a.jpg',
            diveSourceUuid: 'dive-1',
          ),
        ],
      );
      expect(payload.imageRefs.length, 1);
      expect(payload.imageRefs.first.filename, 'a.jpg');
    });

    test('isEmpty is false when only imageRefs are present', () {
      const payload = ImportPayload(
        entities: {},
        imageRefs: [ImportImageRef(originalPath: 'a.jpg', diveSourceUuid: 'd')],
      );
      expect(
        payload.isEmpty,
        isFalse,
        reason: 'a payload carrying photos should not count as empty',
      );
    });
  });
}
