// The restore picker moved to file_picker 12's `pickFile()`, whose
// PlatformFile has a nullable `path` (null for an Android SAF content URI).
// These cover the three outcomes the notifier has to distinguish without
// reaching the real database restore.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;
  late ProviderContainer container;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('export_restore_pick_test');
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
    // ExportNotifier localizes its status messages, and localeProvider
    // watches settingsProvider, which wants SharedPreferences and a
    // database. Pin the locale so this test stays about the picker.
    container = ProviderContainer(
      overrides: [localeProvider.overrideWithValue('en')],
    );
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    container.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  ExportNotifier notifier() => container.read(exportNotifierProvider.notifier);

  test('a cancelled pick returns to idle', () async {
    picker.pickFilesResult = const [];

    await notifier().restoreBackup();

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.idle);
    expect(state.message, 'Restore cancelled');
  });

  test('a pick with no local path is reported, not silently ignored', () async {
    // An Android SAF pick: `path` is null because the Uri is content://.
    picker.pickFilesResult = [
      FakePlatformFile.contentUri(
        Uri.parse('content://downloads/doc/9'),
        name: 'backup.db',
      ),
    ];

    await notifier().restoreBackup();

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.error);
    expect(state.message, 'Could not access file');
  });

  test('a non-.db selection is rejected before any restore runs', () async {
    final wrong = File('${tmp.path}/notes.txt');
    await wrong.writeAsString('not a backup');
    picker.pickFilesResult = [FakePlatformFile(wrong.path)];

    await notifier().restoreBackup();

    final state = container.read(exportNotifierProvider);
    expect(state.status, ExportStatus.error);
    expect(state.message, 'Please select a .db backup file');
  });
}
