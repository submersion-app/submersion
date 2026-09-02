import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Photo properties worth asking the address book for.
///
/// Full resolution first, thumbnail as a fallback: a contact thumbnail is
/// typically only 96x96 or 150x150, well under the 512 the codec stores, so it
/// is a last resort rather than a preference.
const contactPhotoProperties = {
  ContactProperty.photoFullRes,
  ContactProperty.photoThumbnail,
};

/// Ensures contacts read permission, but only where the platform needs it.
///
/// `FlutterContacts.native.showPicker` is permissionless on both platforms.
/// Asking it for properties always works on iOS, and on Android throws a
/// PlatformException without READ_CONTACTS. So Android asks and iOS does not,
/// which keeps the iOS build free of an address-book prompt it does not need.
Future<bool> ensureContactPropertyAccess() async {
  // defaultTargetPlatform rather than dart:io's Platform. kIsWeb is checked
  // first because a mobile browser reports iOS or android here.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  if (await FlutterContacts.permissions.has(PermissionType.read)) return true;
  await FlutterContacts.permissions.request(PermissionType.read);
  return FlutterContacts.permissions.has(PermissionType.read);
}

/// Opens the native contact picker and returns the chosen contact's photo.
///
/// Returns null when the user cancels, denies permission, or picks a contact
/// with no photo. The last case is common and is reported as a plain message
/// rather than an error.
/// Test seam: replaces the native contact picker, which is a static entry
/// point with no place to inject a fake. Returns the picked contact, or null
/// when the user cancels.
typedef ContactPickerFn = Future<Contact?> Function();

Future<Uint8List?> loadContactPhoto(
  BuildContext context, {
  @visibleForTesting ContactPickerFn? pickContactOverride,
  @visibleForTesting Future<bool> Function()? ensureAccessOverride,
}) async {
  final ensureAccess = ensureAccessOverride ?? ensureContactPropertyAccess;
  if (!await ensureAccess()) {
    // Silence here reads as a broken menu action: the user tapped "Choose
    // from Contacts" and nothing happened. The buddy import flow already
    // explains itself with this same string, so say the same thing.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Photo-specific wording: this path is reached from "Choose from
          // Contacts" in the profile photo sheet, where the buddy-import
          // string ("...to import buddies") describes the wrong action.
          content: Text(context.l10n.profilePhoto_error_contactPermission),
        ),
      );
    }
    return null;
  }

  final Contact? contact;
  try {
    contact = pickContactOverride != null
        ? await pickContactOverride()
        : await FlutterContacts.native.showPicker(
            properties: contactPhotoProperties,
          );
  } on PlatformException {
    // Android without READ_CONTACTS refuses the property fetch. Treated as a
    // cancel rather than an error: the user was not promised a photo.
    return null;
  }

  final bytes = contact?.photo?.fullSize ?? contact?.photo?.thumbnail;

  if (contact != null && bytes == null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.profilePhoto_error_contactNoPhoto)),
    );
  }
  return bytes;
}
