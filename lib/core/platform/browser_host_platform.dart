/// What a browser tells the page about itself, read once from `navigator`.
///
/// A plain value so the composition in [BrowserHostPlatform] can be tested on
/// the VM with a fake, where `package:web` has no browser to ask.
class BrowserInfo {
  const BrowserInfo({
    required this.userAgent,
    required this.language,
    required this.hardwareConcurrency,
  });

  /// `navigator.userAgent`: the only description of the device a page gets.
  final String userAgent;

  /// `navigator.language`, a BCP 47 tag such as `en-GB`.
  final String language;

  /// `navigator.hardwareConcurrency`; browsers may report 0 or clamp it.
  final int hardwareConcurrency;
}

/// The host platform answers for a browser, composed from [BrowserInfo].
///
/// Every native platform flag is false: the app is running in a page, and
/// the capability layer decides what that page can do. The page has no
/// environment, no hostname and no executable.
class BrowserHostPlatform {
  const BrowserHostPlatform(this.info);

  final BrowserInfo info;

  bool get isWeb => true;
  bool get isAndroid => false;
  bool get isIOS => false;
  bool get isMacOS => false;
  bool get isWindows => false;
  bool get isLinux => false;
  bool get isApple => false;
  bool get isDesktop => false;
  bool get isMobile => false;

  Map<String, String> get environment => const {};
  String? get localHostname => null;
  String get operatingSystem => 'web';

  /// The user agent string: the nearest thing a page has to an OS version.
  String get operatingSystemVersion => info.userAgent;
  String get localeName => info.language;

  /// At least one, whatever the browser reports.
  int get numberOfProcessors =>
      info.hardwareConcurrency < 1 ? 1 : info.hardwareConcurrency;

  String get pathSeparator => '/';
  String get resolvedExecutable => '';
}
