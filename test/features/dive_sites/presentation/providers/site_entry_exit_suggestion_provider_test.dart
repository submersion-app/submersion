import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Direct coverage for [siteEntryExitSuggestionProvider].
///
/// The site-editor widget tests override this provider with a fixture, so its
/// own mapping logic never runs there. These tests exercise the real body
/// against a real database.
void main() {
  late db.AppDatabase database;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    database = DatabaseService.instance.database;

    // Foreign keys are enforced, so parents must exist first.
    await database
        .into(database.divers)
        .insert(
          db.DiversCompanion.insert(
            id: 'me',
            name: 'Me',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await database
        .into(database.diveSites)
        .insert(
          db.DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Blue Hole',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer buildContainer({String? diverId = 'me'}) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
        // statisticsRepositoryProvider watches the gas model (issue #828),
        // which otherwise builds the real SettingsNotifier and leaves its
        // async load running past this container's disposal.
        gasModelProvider.overrideWith((ref) => GasModel.real),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> insertDive({
    required String id,
    String siteId = 'site-1',
    String diverId = 'me',
    String? entry,
    String? exit,
  }) async {
    await database
        .into(database.dives)
        .insert(
          db.DivesCompanion.insert(
            id: id,
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
            diverId: Value(diverId),
            siteId: Value(siteId),
            entryMethod: Value(entry),
            exitMethod: Value(exit),
          ),
        );
  }

  test('maps the modal pair onto EntryMethod values', () async {
    await insertDive(id: 'd1', entry: 'giantStride', exit: 'ladder');
    await insertDive(id: 'd2', entry: 'giantStride', exit: 'ladder');
    await insertDive(id: 'd3', entry: 'shore', exit: 'shore');

    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.entry, EntryMethod.giantStride);
    expect(suggestion.exit, EntryMethod.ladder);
    expect(suggestion.count, 2);
  });

  test('carries a null exit method through as null', () async {
    await insertDive(id: 'd1', entry: 'shore');

    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion!.entry, EntryMethod.shore);
    expect(suggestion.exit, isNull);
  });

  test('returns null when the site has no dives', () async {
    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion, isNull);
  });

  test('returns null when no dive records an entry method', () async {
    await insertDive(id: 'd1');

    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion, isNull);
  });

  test('returns null when there is no current diver', () async {
    await insertDive(id: 'd1', entry: 'shore', exit: 'shore');

    final container = buildContainer(diverId: null);
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion, isNull);
  });

  test('returns null when the stored entry name is not a known enum', () async {
    // Guards the enum lookup: a value written by a future version, or by a
    // hand-edited database, must not crash the site editor.
    await insertDive(id: 'd1', entry: 'teleportation');

    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion, isNull);
  });

  test('drops an unknown exit name but keeps the entry', () async {
    await insertDive(id: 'd1', entry: 'shore', exit: 'levitation');

    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-1').future,
    );

    expect(suggestion!.entry, EntryMethod.shore);
    expect(suggestion.exit, isNull);
  });

  test('scopes to the requested site', () async {
    await database
        .into(database.diveSites)
        .insert(
          db.DiveSitesCompanion.insert(
            id: 'site-2',
            name: 'Other',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await insertDive(id: 'd1', entry: 'shore', exit: 'shore');
    await insertDive(id: 'd2', siteId: 'site-2', entry: 'boat', exit: 'boat');

    final container = buildContainer();
    final suggestion = await container.read(
      siteEntryExitSuggestionProvider('site-2').future,
    );

    expect(suggestion!.entry, EntryMethod.boat);
  });
}
