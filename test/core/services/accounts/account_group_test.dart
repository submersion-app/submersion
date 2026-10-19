// Issue #3482 phase 2: the UI shows one account per server, while the roster
// keeps one row per role underneath (spec section 7.2).

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

final _t = DateTime.utc(2026);

ConnectedAccount _row(
  String id,
  AccountKind kind, {
  String label = 'x',
  AccountLocation? location,
  String? identifier,
}) => ConnectedAccount(
  id: id,
  kind: kind,
  label: label,
  accountIdentifier: identifier,
  createdAt: _t,
  updatedAt: _t,
  location: location,
);

S3AccountLocation _s3(String prefix, {String host = 'minio.home'}) =>
    S3AccountLocation(
      displayHost: host,
      endpoint: 'https://$host',
      bucket: 'dives',
      region: 'us-east-1',
      prefix: prefix,
      pathStyle: true,
    );

List<AccountGroup> _group(
  List<ConnectedAccount> rows, {
  Map<String, AccountStatus> status = const {},
  Map<String, AccountLocation> local = const {},
  Map<String, List<AccountUsage>> usages = const {},
}) => groupAccounts(
  rows: rows,
  statusById: {
    for (final r in rows) r.id: status[r.id] ?? AccountStatus.signedIn,
  },
  localLocationById: local,
  usagesOf: (r) => usages[r.id] ?? const [],
);

