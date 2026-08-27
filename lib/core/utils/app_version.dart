import 'package:package_info_plus/package_info_plus.dart';

/// Format the app version the way the project displays it everywhere: the
/// three-segment marketing version with the build number appended as a fourth
/// segment (`1.7.6.123`).
///
/// Release tags are four-segment (`vX.Y.Z.N`) while `PackageInfo.version` is
/// the three-segment marketing version, so the build number has to be appended
/// for a version string to be comparable with a tag. Some platforms already
/// report a four-segment version, hence the guard against doubling it.
String formatAppVersion(PackageInfo info) =>
    formatVersionWithBuild(info.version, info.buildNumber);

/// [formatAppVersion] without the PackageInfo dependency, for callers that
/// already hold the two parts separately.
String formatVersionWithBuild(String version, String buildNumber) {
  if (buildNumber.isEmpty) return version;
  if (version.endsWith('.$buildNumber')) return version;
  return '$version.$buildNumber';
}
