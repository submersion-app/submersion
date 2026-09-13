import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';

const _parsed = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'd1', SourceDiver.mapKey: _ann},
      {'sourceUuid': 'd2', SourceDiver.mapKey: _bo},
    ],
    ImportEntityType.media: [
      {'filename': 'b.jpg', '_diveIndex': 1},
    ],
  },
  sourceDivers: [
    SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
    SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
  ],
);

final _me = Diver(
  id: 'me',
  name: 'Me',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(payload: _parsed);
  });

  tearDown(() => container.dispose());

  test('initDiverMapping seeds the defaults once', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    expect(notifier.state.diverMapping, {
      _ann: const ExistingDiverTarget('me'),
      _bo: const NewDiverTarget(_bo),
    });

    notifier.setDiverTarget(_bo, const SkipDiverTarget());
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    expect(notifier.state.diverMapping[_bo], const SkipDiverTarget());
  });

  test('initDiverMapping ignores a single-diver payload', () {
    notifier.state = notifier.state.copyWith(
      payload: const ImportPayload(
        entities: {},
        sourceDivers: [SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 3)],
      ),
    );
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    expect(notifier.state.diverMapping, isEmpty);
  });

  test('applyDiverMapping always expands from the parsed payload', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.sourcePayload, _parsed);
    expect(
      notifier.state.payload!
          .entitiesOf(ImportEntityType.dives)
          .map((d) => d[DiverTarget.itemKey]),
      ['diver:me', 'new:$_bo'],
    );

    notifier.setDiverTarget(_bo, const SkipDiverTarget());
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.payload!.entitiesOf(ImportEntityType.dives), [
      {
        'sourceUuid': 'd1',
        SourceDiver.mapKey: _ann,
        DiverTarget.itemKey: 'diver:me',
      },
    ]);
    expect(notifier.state.parsedPayload, _parsed);
  });

  test('a changed media list drops the photo resolution', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    notifier.applyDiverMapping(activeDiverId: 'me');
    notifier.state = notifier.state.copyWith(
      photoResolution: const ImportMediaResolution(
        resolvedPathByIndex: {0: '/p/b.jpg'},
        reRootedCount: 0,
        filenameOnlyCount: 0,
        notFoundCount: 0,
      ),
    );

    // Same mapping, same media: the resolution stays.
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.photoResolution, isNotNull);

    // Skipping Bo removes his photo, so the resolution no longer lines up.
    notifier.setDiverTarget(_bo, const SkipDiverTarget());
    notifier.applyDiverMapping(activeDiverId: 'me');
    expect(notifier.state.photoResolution, isNull);
  });

  test('clearing the payload clears the diver state', () {
    notifier.initDiverMapping(profiles: [_me], activeDiverId: 'me');
    notifier.applyDiverMapping(activeDiverId: 'me');
    notifier.state = notifier.state.copyWith(clearPayload: true);
    expect(notifier.state.sourcePayload, isNull);
    expect(notifier.state.diverMapping, isEmpty);
    expect(notifier.state.parsedPayload, isNull);
  });
}
