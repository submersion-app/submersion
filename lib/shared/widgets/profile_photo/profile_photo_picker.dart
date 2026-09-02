import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_dialog.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_source_sheet.dart';

/// Outcome of running the profile photo flow.
///
/// [removed] distinguishes "the user asked to delete the photo" from "the user
/// cancelled", which a bare `Uint8List?` cannot express.
@immutable
class ProfilePhotoResult {
  const ProfilePhotoResult({this.bytes, this.removed = false});

  final Uint8List? bytes;
  final bool removed;
}

/// Runs the whole flow: source sheet, byte acquisition, crop dialog, encode.
///
/// Returns null if the user cancelled at any point.
///
/// Size bounding happens in the crop dialog's encode step, never through
/// ImagePicker's maxWidth / maxHeight / imageQuality: image_picker_macos,
/// image_picker_windows and image_picker_linux all document that those
/// arguments are silently ignored, so a desktop pick would be unbounded.
///
/// [contactPhotoLoader] is supplied by callers that can reach the address
/// book, which keeps this shared widget free of a flutter_contacts dependency.
///
/// [pickImageOverride] is a test seam replacing the platform image picker,
/// which has no Dart-side entry point a fake can be injected through. Mirrors
/// [OcrScanPage.pickImageOverride].
Future<ProfilePhotoResult?> pickProfilePhoto({
  required BuildContext context,
  required bool hasPhoto,
  required bool allowContacts,
  Future<Uint8List?> Function(BuildContext context)? contactPhotoLoader,
  @visibleForTesting
  Future<({Uint8List bytes, String name})?> Function(ImageSource source)?
  pickImageOverride,
}) async {
  // Offering Contacts without a loader would show a menu item that silently
  // does nothing when tapped, which reads as a broken flow. The two are
  // therefore gated together rather than independently.
  final source = await showProfilePhotoSourceSheet(
    context: context,
    hasPhoto: hasPhoto,
    allowContacts: allowContacts && contactPhotoLoader != null,
  );
  if (source == null || !context.mounted) return null;

  if (source == ProfilePhotoSource.remove) {
    return const ProfilePhotoResult(removed: true);
  }

  Uint8List? raw;
  String? declaredName;

  if (source == ProfilePhotoSource.contacts) {
    // Unreachable without a loader, since the option is gated above.
    raw = await contactPhotoLoader!(context);
    // No declaredName: the address book gives no filename and a contact photo
    // is not guaranteed to be JPEG. decodeNamedImage picks the decoder purely
    // by extension with no fallback, so claiming '.jpg' over PNG bytes would
    // hand them to the JPEG decoder and report a valid photo as undecodable.
    // Null makes the codec probe the actual bytes.
    declaredName = null;
    if (raw == null) return null;
  } else {
    final imageSource = source == ProfilePhotoSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final ({Uint8List bytes, String name})? picked;
    if (pickImageOverride != null) {
      picked = await pickImageOverride(imageSource);
    } else {
      final file = await ImagePicker().pickImage(source: imageSource);
      // Read through the XFile handle, not File(file.path). A picked file is
      // a HANDLE: on Android SAF the path can be unusable, and image_picker
      // makes no promise it addresses a real filesystem entry.
      picked = file == null
          ? null
          : (bytes: await file.readAsBytes(), name: file.name);
    }
    if (picked == null) return null;
    raw = picked.bytes;
    declaredName = picked.name;
  }

  if (!context.mounted) return null;

  final encoded = await showProfilePhotoCropDialog(
    context: context,
    sourceBytes: raw,
    declaredName: declaredName,
  );
  if (encoded == null) return null;
  return ProfilePhotoResult(bytes: encoded);
}
