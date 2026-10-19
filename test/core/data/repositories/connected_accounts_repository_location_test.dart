// Issue #3482 phase 2: the roster carries a secret-free location for S3 and
// WebDAV rows, written on save and sign-in.

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ConnectedAccountsRepository repo;

  final config = S3Config(
    endpoint: 'https://minio.home:9000',
    bucket: 'dives',
    accessKeyId: 'AKIA1',
    secretAccessKey: 'shh',
  );
  final location = S3AccountLocation.fromConfig(config);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ConnectedAccountsRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<String?> hlcOf(String id) async {
    final row = await db
        .customSelect("SELECT hlc FROM connected_accounts WHERE id = '$id'")
        .getSingle();
    return row.read<String?>('hlc');
  }

  test('setLocation round-trips through getById', () async {
    final a = await repo.create(kind: AccountKind.s3, label: 'dives @ minio');
    await repo.setLocation(a.id, location);
    final loaded = (await repo.getById(a.id))!.location as S3AccountLocation;
    expect(loaded.bucket, 'dives');
    expect(loaded.serverKey, location.serverKey);
  });

  // Review of #3527: a location from a newer build reads as none here; a v1
  // write over it would drop its newer fields on every device.
  test('a location this build cannot read is left alone', () async {
    final a = await repo.create(kind: AccountKind.s3, label: 'dives @ minio');
    const newer = '{"v":2,"kind":"s3","bucket":"dives"}';
    await db.customStatement(
      "UPDATE connected_accounts SET location = '$newer' WHERE id = '${a.id}'",
    );
    await repo.setLocation(a.id, location);
    final row = await db
        .customSelect(
          "SELECT location FROM connected_accounts WHERE id = '${a.id}'",
        )
        .getSingle();
    expect(row.read<String?>('location'), newer);
  });

  test('an identical location does not mark the row pending again', () async {
    final a = await repo.create(kind: AccountKind.s3, label: 'dives @ minio');
    await repo.setLocation(a.id, location);
    final stamped = await hlcOf(a.id);
    await repo.setLocation(a.id, location);
    expect(await hlcOf(a.id), stamped);
  });

  test('ensure writes a location onto an existing row', () async {
    final key = s3NaturalKey(config);
    await repo.ensure(kind: AccountKind.s3, naturalKey: key, label: 'x');
    final a = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: key,
      label: 'x',
      location: location,
    );
    expect((await repo.getById(a.id))!.location, isA<S3AccountLocation>());
  });

  test(
    'a junk stored location reads as none and the row still loads',
    () async {
      final a = await repo.create(kind: AccountKind.s3, label: 'x');
      await db.customStatement(
        "UPDATE connected_accounts SET location = '{' WHERE id = '${a.id}'",
      );
      final loaded = await repo.getById(a.id);
      expect(loaded, isNotNull);
      expect(loaded!.location, isNull);
    },
  );
}
