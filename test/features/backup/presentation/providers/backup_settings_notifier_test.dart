import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

void main() {
  late BackupSettingsNotifier notifier;
  late BackupPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    notifier = BackupSettingsNotifier(prefs);
  });

  group('cloud backup and custom location are mutually exclusive', () {
    test('cloud backup starts disabled', () {
      expect(notifier.state.cloudBackupEnabled, isFalse);
    });

    test('enabling cloud backup clears a custom backup location', () async {
      await notifier.setBackupLocation('/custom/path');
      await notifier.setCloudBackupEnabled(true);

      expect(notifier.state.cloudBackupEnabled, isTrue);
      expect(notifier.state.backupLocation, isNull);
      expect(prefs.getSettings().backupLocation, isNull);
    });

    test('choosing a custom location turns cloud backup off', () async {
      await notifier.setCloudBackupEnabled(true);
      await notifier.setBackupLocation('/custom/path');

      expect(notifier.state.cloudBackupEnabled, isFalse);
      expect(notifier.state.backupLocation, '/custom/path');
      expect(prefs.getSettings().cloudBackupEnabled, isFalse);
    });

    test(
      'clearing the location back to default keeps cloud backup state',
      () async {
        await notifier.setBackupLocation('/custom/path');
        await notifier.setBackupLocation(null);

        expect(notifier.state.backupLocation, isNull);
        expect(notifier.state.cloudBackupEnabled, isFalse);
      },
    );
  });

  group('setBackupLocationWithBookmark', () {
    test('persists both the path and the security-scoped bookmark', () async {
      await notifier.setBackupLocationWithBookmark('/icloud/dir', [1, 2, 3]);

      expect(notifier.state.backupLocation, '/icloud/dir');
      expect(prefs.getSettings().backupLocation, '/icloud/dir');
      expect(prefs.getBackupLocationBookmark(), [1, 2, 3]);
    });

    test('turns cloud backup off (mutually exclusive destinations)', () async {
      await notifier.setCloudBackupEnabled(true);

      await notifier.setBackupLocationWithBookmark('/icloud/dir', [9]);

      expect(notifier.state.cloudBackupEnabled, isFalse);
      expect(notifier.state.backupLocation, '/icloud/dir');
    });

    test('accepts a null bookmark (desktop bare-path case)', () async {
      await notifier.setBackupLocationWithBookmark('/desktop/dir', null);

      expect(prefs.getSettings().backupLocation, '/desktop/dir');
      expect(prefs.getBackupLocationBookmark(), isNull);
    });
  });

  group('disableCloudBackup (cloud sync sign-out hook)', () {
    test('turns cloud backup off and resets the location', () async {
      await notifier.setCloudBackupEnabled(true);

      await notifier.disableCloudBackup();

      expect(notifier.state.cloudBackupEnabled, isFalse);
      expect(notifier.state.backupLocation, isNull);
      expect(prefs.getSettings().cloudBackupEnabled, isFalse);
    });

    test('leaves an unrelated custom location untouched', () async {
      await notifier.setBackupLocation('/custom/path');

      await notifier.disableCloudBackup();

      expect(notifier.state.cloudBackupEnabled, isFalse);
      expect(notifier.state.backupLocation, '/custom/path');
    });
  });

  group('mutual exclusion holds across partial writes', () {
    // The two keys are written in separate awaited steps. If the app is killed
    // between them, whatever was persisted by the first step is the durable
    // state -- so no intermediate write may leave BOTH cloud backup enabled
    // AND a custom location set. This recording subclass snapshots the
    // persisted combination after every underlying write.
    test('enabling cloud backup never persists an enabled+custom-location '
        'combination, even transiently', () async {
      final recording = _RecordingBackupPreferences(
        await SharedPreferences.getInstance(),
      );
      final n = BackupSettingsNotifier(recording);
      await n.setBackupLocation('/custom/path');
      recording.snapshots.clear();

      await n.setCloudBackupEnabled(true);

      expect(
        recording.snapshots.where((s) => s.cloudBackupEnabled && s.hasLocation),
        isEmpty,
        reason:
            'clearing the location must be persisted before enabling cloud '
            'backup, so a crash between writes cannot strand the invalid '
            'enabled+custom-location combination',
      );
      expect(n.state.cloudBackupEnabled, isTrue);
      expect(n.state.backupLocation, isNull);
    });

    test('choosing a custom location never persists an enabled+custom-location '
        'combination, even transiently', () async {
      final recording = _RecordingBackupPreferences(
        await SharedPreferences.getInstance(),
      );
      final n = BackupSettingsNotifier(recording);
      await n.setCloudBackupEnabled(true);
      recording.snapshots.clear();

      await n.setBackupLocation('/custom/path');

      expect(
        recording.snapshots.where((s) => s.cloudBackupEnabled && s.hasLocation),
        isEmpty,
        reason:
            'disabling cloud backup must be persisted before setting the '
            'custom location',
      );
      expect(n.state.cloudBackupEnabled, isFalse);
      expect(n.state.backupLocation, '/custom/path');
    });
  });
}

/// Records the persisted (cloudBackupEnabled, hasLocation) combination after
/// every underlying write, so tests can assert the mutual-exclusion invariant
/// is never violated between the notifier's two awaited steps.
class _RecordingBackupPreferences extends BackupPreferences {
  _RecordingBackupPreferences(super.prefs);

  final List<({bool cloudBackupEnabled, bool hasLocation})> snapshots = [];

  void _snapshot() {
    final s = getSettings();
    snapshots.add((
      cloudBackupEnabled: s.cloudBackupEnabled,
      hasLocation: s.backupLocation != null,
    ));
  }

  @override
  Future<void> setCloudBackupEnabled(bool value) async {
    await super.setCloudBackupEnabled(value);
    _snapshot();
  }

  @override
  Future<void> setBackupLocation(String? path) async {
    await super.setBackupLocation(path);
    _snapshot();
  }
}
