/// Native variant: there is no origin storage and no page.
abstract final class BrowserOriginStorage {
  static Future<void> removeEntry(String name) async =>
      throw UnsupportedError('origin private file system is browser only');

  static void reloadPage() =>
      throw UnsupportedError('reloading the page is browser only');
}
