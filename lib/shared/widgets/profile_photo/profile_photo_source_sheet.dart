import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a profile photo comes from.
enum ProfilePhotoSource { camera, library, contacts, remove }

/// Asks the user where the profile photo should come from.
///
/// Returns null if the sheet was dismissed without a choice.
///
/// Opened from a page's own build context, never from a dialog action:
/// `showModalBottomSheet` defaults to `useRootNavigator: false`, so a sheet
/// opened from inside a dialog would land on the shell navigator and paint
/// underneath that dialog's barrier (issue #1366).
Future<ProfilePhotoSource?> showProfilePhotoSourceSheet({
  required BuildContext context,
  required bool hasPhoto,
  required bool allowContacts,
}) {
  // defaultTargetPlatform rather than dart:io's Platform: web-safe, and
  // overridable in tests so the camera option can actually be exercised.
  final isMobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  return showModalBottomSheet<ProfilePhotoSource>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.profilePhoto_sheet_title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            if (isMobile)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.profilePhoto_source_camera),
                onTap: () =>
                    Navigator.pop(sheetContext, ProfilePhotoSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                isMobile
                    ? l10n.profilePhoto_source_library
                    : l10n.profilePhoto_source_file,
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, ProfilePhotoSource.library),
            ),
            if (allowContacts)
              ListTile(
                leading: const Icon(Icons.contacts),
                title: Text(l10n.profilePhoto_source_contacts),
                onTap: () =>
                    Navigator.pop(sheetContext, ProfilePhotoSource.contacts),
              ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.profilePhoto_action_remove),
                onTap: () =>
                    Navigator.pop(sheetContext, ProfilePhotoSource.remove),
              ),
          ],
        ),
      );
    },
  );
}
