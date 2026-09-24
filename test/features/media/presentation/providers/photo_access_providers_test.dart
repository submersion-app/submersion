import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/providers/photo_access_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

class _FailingRead extends FakePhotoPickerService {
  @override
  Future<PhotoPermissionStatus> currentPermission() async =>
      throw StateError('channel');
}

/// The info panel offers the limited-access actions only when this device's
/// access is a limited selection (media sync program spec 6.3). The answer
/// is an offer, never a verdict, so anything uncertain reads as false.
void main() {
  Future<bool> limitedWith(PhotoPickerService photos) async {
    final container = ProviderContainer(
      overrides: [photoPickerServiceProvider.overrideWithValue(photos)],
    );
    addTearDown(container.dispose);
    return container.read(galleryAccessLimitedProvider.future);
  }

  test('a limited selection reads as limited', () async {
    expect(
      await limitedWith(
        FakePhotoPickerService(permission: PhotoPermissionStatus.limited),
      ),
      isTrue,
    );
  });

  test('full access does not', () async {
    expect(await limitedWith(FakePhotoPickerService()), isFalse);
  });

  test('a host with no photo library does not', () async {
    expect(
      await limitedWith(
        FakePhotoPickerService(
          permission: PhotoPermissionStatus.limited,
          supportsGalleryBrowsing: false,
        ),
      ),
      isFalse,
    );
  });

  test('a permission read that fails does not', () async {
    expect(await limitedWith(_FailingRead()), isFalse);
  });
}
