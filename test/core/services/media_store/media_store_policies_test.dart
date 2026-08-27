import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';

void main() {
  test('defaults: autoUpload on, photos-on-cellular on, videos-on-cellular '
      'off', () async {
    SharedPreferences.setMockInitialValues({});
    final policies = MediaStorePolicies(
      prefs: await SharedPreferences.getInstance(),
    );
    expect(await policies.autoUpload(), isTrue);
    expect(await policies.photosOnCellular(), isTrue);
    expect(await policies.videosOnCellular(), isFalse);
  });

  test('setters round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final policies = MediaStorePolicies(
      prefs: await SharedPreferences.getInstance(),
    );
    await policies.setAutoUpload(false);
    await policies.setPhotosOnCellular(false);
    await policies.setVideosOnCellular(true);
    expect(await policies.autoUpload(), isFalse);
    expect(await policies.photosOnCellular(), isFalse);
    expect(await policies.videosOnCellular(), isTrue);
  });
}
