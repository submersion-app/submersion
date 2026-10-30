import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where demo mode keeps everything it creates. All of it lives in one
/// directory under the app support directory, so exiting can remove every
/// trace by deleting [root], and the user's own database (in Documents or a
/// custom folder) is never near it.
class DemoPaths {
  const DemoPaths(this.supportDir);

  final String supportDir;

  String get root => p.join(supportDir, 'demo_mode');

  String get stateFile => p.join(root, 'state.json');

  String get prefsSnapshotFile => p.join(root, 'prefs_snapshot.json');

  String get packageFile => p.join(root, 'package.zip');

  String get databaseFile => p.join(root, 'submersion_demo.db');

  String get photosDir => p.join(root, 'photos');

  static Future<DemoPaths> resolve() async =>
      DemoPaths((await getApplicationSupportDirectory()).path);
}
