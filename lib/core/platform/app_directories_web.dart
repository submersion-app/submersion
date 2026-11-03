/// Browser implementation of the app directories facade.
///
/// The names are virtual: nothing on the web reads them as filesystem paths.
/// The browser database and temporary files address the origin private file
/// system by name, and these constants exist so code that joins a path for a
/// log line or a cache key has something stable to join.
abstract final class AppDirectories {
  static const String supportPath = '/opfs/support';
  static const String documentsPath = '/opfs/documents';
  static const String tempPath = '/opfs/temp';

  /// The virtual support directory.
  static Future<String> support() async => supportPath;

  /// The virtual documents directory.
  static Future<String> documents() async => documentsPath;

  /// The virtual temporary directory.
  static Future<String> temp() async => tempPath;
}
