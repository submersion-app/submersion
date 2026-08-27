import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// The sync cursor (lastSyncTimestamp) is stamped with the provider it was
/// minted against. A cursor minted against one backend must read as absent
/// for any other backend: carrying it across a backend switch is what let
/// the first-contact merge guard be bypassed (a non-null cursor reads as
/// "this device has synced HERE before", which is false after a switch).
void main() {
  late SyncRepository repo;

  final t1 = DateTime.fromMillisecondsSinceEpoch(111000);
  final t2 = DateTime.fromMillisecondsSinceEpoch(222000);

  setUp(() async {
    await setUpTestDatabase();
    repo = SyncRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('provider-scoped cursor', () {
    test(
      'cursor minted against a provider is visible to that provider',
      () async {
        await repo.updateLastSyncTime(t1, providerId: 'icloud');
        expect(await repo.getLastSyncTime(forProvider: 'icloud'), t1);
      },
    );

    test('cursor minted against one provider is absent for another', () async {
      await repo.updateLastSyncTime(t1, providerId: 's3');
      expect(
        await repo.getLastSyncTime(forProvider: 'icloud'),
        isNull,
        reason:
            'a cursor carried across a backend switch must read as "never '
            'synced here" so first contact with the new backend is detected',
      );
    });

    test(
      'raw read (no provider) ignores scoping, for display contexts',
      () async {
        await repo.updateLastSyncTime(t1, providerId: 's3');
        expect(await repo.getLastSyncTime(), t1);
      },
    );

    test('legacy unstamped cursor stays visible to any provider', () async {
      // Pre-upgrade rows have a cursor but no stamp; treating them as absent
      // would force a one-time first-contact prompt on every upgrader.
      await repo.updateLastSyncTime(t1);
      expect(await repo.getLastSyncTime(forProvider: 'icloud'), t1);
      expect(await repo.getLastSyncTime(forProvider: 's3'), t1);
    });

    test('switching back before any sync on the new backend resumes the old '
        'cursor unchanged', () async {
      await repo.updateLastSyncTime(t1, providerId: 's3');
      // No sync happened against 'icloud'; the stored stamp still names 's3',
      // so an aborted switch is harmless.
      expect(await repo.getLastSyncTime(forProvider: 's3'), t1);
    });
  });

  group('stampLegacyCursorProvider', () {
    test('claims an unstamped cursor for the given provider', () async {
      await repo.updateLastSyncTime(t1);
      await repo.stampLegacyCursorProvider('s3');
      expect(await repo.getLastSyncTime(forProvider: 's3'), t1);
      expect(await repo.getLastSyncTime(forProvider: 'icloud'), isNull);
    });

    test('never overwrites an existing stamp', () async {
      await repo.updateLastSyncTime(t1, providerId: 'icloud');
      await repo.stampLegacyCursorProvider('s3');
      expect(await repo.getLastSyncTime(forProvider: 'icloud'), t1);
      expect(await repo.getLastSyncTime(forProvider: 's3'), isNull);
    });

    test('is a no-op when no cursor exists', () async {
      await repo.stampLegacyCursorProvider('s3');
      expect(await repo.getLastSyncTime(), isNull);
      // A later legacy-style write must still behave as unstamped.
      await repo.updateLastSyncTime(t1);
      expect(await repo.getLastSyncTime(forProvider: 'icloud'), t1);
    });
  });

  group('resetSyncState', () {
    test('clears the provider stamp along with the cursor', () async {
      await repo.updateLastSyncTime(t1, providerId: 'icloud');
      await repo.resetSyncState();
      expect(await repo.getLastSyncTime(), isNull);

      // If the stale stamp survived the reset, this legacy write would be
      // invisible to other providers; unstamped semantics prove it cleared.
      await repo.updateLastSyncTime(t2);
      expect(await repo.getLastSyncTime(forProvider: 's3'), t2);
    });
  });
}
