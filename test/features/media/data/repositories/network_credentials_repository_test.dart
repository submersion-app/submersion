// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 3. Schema deviations applied vs. plan code:
//
// - `network_credential_hosts.id` is TEXT (String), not INTEGER. The plan's
//   `expect(id, isPositive)` is replaced with `expect(id, isNotEmpty)`, and
//   delete/findById/touchLastUsed take String ids.
// - `AppDatabase` constructor takes a positional executor (not the named
//   `executor:` arg used in the plan).
//
// All other test intent (upsert insert, upsert-by-hostname update,
// findByHostname null/present, delete, touchLastUsed) is preserved verbatim.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';

void main() {
  late AppDatabase db;
  late NetworkCredentialsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NetworkCredentialsRepository(db: db);
  });
  tearDown(() async => db.close());

  test('upsert inserts a new host row', () async {
    final id = await repo.upsert(
      hostname: 'example.com',
      authType: 'basic',
      displayName: 'Example',
    );
    expect(id, isNotEmpty);
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.first.hostname, 'example.com');
    expect(all.first.authType, 'basic');
  });

  test('upsert by hostname updates existing row', () async {
    await repo.upsert(hostname: 'example.com', authType: 'basic');
    await repo.upsert(
      hostname: 'example.com',
      authType: 'bearer',
      displayName: 'New name',
    );
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.first.authType, 'bearer');
    expect(all.first.displayName, 'New name');
  });

  test('findByHostname returns null when missing', () async {
    expect(await repo.findByHostname('missing.example'), isNull);
  });

  test('findByHostname returns row when present', () async {
    await repo.upsert(hostname: 'example.com', authType: 'basic');
    final row = await repo.findByHostname('example.com');
    expect(row, isNotNull);
  });

  test('delete removes the row', () async {
    final id = await repo.upsert(hostname: 'example.com', authType: 'basic');
    await repo.delete(id);
    expect(await repo.list(), isEmpty);
  });

  test('touchLastUsed updates lastUsedAt', () async {
    final id = await repo.upsert(hostname: 'example.com', authType: 'basic');
    await repo.touchLastUsed(id);
    final row = await repo.findById(id);
    expect(row?.lastUsedAt, isNotNull);
  });
}
