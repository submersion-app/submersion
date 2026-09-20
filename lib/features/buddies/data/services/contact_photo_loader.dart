import 'dart:async';

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

/// Whether the address book can be read, and if not, what the user can do.
///
/// The distinction matters because the two refusals need different UI: a
/// plain denial will prompt again next time, so offering a trip to system
/// settings would be noise, while a permanent one never prompts again and
/// leaves settings as the only way back.
enum ContactAccessOutcome {
  /// Properties can be read.
  granted,

  /// Refused, but the system will ask again on the next attempt.
  denied,

  /// Refused for good, or blocked by policy. Only system settings can undo it.
  permanentlyDenied,
}

/// Test seam: stands in for the real permission probe, which talks to a
/// platform channel that widget tests have no way to answer.
typedef ContactAccessProbeFn = Future<ContactAccessOutcome> Function();

/// Ensures contacts read permission, but only where the platform needs it.
///
/// `FlutterContacts.native.showPicker` is permissionless on both platforms.
/// Asking it for properties always works on iOS, and on Android needs
/// READ_CONTACTS, which `android/app/src/main/AndroidManifest.xml` declares
/// (#2191). So Android asks and iOS does not, which keeps the iOS build free
/// of an address-book prompt it does not need.
Future<ContactAccessOutcome> ensureContactPropertyAccess() async {
  // defaultTargetPlatform rather than dart:io's Platform. kIsWeb is checked
  // first because a mobile browser reports iOS or android here.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return ContactAccessOutcome.granted;
  }
  if (await FlutterContacts.permissions.has(PermissionType.read)) {
    return ContactAccessOutcome.granted;
  }
  // The request's own status is what carries the permanent refusal: the
  // plugin derives it from shouldShowRequestPermissionRationale at the moment
  // the dialog resolves, and a follow-up `has()` call cannot recover it.
  final status = await FlutterContacts.permissions.request(PermissionType.read);
  return switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited => ContactAccessOutcome.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => ContactAccessOutcome.permanentlyDenied,
    PermissionStatus.denied ||
    PermissionStatus.notDetermined => ContactAccessOutcome.denied,
  };
}

/// Leaves for the system settings page so the user can grant the permission.
void _openAppSettings() {
  // Fire and forget: the user is on their way out to another activity, and
  // there is nothing useful to do when the intent resolves.
  unawaited(FlutterContacts.permissions.openSettings());
}

/// Ensures address-book access, explaining any refusal in a snackbar.
///
/// Returns true when the caller may go on to read contact properties.
/// [deniedMessage] is the caller's own wording, because "choose a photo" and
/// "import buddies" describe different actions to a user who just said no.
///
/// The two overrides are test seams, but they are deliberately not marked
/// `@visibleForTesting`: every caller is production code forwarding a seam of
/// its own, and the annotation would flag those forwards as misuse.
Future<bool> ensureContactAccessOrExplain(
  BuildContext context, {
  required String deniedMessage,
  ContactAccessProbeFn? ensureAccessOverride,
  VoidCallback? openSettingsOverride,
}) async {
  final outcome = await (ensureAccessOverride ?? ensureContactPropertyAccess)();
  if (outcome == ContactAccessOutcome.granted) return true;

  // Silence here reads as a broken menu action: the user tapped "Choose from
  // Contacts" and nothing happened.
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deniedMessage),
        // Only offered when the system will not ask again. After a first
        // refusal the next tap re-prompts, so a settings trip would send the
        // user somewhere they do not need to go.
        action: outcome == ContactAccessOutcome.permanentlyDenied
            ? SnackBarAction(
                label: context.l10n.common_action_openSettings,
                onPressed: openSettingsOverride ?? _openAppSettings,
              )
            : null,
      ),
    );
  }
  return false;
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
  @visibleForTesting ContactAccessProbeFn? ensureAccessOverride,
  @visibleForTesting VoidCallback? openSettingsOverride,
}) async {
  final allowed = await ensureContactAccessOrExplain(
    context,
    // Photo-specific wording: this path is reached from "Choose from
    // Contacts" in the profile photo sheet, where the buddy-import string
    // ("...to import buddies") describes the wrong action.
    deniedMessage: context.l10n.profilePhoto_error_contactPermission,
    ensureAccessOverride: ensureAccessOverride,
    openSettingsOverride: openSettingsOverride,
  );
  if (!allowed) return null;

  final Contact? contact;
  try {
    contact = pickContactOverride != null
        ? await pickContactOverride()
        : await FlutterContacts.native.showPicker(
            properties: contactPhotoProperties,
          );
  } on PlatformException {
    // Android refuses the property fetch without READ_CONTACTS held. The
    // manifest declares it and the check above secures the grant, so this
    // covers the races the check cannot: a permission revoked from settings
    // while the app is alive, or a policy restriction applied mid-session.
    // Treated as a cancel rather than an error: the user was not promised a
    // photo.
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
