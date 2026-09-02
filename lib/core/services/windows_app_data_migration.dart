import 'dart:io';

import 'package:path/path.dart' as p;

/// The `CompanyName` the Windows runner shipped with through v1.7.5. It came
/// from the Flutter template and was never changed, so `path_provider_windows`
/// placed every Windows user's application-support and cache data under the
/// developer's personal name.
const legacyWindowsCompanyName = 'Eric Griffin';

/// The `CompanyName` in `windows/runner/Runner.rc`. These two MUST stay in
/// sync: `path_provider_windows` reads the value out of the executable's
/// VERSIONINFO resource via `VerQueryValue`, not from anything in Dart, and
/// this migration has to be able to name the directory that produces.
const windowsCompanyName = 'Submersion';

/// The `ProductName` in `windows/runner/Runner.rc`, unchanged.
const windowsProductName = 'submersion';

/// What a single company-directory migration attempt did.
enum AppDataMigrationOutcome {
  /// No legacy directory on disk. The overwhelmingly common case: a fresh
  /// install, or a machine that already migrated on an earlier launch.
  noLegacyData,

  /// Legacy and target resolve to the same directory, so there is nothing to
  /// move.
  notNeeded,

  /// The target already holds data. The legacy tree is left alone rather than
  /// clobbering whatever the user has been using.
  targetAlreadyPopulated,

  /// Renamed atomically. The legacy directory is gone.
  moved,

  /// Rename failed, so the tree was copied. The legacy directory is retained.
  copied,

  /// Nothing was moved and the legacy directory is untouched.
  failed,
}

/// The result of one migration attempt, including the paths considered so a
/// debug log can show exactly which directories were involved.
class AppDataMigrationReport {
  const AppDataMigrationReport({
    required this.outcome,
    required this.legacyPath,
    required this.targetPath,
    this.error,
  });

  final AppDataMigrationOutcome outcome;
  final String legacyPath;
  final String targetPath;
  final Object? error;

  @override
  String toString() =>
      'AppDataMigrationReport(${outcome.name}, legacy: $legacyPath, '
      'target: $targetPath${error == null ? '' : ', error: $error'})';
}

Future<Directory> _defaultRename(Directory source, String targetPath) =>
    source.rename(targetPath);

