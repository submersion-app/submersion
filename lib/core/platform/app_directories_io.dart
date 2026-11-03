import 'package:path_provider/path_provider.dart';

/// Native implementation of the app directories facade: `path_provider`.
abstract final class AppDirectories {
  /// The application support directory: app-owned data the diver never sees.
  static Future<String> support() async =>
      (await getApplicationSupportDirectory()).path;

  /// The documents directory the platform gives the app.
  static Future<String> documents() async =>
      (await getApplicationDocumentsDirectory()).path;

  /// The platform's temporary directory for this app.
  static Future<String> temp() async => (await getTemporaryDirectory()).path;
}
