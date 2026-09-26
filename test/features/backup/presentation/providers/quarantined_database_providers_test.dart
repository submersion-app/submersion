import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:submersion/core/constants/app_directories.dart';
import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';
import 'package:submersion/features/backup/presentation/providers/quarantined_database_providers.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Exercises the real providers, which bind the service to the database
/// singleton's path. Every other test injects the path, so only this one
/// would notice the binding pointing somewhere else.
void main() {
  late Directory documents;
  late PathProviderPlatform realPathProvider;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    documents = await Directory.systemTemp.createTemp('quarantine_wiring_');
    realPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = realPathProvider;
    if (documents.existsSync()) await documents.delete(recursive: true);
  });

  test('lists copies beside the database the app is using', () async {
    final folder = await Directory(
      p.join(documents.path, kAppDocumentsFolder),
    ).create(recursive: true);
    await File(
      p.join(folder.path, 'submersion.db.pre-restore.20260926T134501Z'),
    ).writeAsString('not a database');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final copies = await container.read(quarantinedDatabasesProvider.future);

    expect(copies.map((c) => c.filename), [
      'submersion.db.pre-restore.20260926T134501Z',
    ]);
    expect(copies.single.status, QuarantinedDatabaseStatus.unreadable);
  });
}