/// Moves `<rootPath>/<legacyCompany>/<product>` to
/// `<rootPath>/<company>/<product>`.
///
/// Never throws: a failure is reported as [AppDataMigrationOutcome.failed] with
/// the legacy directory left exactly as it was found. This runs during startup
/// before anything has opened a file, so a thrown error here would be a blank
/// app rather than a lost setting.
///
/// [rename] is injectable so the copy fallback is reachable from a test on a
/// POSIX host, where a rename within one filesystem always succeeds.
Future<AppDataMigrationReport> migrateCompanyDirectory({
  required String rootPath,
  required String legacyCompany,
  required String company,
  required String product,
  Future<Directory> Function(Directory source, String targetPath)? rename,
}) async {
  final legacyPath = p.join(rootPath, legacyCompany, product);
  final targetPath = p.join(rootPath, company, product);

  // Windows filenames are case-insensitive, so a company name differing only in
  // case names the same directory and a "move" would be a self-rename.
  if (legacyCompany.toLowerCase() == company.toLowerCase()) {
    return AppDataMigrationReport(
      outcome: AppDataMigrationOutcome.notNeeded,
      legacyPath: legacyPath,
      targetPath: targetPath,
    );
  }

  final legacyDir = Directory(legacyPath);
  final targetDir = Directory(targetPath);

  try {
    if (!await legacyDir.exists()) {
      return AppDataMigrationReport(
        outcome: AppDataMigrationOutcome.noLegacyData,
        legacyPath: legacyPath,
        targetPath: targetPath,
      );
    }

    if (await targetDir.exists()) {
      if (!await _isEmpty(targetDir)) {
        return AppDataMigrationReport(
          outcome: AppDataMigrationOutcome.targetAlreadyPopulated,
          legacyPath: legacyPath,
          targetPath: targetPath,
        );
      }
      // An empty target is an artefact of a previous launch that created the
      // directory without writing anything. Clear it so the rename can land.
      await targetDir.delete();
    }

    await Directory(p.dirname(targetPath)).create(recursive: true);

    try {
      await (rename ?? _defaultRename)(legacyDir, targetPath);
      return AppDataMigrationReport(
        outcome: AppDataMigrationOutcome.moved,
        legacyPath: legacyPath,
        targetPath: targetPath,
      );
    } catch (_) {
      // Rename can fail across volumes or when another process holds a handle
      // on something in the tree. Fall back to a copy.
      //
      // The copy lands in a staging sibling and is renamed into place, never
      // directly into the target. A copy is not atomic, and a half-copied
      // target would look populated to the next launch: the migration would
      // report targetAlreadyPopulated forever while the app ran on partial
      // data and the real settings sat stranded under the legacy name. Staging
      // keeps the target all-or-nothing. The promotion is also a rename WITHIN
      // the new company directory, so it is same-volume even when the original
      // rename failed because it crossed volumes.
      final staging = Directory('$targetPath.migrating');
      await _deleteQuietly(staging); // leftover from an interrupted attempt
      try {
        await _copyTree(legacyDir, staging);
        await staging.rename(targetPath);
      } catch (_) {
        await _deleteQuietly(staging);
        rethrow;
      }
      // The legacy tree is deliberately retained. The target is now complete,
      // so the next launch no-ops on it; keeping the source costs disk and
      // buys a manual recovery path.
      return AppDataMigrationReport(
        outcome: AppDataMigrationOutcome.copied,
        legacyPath: legacyPath,
        targetPath: targetPath,
      );
    }
  } catch (e) {
    return AppDataMigrationReport(
      outcome: AppDataMigrationOutcome.failed,
      legacyPath: legacyPath,
      targetPath: targetPath,
      error: e,
    );
  }
}

/// Best effort removal. Used only for staging leftovers, where a failure to
/// clean up must not mask the real error or abort the migration.
Future<void> _deleteQuietly(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // A stale staging directory is harmless; the next attempt overwrites it.
  }
}

Future<bool> _isEmpty(Directory dir) async =>
    await dir.list(followLinks: false).isEmpty;

Future<void> _copyTree(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entity in from.list(followLinks: false)) {
    final destination = p.join(to.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyTree(entity, Directory(destination));
    } else if (entity is File) {
      await entity.copy(destination);
    }
    // Links are skipped: nothing the app writes under app-support is a link.
  }
}

/// Relocates the Windows roaming and local app-data trees off the legacy
/// company name.
///
/// Must run before ANY other code touches those directories. In particular it
/// has to precede `SharedPreferences.getInstance()`: on Windows
/// `shared_preferences_windows` resolves its file through
/// `PathProviderWindows.getApplicationSupportPath()`, so reading prefs first
/// would create an empty file at the new path, leave the user's real settings
/// stranded, and make the target look populated to this migration.
///
/// The database is NOT affected -- it lives under
/// `getApplicationDocumentsDirectory()`, which has no company component.
///
/// Returns an empty list off Windows. Never throws.
Future<List<AppDataMigrationReport>> migrateWindowsAppDataDirectories() async {
  if (!Platform.isWindows) return const <AppDataMigrationReport>[];

  // APPDATA backs getApplicationSupportDirectory (FOLDERID_RoamingAppData);
  // LOCALAPPDATA backs getApplicationCacheDirectory (FOLDERID_LocalAppData).
  const roots = ['APPDATA', 'LOCALAPPDATA'];

  final reports = <AppDataMigrationReport>[];
  for (final variable in roots) {
    final root = Platform.environment[variable];
    if (root == null || root.isEmpty) continue;
    reports.add(
      await migrateCompanyDirectory(
        rootPath: root,
        legacyCompany: legacyWindowsCompanyName,
        company: windowsCompanyName,
        product: windowsProductName,
      ),
    );
  }
  return reports;
}
