import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// `flutter build web` compiles every library `lib/main.dart` reaches, and
/// these imports do not exist there: the Dart front end stops on the first
/// one. Each sits behind a facade whose native half is a `*_io.dart` file,
/// so that suffix is the one place they may appear. A new direct import
/// anywhere else fails here before it fails the web build.
void main() {
  const bannedOutsideIo = <String>[
    'dart:ffi',
    'package:ffi/',
    'package:sqlite3/sqlite3.dart',
    'package:drift/native.dart',
    'package:drift/isolate.dart',
    'package:mcp_dart/',
    'package:http/io_client.dart',
  ];

  /// `path_provider` compiles for the web but throws on every call, and its
  /// callers move to `AppDirectories` as the browser work reaches them. The
  /// importers that remain are listed so a new one fails the guard; the
  /// connect-and-capabilities plan shrinks this list.
  const pathProviderImporters = <String>{
    'lib/core/services/cloud_storage/git_storage_provider.dart',
    'lib/core/services/database_location_service.dart',
    'lib/core/services/database_service.dart',
    'lib/core/services/export/shared/file_export_utils.dart',
    'lib/core/services/files/picked_file_materializer.dart',
    'lib/core/services/local_cache_database_service.dart',
    'lib/core/services/sync/changeset_log/resumable_base_publish.dart',
    'lib/core/services/sync/changeset_log/sync_temp_dir.dart',
    'lib/features/backup/data/services/backup_service.dart',
    'lib/features/certifications/presentation/widgets/certification_share_sheet.dart',
    'lib/features/demo_mode/data/demo_paths.dart',
    'lib/features/documents/presentation/helpers/document_page_opener.dart',
    'lib/features/maps/data/services/tile_cache_service.dart',
    'lib/features/media/data/services/cached_network_image_diagnostics.dart',
    'lib/features/media/data/services/media_import_service.dart',
    'lib/features/media/data/services/media_share_temp_file.dart',
    'lib/features/media/data/services/scanned_logs_migration.dart',
    'lib/features/media/presentation/providers/media_resolver_providers.dart',
    'lib/features/media_store/presentation/providers/media_store_providers.dart',
    'lib/features/settings/presentation/pages/storage_settings_page.dart',
    'lib/features/settings/presentation/providers/debug_log_providers.dart',
    'lib/features/settings/presentation/providers/storage_gc_providers.dart',
    'lib/features/settings/presentation/providers/storage_usage_providers.dart',
  };

  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('.freezed.dart'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList()
        ..sort();

  List<String> importsOf(String path) {
    final text = MaskedSource(File(path).readAsStringSync()).text;
    return [
      for (final m in RegExp(
        r"^(?:import|export)\s+'([^']+)'",
        multiLine: true,
      ).allMatches(text))
        m.group(1)!,
    ];
  }

  final imports = {for (final path in files) path: importsOf(path)};

  test('the native seams still import what they seam', () {
    final ioFiles = [
      for (final path in files)
        if (path.endsWith('_io.dart') &&
            imports[path]!.any((uri) => bannedOutsideIo.any(uri.startsWith)))
          path,
    ];
    expect(
      ioFiles,
      isNotEmpty,
      reason: 'No *_io.dart file imports a seamed library; were they renamed?',
    );
  });

  test('no file outside a *_io.dart imports a library the web build lacks', () {
    final offenders = [
      for (final path in files)
        if (!path.endsWith('_io.dart'))
          for (final uri in imports[path]!)
            if (bannedOutsideIo.any(uri.startsWith)) '$path imports $uri',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Move the import into a *_io.dart file behind a conditional-export '
          'facade (see lib/core/platform/):\n${offenders.join('\n')}',
    );
  });

  test('path_provider is imported only where the allowlist says', () {
    final importers = [
      for (final path in files)
        if (!path.endsWith('_io.dart') &&
            imports[path]!.any(
              (uri) => uri.startsWith('package:path_provider/'),
            ))
          path,
    ];
    final unexpected = importers.where(
      (p) => !pathProviderImporters.contains(p),
    );
    expect(
      unexpected,
      isEmpty,
      reason:
          'New path_provider importers; read the directory through '
          'AppDirectories (lib/core/platform/app_directories.dart) instead:\n'
          '${unexpected.join('\n')}',
    );
    final stale = pathProviderImporters.where((p) => !importers.contains(p));
    expect(
      stale,
      isEmpty,
      reason:
          'Allowlisted files no longer import path_provider; remove them:\n'
          '${stale.join('\n')}',
    );
  });
}
