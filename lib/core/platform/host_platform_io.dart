import 'dart:io';

/// Native implementation of the host platform facade: `dart:io`'s
/// `Platform`, read at call time so a test that fakes the platform through
/// `dart:io` sees the same answers the app does.
abstract final class HostPlatform {
  /// Never a browser on a native build.
  static bool get isWeb => false;

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;

  /// iOS or macOS.
  static bool get isApple => isIOS || isMacOS;

  /// macOS, Windows or Linux.
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Android or iOS.
  static bool get isMobile => isAndroid || isIOS;

  static Map<String, String> get environment => Platform.environment;
  static String? get localHostname => Platform.localHostname;
  static String get operatingSystem => Platform.operatingSystem;
  static String get operatingSystemVersion => Platform.operatingSystemVersion;
  static String get localeName => Platform.localeName;
  static int get numberOfProcessors => Platform.numberOfProcessors;
  static String get pathSeparator => Platform.pathSeparator;
  static String get resolvedExecutable => Platform.resolvedExecutable;
}
