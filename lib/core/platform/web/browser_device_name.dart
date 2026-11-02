/// The name a browser peer shows on every other device (issue #4121):
/// `<Browser> on <OS>` read off the user agent, since a page has neither a
/// hostname nor a native identity. "Browser" when nothing is recognised,
/// the browser alone when only it is.
String browserDeviceName(String userAgent) {
  final browser = _browserOf(userAgent);
  final platform = _platformOf(userAgent);
  if (browser == null && platform == null) return 'Browser';
  if (platform == null) return browser!;
  return '${browser ?? 'Browser'} on $platform';
}

/// Order matters: Edge carries "Chrome", every Chromium browser carries
/// "Safari", and the iOS ports carry their own tokens.
String? _browserOf(String ua) {
  if (ua.contains('Edg/') || ua.contains('EdgA/') || ua.contains('EdgiOS/')) {
    return 'Edge';
  }
  if (ua.contains('Firefox/') || ua.contains('FxiOS/')) return 'Firefox';
  if (ua.contains('Chrome/') ||
      ua.contains('Chromium/') ||
      ua.contains('CriOS/')) {
    return 'Chrome';
  }
  if (ua.contains('Safari/') && ua.contains('Version/')) return 'Safari';
  return null;
}

/// Order matters here too: Android carries "Linux", and the iOS browsers
/// say "like Mac OS X".
String? _platformOf(String ua) {
  if (ua.contains('CrOS')) return 'ChromeOS';
  if (ua.contains('Windows')) return 'Windows';
  if (ua.contains('Android')) return 'Android';
  if (ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod')) {
    return 'iOS';
  }
  if (ua.contains('Mac OS X') || ua.contains('Macintosh')) return 'macOS';
  if (ua.contains('Linux') || ua.contains('X11')) return 'Linux';
  return null;
}
