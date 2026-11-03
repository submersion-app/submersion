import 'package:path/path.dart' as p;

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/services/logger_service.dart';

/// The names a browser's library takes (issue #4121). The first library is
/// `kWebDatabasePath`; each restore installs the backup under a new name and
/// moves the browser's preference to it once it opens, so a tab closed
/// halfway leaves the old library in place. The names it replaced are swept
/// up on a later launch.

const String _directory = '/opfs/Submersion';

/// A library name: the first one, or a restored one with its time in it.
final RegExp _libraryName = RegExp(r'^submersion(_\d+)?$');

/// Where a restore made at [at] installs the backup.
String webRestoredLibraryPath(DateTime at) =>
    '$_directory/submersion_${at.millisecondsSinceEpoch}.db';

/// The libraries in [stored] (drift's database names) that the one at
/// [activePath] replaced. The local cache, the sample logbook and anything
/// else the browser stores keep their own names and are never listed.
Iterable<String> supersededWebLibraryNames(
  Iterable<String> stored, {
  required String activePath,
}) {
  final active = p.basenameWithoutExtension(activePath);
  return stored.where((name) => name != active && _libraryName.hasMatch(name));
}

const _log = LoggerService('WebLibrarySweep');

/// Deletes the libraries the one at [activePath] replaced, at launch and
/// best effort: a tab still holding one keeps it until a later launch, and
/// nothing here ever stops the app opening.
Future<void> sweepSupersededWebLibraries(
  String activePath, {
  Future<Set<String>> Function() listNames =
      BackgroundDatabaseConnection.storedDatabaseNames,
  Future<void> Function(String path) delete =
      BackgroundDatabaseConnection.deleteStoredDatabases,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final Set<String> stored;
  try {
    stored = await listNames();
  } catch (e, stackTrace) {
    _log.warning(
      'Could not list the stored libraries',
      error: e,
      stackTrace: stackTrace,
    );
    return;
  }
  for (final name in supersededWebLibraryNames(
    stored,
    activePath: activePath,
  )) {
    try {
      await delete('$_directory/$name.db').timeout(timeout);
    } catch (e, stackTrace) {
      _log.warning(
        'Could not delete the replaced library $name yet',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
