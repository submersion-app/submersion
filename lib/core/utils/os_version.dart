/// Lowest build number that is Windows 11.
///
/// Windows 10 stopped at build 19045 and the Windows 11 line opens at 22000,
/// so a single threshold separates them and always will: Windows 10 is out of
/// support and will never ship a higher build.
const _firstWindows11Build = 22000;

/// The `Windows 10` prefix inside the quoted product name, and only there.
///
/// Anchored to the opening quote so the `10` in the `10.0` NT version that
/// follows can never be rewritten, and closed by a lookahead so a product
/// name that merely starts with those characters is left alone.
final _windows10ProductName = RegExp(r'^"Windows 10(?=["\s])');

/// The build number Windows appends to its version string.
final _windowsBuildNumber = RegExp(r'\(Build (\d+)\)');

/// Correct the operating system version string a host reports about itself.
///
/// [platform] is a `Platform.operatingSystem` value and [version] the matching
/// `Platform.operatingSystemVersion`. Everything except Windows is passed
/// through untouched.
///
/// Windows 11 machines report themselves as Windows 10 (#1982). Dart builds
/// its version string from the `ProductName` registry value under
/// `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion`, and Microsoft
/// deliberately left that value reading `Windows 10 ...` on Windows 11 so
/// that software sniffing it would not break. The NT version stayed at `10.0`
/// for the same reason, which leaves the build number as the only field that
/// tells the two apart. So a diagnostics header that quotes Windows verbatim
/// misidentifies every Windows 11 machine, and the triager reading it is
/// misled about the very thing the header exists to establish.
///
/// Only the product name is rewritten, and only when the build number proves
/// the claim. Anything unrecognised degrades to [version] unchanged: a
/// slightly stale OS name is worth far more to a bug report than no OS at all.
String normalizeOsVersion({required String platform, required String version}) {
  if (platform != 'windows') return version;

  final match = _windowsBuildNumber.firstMatch(version);
  if (match == null) return version;

  // Returns null for a build number too long for an int, which is not a
  // build number at all.
  final build = int.tryParse(match.group(1)!);
  if (build == null || build < _firstWindows11Build) return version;

  return version.replaceFirst(_windows10ProductName, '"Windows 11');
}