void main() {
  test('sync and media rows on one bucket are one account', () {
    final groups = _group(
      [
        _row('sync', AccountKind.s3, location: _s3('submersion-sync/')),
        _row('media', AccountKind.s3, location: _s3('submersion-media/')),
      ],
      usages: {
        'sync': const [AccountUsage(AccountUsageKind.databaseSync)],
        'media': const [AccountUsage(AccountUsageKind.mediaStorage)],
      },
    );
    expect(groups, hasLength(1));
    final g = groups.single;
    expect(g.label, 'dives @ minio.home');
    expect(g.rows.map((r) => r.id), unorderedEquals(['sync', 'media']));
    expect(g.usages.map((u) => u.kind), [
      AccountUsageKind.databaseSync,
      AccountUsageKind.mediaStorage,
    ]);
    expect(g.rowFor(AccountRole.sync)!.id, 'sync');
    expect(g.rowFor(AccountRole.media)!.id, 'media');
    expect(g.isOwnServer, isTrue);
  });

  // Issue #3522: accounts read by a short name, the address kept below.
  test('a well-known host reads as its service, the address kept', () {
    final g = _group([
      _row(
        'r2',
        AccountKind.s3,
        location: _s3(
          'submersion-sync/',
          host: 'abc123.r2.cloudflarestorage.com',
        ),
      ),
    ]).single;
    expect(g.label, 'dives @ Cloudflare R2');
    expect(g.address, 'dives @ abc123.r2.cloudflarestorage.com');
  });

  test('a nickname on any row names the account', () {
    final g = _group([
      _row('sync', AccountKind.s3, location: _s3('submersion-sync/')),
      ConnectedAccount(
        id: 'lib',
        kind: AccountKind.s3,
        label: 'x',
        createdAt: _t,
        updatedAt: _t,
        location: _s3('submersion-sites/reef/'),
        nickname: 'Home NAS',
      ),
    ]).single;
    expect(g.label, 'Home NAS');
    expect(g.address, 'dives @ minio.home');
  });

  test('the same bucket on two hosts is two accounts', () {
    final groups = _group([
      _row('a', AccountKind.s3, location: _s3('submersion-sync/')),
      _row('b', AccountKind.s3, location: _s3('submersion-sync/', host: 'nas')),
    ]);
    expect(groups, hasLength(2));
  });

  test('a row nothing here can place stands alone', () {
    final groups = _group([
      _row('known', AccountKind.s3, location: _s3('submersion-sync/')),
      _row('legacy', AccountKind.s3, label: 'dives @ minio.home'),
    ]);
    expect(groups, hasLength(2));
    expect(
      groups.firstWhere((g) => g.rows.single.id == 'legacy').key,
      'row|legacy',
    );
  });

  test(
    'a row known only from this device\'s stored config joins its server',
    () {
      final groups = _group(
        [
          _row('sync', AccountKind.s3, location: _s3('submersion-sync/')),
          _row('lib', AccountKind.s3),
        ],
        local: {'lib': _s3('submersion-sites/reef-team/')},
      );
      expect(groups, hasLength(1));
      expect(groups.single.rowFor(AccountRole.library)!.id, 'lib');
    },
  );

  test('one row needing sign-in makes the account need sign-in', () {
    final g = _group(
      [
        _row('sync', AccountKind.s3, location: _s3('submersion-sync/')),
        _row('media', AccountKind.s3, location: _s3('submersion-media/')),
      ],
      status: {'media': AccountStatus.needsSignIn},
    ).single;
    expect(g.status, AccountStatus.needsSignIn);
  });

  test('an iCloud row unavailable here reads unavailable', () {
    final g = _group(
      [_row('ic', AccountKind.icloud, label: 'iCloud')],
      status: {'ic': AccountStatus.unavailable},
    ).single;
    expect(g.status, AccountStatus.unavailable);
    expect(g.isOwnServer, isFalse);
  });

  test('a library row\'s label drops its folder note', () {
    final g = _group([
      _row(
        'lib',
        AccountKind.s3,
        label: 'dives @ minio.home (submersion-sites/reef-team)',
      ),
    ]).single;
    expect(g.label, 'dives @ minio.home');
  });

  test('usages are listed once even when two rows share one', () {
    final g = _group(
      [
        _row('a', AccountKind.s3, location: _s3('submersion-sites/a/')),
        _row('b', AccountKind.s3, location: _s3('submersion-sites/b/')),
      ],
      usages: {
        'a': const [
          AccountUsage(
            AccountUsageKind.sharedLibrary,
            libraryName: 'Reef team',
          ),
        ],
        'b': const [
          AccountUsage(
            AccountUsageKind.sharedLibrary,
            libraryName: 'Reef team',
          ),
        ],
      },
    ).single;
    expect(g.usages, hasLength(1));
  });

  test(
    'accounts sort iCloud, Google Drive, Dropbox, own servers, Lightroom',
    () {
      final groups = _group([
        _row('lr', AccountKind.adobeLightroom, label: 'Lightroom'),
        _row('s3', AccountKind.s3, location: _s3('submersion-sync/')),
        _row('db', AccountKind.dropbox, label: 'Dropbox'),
        _row('gd', AccountKind.googledrive, label: 'Google Drive'),
        _row('ic', AccountKind.icloud, label: 'iCloud'),
      ]);
      expect(groups.map((g) => g.kind), [
        AccountKind.icloud,
        AccountKind.googledrive,
        AccountKind.dropbox,
        AccountKind.s3,
        AccountKind.adobeLightroom,
      ]);
    },
  );

  test('a WebDAV server groups by its address and labels by user and host', () {
    const sync = WebDavAccountLocation(
      serverUrl: 'https://cloud.example.com/dav',
      username: 'eric',
      folder: 'Submersion',
    );
    const media = WebDavAccountLocation(
      serverUrl: 'https://cloud.example.com/dav',
      username: 'eric',
      folder: 'Submersion Media',
    );
    final g = _group([
      _row('s', AccountKind.webdav, location: sync),
      _row('m', AccountKind.webdav, location: media),
    ]).single;
    expect(g.label, 'eric @ cloud.example.com');
    expect(g.rowFor(AccountRole.media)!.id, 'm');
  });

  // Review of #3527: the default sync folder alone does not mean this device
  // syncs through a server; only the sync usage does.
  test('the row sync uses here comes from usage, not the folder', () {
    final unused = _group([
      _row('srv', AccountKind.s3, location: _s3('submersion-sync/')),
    ]).single;
    expect(unused.rowFor(AccountRole.sync)!.id, 'srv');
    expect(unused.syncRowHere, isNull);

    final used = _group(
      [_row('srv', AccountKind.s3, location: _s3('submersion-sync/'))],
      usages: {
        'srv': const [AccountUsage(AccountUsageKind.databaseSync)],
      },
    ).single;
    expect(used.syncRowHere!.id, 'srv');
  });

  test('a role from usage outranks one from the folder name', () {
    // Newest first, as the roster lists rows: the default-folder row comes
    // first, but sync runs on the custom folder.
    final g = _group(
      [
        _row('default', AccountKind.s3, location: _s3('submersion-sync/')),
        _row('custom', AccountKind.s3, location: _s3('dives/')),
      ],
      usages: {
        'custom': const [AccountUsage(AccountUsageKind.databaseSync)],
      },
    ).single;
    expect(g.rowFor(AccountRole.sync)!.id, 'custom');
  });

  test('each row keeps its own sign-in state', () {
    final g = _group(
      [
        _row('sync', AccountKind.s3, location: _s3('submersion-sync/')),
        _row('photos', AccountKind.s3, location: _s3('submersion-media/')),
      ],
      status: {'photos': AccountStatus.needsSignIn},
    ).single;
    expect(g.status, AccountStatus.needsSignIn);
    expect(g.statusOf('sync'), AccountStatus.signedIn);
    expect(g.signedInHere, isTrue);
  });

  test('accounts with one label keep a stable order', () {
    List<String> order(List<ConnectedAccount> rows) => [
      for (final g in _group(rows)) g.rows.single.id,
    ];
    final a = _row('a', AccountKind.googledrive, label: 'Drive');
    final b = _row('b', AccountKind.dropbox, label: 'Drive');
    final c = _row('c', AccountKind.s3, label: 'Home');
    final d = _row('d', AccountKind.s3, label: 'Home');
    expect(order([c, d]), order([d, c]));
    expect(order([a, b]), ['a', 'b']);
  });

  test('a Lightroom name keeps its parentheses', () {
    final g = _group([
      _row('lr', AccountKind.adobeLightroom, label: 'Jane Doe (Dive Club)'),
    ]).single;
    expect(g.label, 'Jane Doe (Dive Club)');
  });
}
