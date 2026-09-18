import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

/// Holds both permission calls open until [gate] completes, and fails them
/// instead when [fail] is set.
class _GatedPermissionService implements PhotoPickerService {
  final gate = Completer<void>();
  bool fail = false;

  Future<PhotoPermissionStatus> _answer() async {
    await gate.future;
    if (fail) throw StateError('platform channel gone');
    return PhotoPermissionStatus.authorized;
  }

  @override
  Future<PhotoPermissionStatus> checkPermission() => _answer();

  @override
  Future<PhotoPermissionStatus> requestPermission() => _answer();

  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      const [];

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
}

void main() {
  late _GatedPermissionService service;
  late ProviderContainer container;

  setUp(() {
    service = _GatedPermissionService();
    container = ProviderContainer(
      overrides: [photoPickerServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  });

  // Issue #1996: the picker is opened from a dive or a dive site, and a
  // selection that outlived its session arrived preselected in the next one.
  test('the selection ends with the picker session that made it', () async {
    final session = container.listen(photoPickerNotifierProvider, (_, _) {});
    container
        .read(photoPickerNotifierProvider.notifier)
        .toggleSelection('photo-1');
    expect(container.read(photoPickerNotifierProvider).selectedIds, {
      'photo-1',
    });

    session.close();
    await container.pump();

    expect(container.read(photoPickerNotifierProvider).selectedIds, isEmpty);
  });

  group('a permission call that outlives its session', () {
    // The page awaits these through logFailure, so a throw here would only
    // ever surface as a logged "Failed to check permission and load".
    Future<void> expectQuietAfterClose(
      Future<void> Function(PhotoPickerNotifier) call,
    ) async {
      final session = container.listen(photoPickerNotifierProvider, (_, _) {});
      final notifier = container.read(photoPickerNotifierProvider.notifier);
      final inFlight = call(notifier);
      session.close();
      await container.pump();
      expect(notifier.mounted, isFalse);

      service.gate.complete();
      await expectLater(inFlight, completes);
    }

    test('checkPermission completes quietly', () async {
      await expectQuietAfterClose((n) => n.checkPermission());
    });

    test('checkPermission completes quietly when the platform fails', () async {
      service.fail = true;
      await expectQuietAfterClose((n) => n.checkPermission());
    });

    test('requestPermission completes quietly', () async {
      await expectQuietAfterClose((n) => n.requestPermission());
    });

    test(
      'requestPermission completes quietly when the platform fails',
      () async {
        service.fail = true;
        await expectQuietAfterClose((n) => n.requestPermission());
      },
    );
  });
}
