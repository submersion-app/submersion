import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../data/identification_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late bool flagBefore;

  setUp(() {
    flagBefore = marineLifeIdEnabled;
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    container = ProviderContainer(
      overrides: [
        mediaIdentificationRepositoryProvider.overrideWithValue(
          MediaIdentificationRepository(database: db),
        ),
      ],
    );
  });
  tearDown(() async {
    marineLifeIdEnabled = flagBefore;
    container.dispose();
    await db.close();
  });

  Future<void> seedSuggestion() => container
      .read(mediaIdentificationRepositoryProvider)
      .storeRun(run(), insert: [identification('a')], deleteIds: const []);

  test('no suggestions while the feature is switched off', () async {
    marineLifeIdEnabled = false;
    await seedSuggestion();
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      isEmpty,
    );
  });

  test('stored suggestions show with no pack installed', () async {
    marineLifeIdEnabled = true;
    await seedSuggestion();
    final suggestions = await container.read(
      mediaSuggestionsProvider('m1').future,
    );
    expect(suggestions.single.top.candidate.commonName, 'Queen Parrotfish');
  });

  test('suggestions follow new identifications and new tags', () async {
    marineLifeIdEnabled = true;
    final sub = container.listen(mediaSuggestionsProvider('m1'), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      isEmpty,
    );

    await seedSuggestion();
    await pumpEventQueue();
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      hasLength(1),
    );

    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'm1',
            filePath: '',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'sp_queen_parrotfish',
            commonName: 'Queen Parrotfish',
            scientificName: const Value('Scarus vetula'),
            category: 'fish',
          ),
        );
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 't1',
            mediaId: 'm1',
            speciesId: 'sp_queen_parrotfish',
            createdAt: 0,
          ),
        );
    await pumpEventQueue();
    expect(
      await container.read(mediaSuggestionsProvider('m1').future),
      isEmpty,
    );
  });

  test('the engine is the channel engine, unsupported off Apple', () async {
    final engine = container.read(visionEngineProvider);
    expect(engine, isA<ChannelVisionEngine>());
    if (defaultTargetPlatform == TargetPlatform.android) {
      expect(engine.engineName, isNull);
    }
  });

  test('identifying on open is on by default and remembered', () async {
    expect(container.read(identifyFishOnOpenProvider), isTrue);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final stored = ProviderContainer(
      overrides: [
        identifyFishOnOpenProvider.overrideWith(
          (ref) => IdentifyFishOnOpenNotifier(prefs),
        ),
      ],
    );
    addTearDown(stored.dispose);
    await stored.read(identifyFishOnOpenProvider.notifier).setEnabled(false);
    expect(prefs.getBool(SettingsKeys.identifyFishOnOpen), isFalse);
    expect(jsonEncode(stored.read(identifyFishOnOpenProvider)), 'false');
  });
}
