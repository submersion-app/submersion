import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';

void main() {
  test('the production reader reads originals as files on every platform '
      'photo_manager serves, Android included (#4999)', () {
    // On Android the bytes path pulled a whole video across the platform
    // channel, several copies deep, and an upload of two dive videos ran
    // the app out of memory on every launch. photo_manager's Android file
    // read streams the original into its cache instead.
    expect(const PhotoManagerAssetReader().originalsAsFiles, isTrue);
  });
}
