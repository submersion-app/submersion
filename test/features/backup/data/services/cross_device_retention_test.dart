import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/cross_device_retention.dart';

final _now = DateTime(2026, 10, 24, 12);

/// A backup named for [day] October 2026 at 09:00, written by [deviceId]
/// (unattributed when null), modified when its name says unless [modified].
CloudFileInfo _backup(
  int day, {
  String? deviceId = 'dev-A',
  String ext = '.db',
  DateTime? modified,
  int size = 100,
}) {
  final ts = '2026-10-${day.toString().padLeft(2, '0')}_090000';
  final tag = deviceId == null ? '' : '__d${deviceTag(deviceId)}';
  final name = 'submersion_backup_$ts$tag$ext';
  return CloudFileInfo(
    id: 'id-$name',
    name: name,
    modifiedTime: modified ?? DateTime(2026, 10, day, 9),
    sizeBytes: size,
  );
}

CloudFileInfo _marker(
  CloudFileInfo backup,
  String pinner, {
  DateTime? modified,
}) {
  final name = pinMarkerName(
    backupFilename: backup.name,
    pinningDeviceId: pinner,
  );
  return CloudFileInfo(
    id: 'id-$name',
    name: name,
    modifiedTime: modified ?? _now,
  );
}

CrossDeviceRetentionPlan _plan(
  Iterable<CloudFileInfo> listing, {
  int keep = 5,
  Set<String> pinnedStems = const {},
  Set<String> pinnedIds = const {},
}) => planCrossDeviceRetention(
  listing: listing,
  keepCount: keep,
  locallyPinnedStems: pinnedStems,
  locallyPinnedFileIds: pinnedIds,
  thisDeviceId: 'dev-A',
  now: _now,
);

List<String> _names(CrossDeviceRetentionPlan plan) => [
  for (final c in plan.toDelete) c.file.name,
];

void main() {
  test('keeps the newest keepCount and removes the rest, oldest last', () {
    final files = [for (var d = 1; d <= 7; d++) _backup(d)];
    final plan = _plan(files);
    expect(_names(plan), [files[1].name, files[0].name]);
    expect(plan.keepCount, 5);
    expect(plan.totalBytes, 200);
    expect(plan.isEmpty, isFalse);
  });

  test('counts every device and unattributed backups alike', () {
    final files = [
      _backup(1, deviceId: null),
      _backup(2, deviceId: 'dev-B'),
      _backup(3, deviceId: 'dev-C'),
      _backup(4),
    ];
    expect(_names(_plan(files, keep: 2)), [files[1].name, files[0].name]);
  });

  test('a marker from any device pins its backup, whatever the extension', () {
    final files = [for (var d = 1; d <= 6; d++) _backup(d, ext: '.sbe')];
    final plan = _plan([...files, _marker(files[0], 'dev-B')]);
    expect(_names(plan), isEmpty);
    expect(plan.pinnedKept, 1);
  });

  test('locally pinned stems and file ids are kept', () {
    final files = [for (var d = 1; d <= 7; d++) _backup(d)];
    final plan = _plan(
      files,
      pinnedStems: {backupStem(files[0].name)},
      pinnedIds: {files[1].id},
    );
    expect(_names(plan), isEmpty);
    expect(plan.pinnedKept, 2);
  });

  test('pinned backups do not count toward keepCount', () {
    final files = [for (var d = 1; d <= 6; d++) _backup(d)];
    final plan = _plan([...files, _marker(files[5], 'dev-A')]);
    expect(_names(plan), isEmpty);
  });

  test('backups inside the 24 hour grace are never removed', () {
    final today = [
      CloudFileInfo(
        id: 'a',
        name: 'submersion_backup_2026-10-24_080000.db',
        modifiedTime: _now,
      ),
      CloudFileInfo(
        id: 'b',
        name: 'submersion_backup_2026-10-24_070000.db',
        modifiedTime: _now,
      ),
    ];
    expect(_names(_plan(today, keep: 1)), isEmpty);

    final uploadedLately = _backup(
      3,
      modified: _now.subtract(const Duration(hours: 2)),
    );
    expect(_names(_plan([_backup(5), uploadedLately], keep: 1)), isEmpty);
  });

  test('orders by the name, not the modified time', () {
    final older = _backup(1, modified: DateTime(2026, 10, 20));
    final newer = _backup(2, modified: DateTime(2026, 10, 2));
    expect(_names(_plan([older, newer], keep: 1)), [older.name]);
  });

  test('a backup renamed by hand is never removed', () {
    final odd = CloudFileInfo(
      id: 'odd',
      name: 'submersion_backup_renamed.db',
      modifiedTime: DateTime(2026, 9, 1),
    );
    expect(_names(_plan([odd, _backup(1)], keep: 1)), isEmpty);
  });

  test('prefix lookalikes are never counted or removed', () {
    final real = [for (var d = 1; d <= 3; d++) _backup(d)];
    final lookalikes = [
      CloudFileInfo(
        id: 't',
        name: 'submersion_backup_2026-09-01_090000.db.tmp',
        modifiedTime: DateTime(2026, 9, 1),
      ),
      CloudFileInfo(
        id: 'c',
        name: 'submersion_backup_2026-09-02_090000 (conflicted copy).db',
        modifiedTime: DateTime(2026, 9, 2),
      ),
      CloudFileInfo(
        id: 'k',
        name: 'submersion_keyslot.json',
        modifiedTime: DateTime(2026, 9, 3),
      ),
    ];
    final plan = _plan([...real, ...lookalikes], keep: 1);
    expect(_names(plan), [real[1].name, real[0].name]);
  });

  test('the same file listed twice is counted once', () {
    final files = [for (var d = 1; d <= 3; d++) _backup(d)];
    expect(_names(_plan([...files, files[0]], keep: 2)), [files[0].name]);
  });

  test('an old marker whose backup is not listed is an orphan', () {
    final gone = _backup(1);
    final kept = _backup(2);
    final old = DateTime(2026, 10, 1);
    final orphan = _marker(gone, 'dev-B', modified: old);
    final live = _marker(kept, 'dev-B', modified: old);
    final plan = _plan([kept, orphan, live]);
    expect([for (final m in plan.orphanMarkers) m.name], [orphan.name]);
  });

  test(
    'a young marker is never an orphan: its backup may still be on the way',
    () {
      final arriving = _backup(1);
      final young = _marker(
        arriving,
        'dev-B',
        modified: _now.subtract(const Duration(hours: 1)),
      );
      expect(_plan([young]).orphanMarkers, isEmpty);
    },
  );

  test('a marker for a backup the rule does not manage is not an orphan', () {
    final conflicted = CloudFileInfo(
      id: 'c',
      name: 'submersion_backup_2026-09-02_090000 (conflicted copy).db',
      modifiedTime: DateTime(2026, 9, 2),
    );
    final marker = _marker(conflicted, 'dev-B', modified: DateTime(2026, 9, 3));
    expect(_plan([conflicted, marker]).orphanMarkers, isEmpty);
  });

  test('ownership comes from the name', () {
    final files = [
      _backup(1),
      _backup(2, deviceId: 'dev-B'),
      _backup(3, deviceId: null),
      _backup(4),
    ];
    final plan = _plan(files, keep: 1);
    expect(
      {for (final c in plan.toDelete) c.file.name: c.ownership},
      {
        files[0].name: BackupOwnership.thisDevice,
        files[1].name: BackupOwnership.otherDevice,
        files[2].name: BackupOwnership.unattributed,
      },
    );
    expect(plan.toDelete.first.timestamp, DateTime(2026, 10, 3, 9));
  });
}
