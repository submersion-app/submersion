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
}) => _backupAt(
  DateTime(2026, 10, day, 9),
  deviceId: deviceId,
  ext: ext,
  modified: modified,
  size: size,
);

/// A backup named for [at], as for [_backup].
CloudFileInfo _backupAt(
  DateTime at, {
  String? deviceId = 'dev-A',
  String ext = '.db',
  DateTime? modified,
  int size = 100,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final ts =
      '${at.year}-${two(at.month)}-${two(at.day)}_'
      '${two(at.hour)}${two(at.minute)}00';
  final tag = deviceId == null ? '' : '__d${deviceTag(deviceId)}';
  final name = 'submersion_backup_$ts$tag$ext';
  return CloudFileInfo(
    id: 'id-$name',
    name: name,
    modifiedTime: modified ?? at,
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

  test('unattributed backups get no reserved slot', () {
    final files = [
      _backup(1, deviceId: null),
      _backup(2, deviceId: null),
      _backup(3),
      _backup(4),
    ];
    expect(_names(_plan(files, keep: 2)), [files[1].name, files[0].name]);
  });

  group("each device's newest backup (issue #3632)", () {
    test('keeps its slot when newer backups from others fill the count', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      final laptop = _backup(2, deviceId: 'C');
      final plan = _plan([...phone, laptop]);
      // The laptop's only backup takes one of the five slots, so the folder
      // still holds five: the laptop's and the phone's newest four.
      expect(_names(plan), [phone[2].name, phone[1].name, phone[0].name]);
      expect(plan.deviceNewestKept, 1);
    });

    test('this device is a device like any other', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      final mine = _backup(2);
      expect(_names(_plan([...phone, mine])), isNot(contains(mine.name)));
    });

    test("more devices than slots: every device's newest, nothing else", () {
      final files = [
        for (final device in ['A', 'B', 'C']) ...[
          _backup(5, deviceId: device),
          _backup(10, deviceId: device),
        ],
      ];
      final plan = _plan(files, keep: 2);
      expect(
        _names(plan),
        unorderedEquals([
          for (final f in files)
            if (f.name.contains('-05_')) f.name,
        ]),
      );
      // Two of the three newest were in the plain newest two anyway.
      expect(plan.deviceNewestKept, 1);
    });

    test('a newest older than 180 days competes under the plain rule', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      final retired = _backupAt(DateTime(2026, 4, 20, 9), deviceId: 'C');
      final plan = _plan([...phone, retired]);
      expect(_names(plan), [phone[1].name, phone[0].name, retired.name]);
      expect(plan.deviceNewestKept, 0);
    });

    test('a newest just inside 180 days keeps its slot', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      final seasonal = _backupAt(DateTime(2026, 4, 28, 9), deviceId: 'C');
      expect(
        _names(_plan([...phone, seasonal])),
        isNot(contains(seasonal.name)),
      );
    });

    test('a device whose newest is pinned reserves no other backup', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      final older = _backup(1, deviceId: 'C');
      final newest = _backup(2, deviceId: 'C');
      final plan = _plan([...phone, older, newest, _marker(newest, 'C')]);
      expect(_names(plan), [phone[1].name, phone[0].name, older.name]);
      expect(plan.deviceNewestKept, 0);
      expect(plan.pinnedKept, 1);
    });

    test('two backups stamped the same second: the later name is newest', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      final plain = _backup(2, deviceId: 'C');
      final encrypted = _backup(2, deviceId: 'C', ext: '.sbe');
      final names = _names(_plan([...phone, encrypted, plain]));
      expect(names, isNot(contains(encrypted.name)));
      expect(names, contains(plain.name));
    });

    test('a reserved backup the grace keeps anyway is not counted', () {
      final phone = [for (var d = 10; d <= 16; d++) _backup(d, deviceId: 'B')];
      // Named three weeks ago but uploaded just now, so the grace keeps it.
      final late = _backup(2, deviceId: 'C', modified: _now);
      final plan = _plan([...phone, late]);
      expect(_names(plan), isNot(contains(late.name)));
      expect(plan.deviceNewestKept, 0);
    });

    test('two devices stamped the same second rank alike in any order', () {
      final files = [
        _backup(20, deviceId: 'B'),
        _backup(20, deviceId: 'C'),
        _backup(10, deviceId: 'B'),
        _backup(10, deviceId: 'C'),
      ];
      // Both newest are reserved, leaving one slot for the two tied backups.
      final forward = _names(_plan(files, keep: 3));
      expect(forward, hasLength(1));
      expect(_names(_plan(files.reversed, keep: 3)), forward);
    });

    test('a plain prune reports no device newest kept', () {
      final files = [for (var d = 1; d <= 7; d++) _backup(d)];
      expect(_plan(files).deviceNewestKept, 0);
    });
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
        files[2].name: BackupOwnership.unattributed,
      },
    );
    expect(plan.toDelete.first.timestamp, DateTime(2026, 10, 3, 9));

    final another = _plan([
      _backup(2),
      _backup(3, deviceId: 'dev-B'),
      _backup(1, deviceId: 'dev-B'),
    ], keep: 1);
    expect(another.toDelete.single.ownership, BackupOwnership.otherDevice);
  });
}
