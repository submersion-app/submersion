/// Native variant: there is no origin storage and no page.
abstract final class BrowserOriginStorage {
  static const String forgetChannel = 'submersion-forget-device';

  static Future<void> removeEntry(String name) async =>
      throw UnsupportedError('origin private file system is browser only');

  static void reloadPage() =>
      throw UnsupportedError('reloading the page is browser only');

  static void announceForgotten() =>
      throw UnsupportedError('Forget this device is browser only');

  /// A native build has no other tabs to hear from.
  static void Function() onForgottenElsewhere(void Function() listener) =>
      () {};
}
