import 'dart:io' show Platform;

import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';

/// Public enrollment links for the beta program. An empty link hides the
/// corresponding Join-the-Beta tile.
///
const kTestFlightBetaUrl = 'https://testflight.apple.com/join/aMD393sB';
const kPlayBetaOptInUrl = 'https://play.google.com/apps/testing/app.submersion';

/// The store beta-enrollment link to offer on this build, or null when there
/// is none.
String? get betaEnrollUrl => betaEnrollUrlFor(
  isIOS: Platform.isIOS,
  isMacOS: Platform.isMacOS,
  isAndroid: Platform.isAndroid,
  autoUpdateEnabled: UpdateChannelConfig.isAutoUpdateEnabled,
);

/// The rule behind [betaEnrollUrl], with the host platform and the updater
/// state passed in rather than read from the environment.
///
/// Only store builds are offered a link. A build with its own updater picks
/// its channel in Settings > Updates > Update channel, so pointing it at a
/// store testing program would be a dead end: that is what the sideloaded
/// Android APK did, offering the Play opt-in page for an app that is not
/// listed on Play (#1258).
String? betaEnrollUrlFor({
  required bool isIOS,
  required bool isMacOS,
  required bool isAndroid,
  required bool autoUpdateEnabled,
}) {
  if (autoUpdateEnabled) return null;
  if (isIOS || isMacOS) return _orNull(kTestFlightBetaUrl);
  if (isAndroid) return _orNull(kPlayBetaOptInUrl);
  return null;
}

/// An empty constant means the program is not live yet, which reads as "no
/// link" rather than as a link to nowhere.
String? _orNull(String url) => url.isEmpty ? null : url;
