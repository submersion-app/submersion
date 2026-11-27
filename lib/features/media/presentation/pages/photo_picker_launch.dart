import 'package:flutter/material.dart';

import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';

/// Shows the photo picker as a full-screen modal.
///
/// Returns the list of selected [AssetInfo] objects, or null if cancelled.
/// [initialFilePaths] opens it on the Files tab with those files staged; see
/// [PhotoPickerPage.initialFilePaths]. [loadAssets] replaces the Gallery
/// tab's date range search; see [PhotoPickerPage.loadAssets].
Future<List<AssetInfo>?> showPhotoPicker({
  required BuildContext context,
  required DateTime diveStartTime,
  required DateTime diveEndTime,
  Set<String> alreadyLinkedIds = const {},
  Duration buffer = const Duration(minutes: 30),
  MediaAttachTarget? target,
  List<String>? initialFilePaths,
  Future<List<AssetInfo>> Function(bool Function() isActive)? loadAssets,
  MediaHoldSink? onHold,
  bool galleryOnly = false,
}) {
  // Nothing comes in while demo mode is on (#3708): the note, not a picker.
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) {
    return Future<List<AssetInfo>?>.value();
  }
  final startTime = diveStartTime.subtract(buffer);
  final endTime = diveEndTime.add(buffer);

  return Navigator.of(context).push<List<AssetInfo>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      // With [onHold], the tabs hand a sitting what they would write.
      builder: (context) => MediaHoldScope.wrap(
        onHold,
        PhotoPickerPage(
          startTime: startTime,
          endTime: endTime,
          alreadyLinkedIds: alreadyLinkedIds,
          target: target,
          initialFilePaths: initialFilePaths,
          loadAssets: loadAssets,
          galleryOnly: galleryOnly,
        ),
      ),
    ),
  );
}
