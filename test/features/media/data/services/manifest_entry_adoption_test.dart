import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/manifest_entry_adoption.dart';
import 'package:submersion/features/media/data/services/manifest_url_identity.dart';

ManifestEntry _entry(String key, String url) =>
    ManifestEntry(entryKey: key, url: url);

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late ManifestSubscriptionRepository subscriptions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    DatabaseService.instance.setTestDatabase(db);
    mediaRepo = MediaRepository();
    subscriptions = ManifestSubscriptionRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<void> insertRow(
    String id,
    String url, {
    String? subscriptionId,
    String? entryKey,
    int createdAt = 1000,
    String sourceType = 'manifestEntry',
  }) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          filePath: '',
          sourceType: Value(sourceType),
          subscriptionId: Value(subscriptionId),
          entryKey: Value(entryKey),
          url: Value(url),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  /// The tombstone deleting a subscription logs.
  Future<void> tombstone(String subscriptionId) => db
      .into(db.deletionLog)
      .insert(
        DeletionLogCompanion.insert(
          id: 'del-$subscriptionId',
          entityType: 'mediaSubscriptions',
          recordId: subscriptionId,
          deletedAt: 1,
        ),
      );

  group('canonicalManifestUrl', () {
    test('reduces a share link to origin and code', () {
      const plain = 'https://nas.example.com:5001/mo/sharing/code1';
      expect(canonicalManifestUrl('$plain/'), plain);
      expect(canonicalManifestUrl('  $plain  '), plain);
      expect(
        canonicalManifestUrl(
          'https://nas.example.com:5001/photo/mo/sharing/code1',
        ),
        plain,
      );
    });

    test('keeps any other URL as typed, minus whitespace', () {
      expect(
        canonicalManifestUrl(' https://feed.example.com/m.json?a=1 '),
        'https://feed.example.com/m.json?a=1',
      );
      expect(
        canonicalManifestUrl('https://feed.example.com/m.json?a=2'),
        isNot(canonicalManifestUrl('https://feed.example.com/m.json?a=1')),
      );
    });
  });

  group('findByManifestUrl', () {
    test('finds an inactive subscription through another spelling', () async {
      final sub = await subscriptions.createSubscription(
        manifestUrl: 'https://nas.example.com:5001/mo/sharing/code1',
        format: ManifestFormat.json,
        isActive: false,
      );
      final found = await subscriptions.findByManifestUrl(
        'https://nas.example.com:5001/mo/sharing/code1/',
      );
      expect(found?.id, sub.id);
    });

    test('returns null when no subscription reads the URL', () async {
      await subscriptions.createSubscription(
        manifestUrl: 'https://nas.example.com:5001/mo/sharing/code1',
        format: ManifestFormat.json,
      );
      expect(
        await subscriptions.findByManifestUrl(
          'https://nas.example.com:5001/mo/sharing/code2',
        ),
        isNull,
      );
    });
  });

  group('planManifestAdoption', () {
    test('takes over rows of a deleted subscription or of none', () async {
      await insertRow('gone', 'https://h/a.jpg', subscriptionId: 'deleted');
      await tombstone('deleted');
      await insertRow('none', 'https://h/b.jpg');
      final plan = await planManifestAdoption(mediaRepo, [
        _entry('ka', 'https://h/a.jpg'),
        _entry('kb', 'https://h/b.jpg'),
        _entry('kc', 'https://h/c.jpg'),
      ]);
      expect(plan.adoptable.keys.toSet(), {'gone', 'none'});
      expect(plan.adoptable['gone']!.entry.entryKey, 'ka');
      expect(plan.fresh.map((e) => e.entryKey), ['kc']);
    });

    test('leaves rows of a subscription not synced here yet alone', () async {
      // Absent locally, but no tombstone: another device's subscription
      // whose row has not arrived yet.
      await insertRow('peer', 'https://h/a.jpg', subscriptionId: 'unsynced');
      final plan = await planManifestAdoption(mediaRepo, [
        _entry('ka', 'https://h/a.jpg'),
      ]);
      expect(plan.adoptable, isEmpty);
      expect(plan.fresh, hasLength(1));
    });

    test('leaves rows of a live subscription alone', () async {
      final live = await subscriptions.createSubscription(
        manifestUrl: 'https://feed.example.com/m.json',
        format: ManifestFormat.json,
      );
      await insertRow('owned', 'https://h/a.jpg', subscriptionId: live.id);
      final plan = await planManifestAdoption(mediaRepo, [
        _entry('ka', 'https://h/a.jpg'),
      ]);
      expect(plan.adoptable, isEmpty);
      expect(plan.fresh, hasLength(1));
    });

    test('ignores rows that are not manifest entries', () async {
      await insertRow('url', 'https://h/a.jpg', sourceType: 'networkUrl');
      final plan = await planManifestAdoption(mediaRepo, [
        _entry('ka', 'https://h/a.jpg'),
      ]);
      expect(plan.adoptable, isEmpty);
    });

    test('matches the re-serialized spelling of a URL', () async {
      const raw = 'https://h/x?item_id=[42]';
      final stored = Uri.parse(raw).toString();
      expect(stored, isNot(raw));
      await insertRow('r', stored);
      final plan = await planManifestAdoption(mediaRepo, [_entry('k', raw)]);
      expect(plan.adoptable.keys, ['r']);
    });

    test('takes over the oldest of several rows once', () async {
      await insertRow('old', 'https://h/a.jpg', createdAt: 1);
      await insertRow('new', 'https://h/a.jpg', createdAt: 2);
      final plan = await planManifestAdoption(mediaRepo, [
        _entry('ka', 'https://h/a.jpg'),
      ]);
      expect(plan.adoptable.keys, ['old']);
    });

    test('an empty batch reads nothing', () async {
      final plan = await planManifestAdoption(mediaRepo, const []);
      expect(plan.adoptable, isEmpty);
      expect(plan.fresh, isEmpty);
    });
  });

  test(
    'applyManifestAdoption moves rows and clears the missing mark',
    () async {
      final sub = await subscriptions.createSubscription(
        manifestUrl: 'https://feed.example.com/m.json',
        format: ManifestFormat.json,
      );
      await insertRow('gone', 'https://h/a.jpg', subscriptionId: 'deleted');
      await tombstone('deleted');
      await mediaRepo.markOrphaned('gone', true);
      final plan = await planManifestAdoption(mediaRepo, [
        _entry('ka', 'https://h/a.jpg'),
      ]);

      expect(await applyManifestAdoption(mediaRepo, plan, sub.id), 1);
      final row = (await mediaRepo.getAllBySubscription(sub.id)).single;
      expect(row.id, 'gone');
      expect(row.entryKey, 'ka');
      expect(row.isOrphaned, isFalse);
      expect(
        await applyManifestAdoption(
          mediaRepo,
          ManifestAdoptionPlan.empty,
          sub.id,
        ),
        0,
      );
    },
  );

  test('entriesNotYetIn drops what the subscription holds', () async {
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
    );
    await insertRow(
      'a',
      'https://h/a.jpg',
      subscriptionId: sub.id,
      entryKey: 'ka',
    );
    final left = await entriesNotYetIn(mediaRepo, sub.id, [
      _entry('ka', 'https://h/a.jpg'),
      _entry('kb', 'https://h/b.jpg'),
    ]);
    expect(left.map((e) => e.entryKey), ['kb']);
  });
}
