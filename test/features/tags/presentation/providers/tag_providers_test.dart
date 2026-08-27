import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';

import '../../../../helpers/test_database.dart';

Tag _makeTag({String id = '', String name = 'Test Tag', String? diverId}) {
  final now = DateTime.now();
  return Tag(
    id: id,
    diverId: diverId,
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Dive _makeDive({String id = '', String? diverId, String notes = 'Test Dive'}) {
  return Dive(id: id, diverId: diverId, dateTime: DateTime.now(), notes: notes);
}

void main() {
  late SharedPreferences prefs;
  late TagRepository tagRepo;
  late DiveRepository diveRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    tagRepo = TagRepository();
    diveRepo = DiveRepository();
    diverRepo = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates a default diver and pins it as the current diver in prefs so the
  /// diver-scoped tag providers/notifier read it at construction. Tags are
  /// diver-scoped, so a current diver must exist for written rows to be
  /// visible to the providers.
  Future<Diver> setUpCurrentDiver() async {
    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  group('tagsProvider auto-refresh', () {
    test('auto-refreshes after a tag is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await setUpCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // An active listener keeps the provider alive, mirroring a widget that
      // watches the list; this keeps its table-change subscription open.
      final sub = container.listen(tagsProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(tagsProvider.future), isEmpty);

      // A sync applies a remote tag straight to the DB, bypassing the notifier.
      // The watchTagsChanges tick must invalidate the provider so the new row
      // surfaces.
      await tagRepo.createTag(_makeTag(name: 'Synced Tag', diverId: diver.id));

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          tagsProvider.future,
        )).map((t) => t.name).toList();
        if (names.contains('Synced Tag')) break;
      }

      expect(
        names,
        contains('Synced Tag'),
        reason:
            'tagsProvider should auto-refresh after a direct DB write '
            'without any manual invalidation',
      );
    });
  });

  group('tagStatisticsProvider auto-refresh', () {
    test('re-resolves on BOTH a tags-table write and a dives-table write '
        '(sync scenario)', () async {
      final diver = await setUpCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // An active listener keeps the provider (and its tags + dives table
      // subscriptions) alive.
      final sub = container.listen(tagStatisticsProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(tagStatisticsProvider.future), isEmpty);

      // 1. A tag written directly to the DB must tick the tags subscription
      //    and re-resolve the statistics with the new tag.
      await tagRepo.createTag(_makeTag(name: 'Stat Tag', diverId: diver.id));

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          tagStatisticsProvider.future,
        )).map((s) => s.tag.name).toList();
        if (names.contains('Stat Tag')) break;
      }
      expect(
        names,
        contains('Stat Tag'),
        reason:
            'tagStatisticsProvider should re-resolve after a tags-table write',
      );

      // 2. A dive written directly to the DB must tick the dives subscription
      //    and re-resolve the statistics again (the tag remains, proving a
      //    fresh rebuild rather than a stale cached snapshot).
      await diveRepo.createDive(
        _makeDive(diverId: diver.id, notes: 'Synced Dive'),
      );

      var resolvedAfterDive = false;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final stats = await container.read(tagStatisticsProvider.future);
        if (stats.any((s) => s.tag.name == 'Stat Tag')) {
          resolvedAfterDive = true;
          break;
        }
      }
      expect(
        resolvedAfterDive,
        isTrue,
        reason:
            'tagStatisticsProvider should re-resolve after a dives-table write',
      );
    });
  });

  group('tagListNotifierProvider auto-refresh', () {
    test('silently reloads the list when a tag is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await setUpCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen tag picker.
      final sub = container.listen(tagListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(tagListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(tagListNotifierProvider).value, isEmpty);

      // A sync applies a remote tag straight to the DB (no notifier mutation
      // call). The watchTagsChanges tick must silently reload via
      // _silentReloadTags.
      await tagRepo.createTag(_makeTag(name: 'Synced Tag', diverId: diver.id));

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(tagListNotifierProvider).value ?? [])
            .map((t) => t.name)
            .toList();
        if (names.contains('Synced Tag')) break;
      }

      expect(
        names,
        contains('Synced Tag'),
        reason:
            'TagListNotifier should silently reload after a direct DB write '
            'without any manual refresh() call',
      );
    });
  });
}
