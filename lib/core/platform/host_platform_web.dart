import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/browser_host_platform.dart';

/// Browser implementation of the host platform facade.
///
/// The answers are composed in [BrowserHostPlatform]; this file only reads
/// `navigator` through `package:web`, once, so the composition can be tested
/// on the VM.
abstract final class HostPlatform {
  static final BrowserHostPlatform _browser = BrowserHostPlatform(
    BrowserInfo(
      userAgent: web.window.navigator.userAgent,
      language: web.window.navigator.language,
      hardwareConcurrency: web.window.navigator.hardwareConcurrency,
    ),
  );

  static bool get isWeb => _browser.isWeb;
  static bool get isAndroid => _browser.isAndroid;
  static bool get isIOS => _browser.isIOS;
  static bool get isMacOS => _browser.isMacOS;
  static bool get isWindows => _browser.isWindows;
  static bool get isLinux => _browser.isLinux;
  static bool get isApple => _browser.isApple;
  static bool get isDesktop => _browser.isDesktop;
  static bool get isMobile => _browser.isMobile;

  static Map<String, String> get environment => _browser.environment;
  static String? get localHostname => _browser.localHostname;
  static String get operatingSystem => _browser.operatingSystem;
  static String get operatingSystemVersion => _browser.operatingSystemVersion;
  static String get localeName => _browser.localeName;
  static int get numberOfProcessors => _browser.numberOfProcessors;
  static String get pathSeparator => _browser.pathSeparator;
  static String get resolvedExecutable => _browser.resolvedExecutable;
}
