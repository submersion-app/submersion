import 'package:flutter/foundation.dart';

import 'package:submersion/core/platform/host_platform.dart';

/// Whether the device address book can be reached at all.
///
/// flutter_contacts ships iOS and Android implementations only. Lifted out of
/// `buddy_list_content.dart` so the buddy import flow and the profile photo
/// source sheet cannot drift apart on which platforms they offer contacts on.
bool get isContactImportSupported {
  if (HostPlatform.isWeb) return false;
  // defaultTargetPlatform rather than dart:io's Platform, so this compiles
  // for web and so tests can drive the mobile branch through
  // debugDefaultTargetPlatformOverride.
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
}
