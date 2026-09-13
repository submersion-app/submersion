import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// OAuth client configuration for the Google Photos connector.
///
/// The connector reads a user's Google Photos library through the
/// [Photos Picker API](https://developers.google.com/photos/picker/guides/get-started):
/// the app opens a Google-hosted picker, the user chooses the photos, and
/// the app downloads exactly those. Since March 31 2025 this is the only
/// way a third-party app can reach photos it did not itself upload -- the
/// old `photoslibrary.readonly` scope was removed -- so there is no
/// album-listing or background-watch capability to configure here.
///
/// Only client IDs are committed. OAuth client IDs are public identifiers,
/// safe to commit; the Desktop client's secret is NOT committed and arrives
/// at build time (see [desktopClientSecret]). This mirrors
/// `GoogleDriveClientConfig` deliberately -- both clients must live in the
/// same Google Cloud project as the Drive clients so a single OAuth consent
/// screen covers the whole app.
class GooglePhotosClientConfig {
  /// The single scope the connector needs: read-only access to the media
  /// items the user picks in the Google-hosted picker.
  static const String pickerScope =
      'https://www.googleapis.com/auth/photospicker.mediaitems.readonly';

  /// OAuth 2.0 "Desktop app" client used by the loopback flow on Windows,
  /// Linux, and the Developer ID macOS build. Empty until the client is
  /// created in the Google Cloud console; an empty value disables the
  /// Google Photos connector on desktop instead of crashing.
  static const String desktopClientId = String.fromEnvironment(
    'GOOGLE_PHOTOS_DESKTOP_CLIENT_ID',
  );

  /// "iOS" / "Web application" client ID used by the mobile and sandboxed
  /// macOS builds through `google_sign_in`. Empty means the connector is
  /// not offered on those platforms yet.
  static const String mobileClientId = String.fromEnvironment(
    'GOOGLE_PHOTOS_MOBILE_CLIENT_ID',
  );

  /// Secret for [desktopClientId], supplied at build time by
  /// `--dart-define=GOOGLE_PHOTOS_CLIENT_SECRET=...` and never committed.
  ///
  /// Google documents that an installed-app client secret is not treated as
  /// confidential -- it ships inside every desktop binary by design -- but
  /// it stays out of the repository so secret scanning has nothing to block
  /// and forks do not inherit this project's client.
  static const String desktopClientSecret = String.fromEnvironment(
    'GOOGLE_PHOTOS_CLIENT_SECRET',
  );

  /// True when BOTH halves of the Desktop-app client are present in this
  /// build. Split out so the rule is testable without a `--dart-define`.
  @visibleForTesting
  static bool desktopClientConfigured(String id, String secret) =>
      id.isNotEmpty && secret.isNotEmpty;

  /// True when the Desktop-app client is fully configured in this build.
  static bool get hasDesktopClient =>
      desktopClientConfigured(desktopClientId, desktopClientSecret);

  /// Whether the Google Photos connector can be offered on the current
  /// platform/build.
  ///
  /// iOS / Android / macOS resolve their client at compile time through
  /// `google_sign_in` (no secret needed), gated only on [mobileClientId];
  /// Windows / Linux need the compiled-in Desktop-app client.
  static bool get isSupportedOnThisPlatform =>
      (Platform.isWindows || Platform.isLinux)
      ? hasDesktopClient
      : mobileClientId.isNotEmpty || hasDesktopClient;
}
