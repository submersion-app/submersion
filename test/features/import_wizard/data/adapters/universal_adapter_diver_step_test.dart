import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    as wizard
    show ImportEntityType;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';

const _multi = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'd1', SourceDiver.mapKey: _ann},
      {'sourceUuid': 'd2', SourceDiver.mapKey: _bo},
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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith(ImportPayload payload) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allDiversProvider.overrideWith((ref) async => [_me]),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        diveRepositoryProvider.overrideWithValue(_FakeDiveNumbers()),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(payload: payload);
    return container;
  }

  group('Divers step providers', () {
    test('a single-diver payload skips the step', () {
      final container = containerWith(const ImportPayload(entities: {}));
      expect(container.read(universalAdapterSingleDiverProvider), isTrue);
      expect(container.read(universalAdapterDiverMappingReadyProvider), isTrue);
    });

    test('a multi-diver payload waits for a mapping', () {
      final container = containerWith(_multi);
      expect(container.read(universalAdapterSingleDiverProvider), isFalse);
      expect(
        container.read(universalAdapterDiverMappingReadyProvider),
        isFalse,
      );
    });

    test(
      'Map Fields drops out of the indicator once a non-CSV parse lands',
      () {
        final before = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(before.dispose);
        // Nothing parsed yet: the step might still be needed.
        expect(before.read(universalAdapterNoFieldMappingProvider), isFalse);

        final after = containerWith(_multi);
        expect(after.read(universalAdapterNoFieldMappingProvider), isTrue);
      },
    );

    test('the step is ready once one diver imports somewhere', () {
      final container = containerWith(_multi);
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.setDiverTarget(_ann, const SkipDiverTarget());
      notifier.setDiverTarget(_bo, const SkipDiverTarget());
      expect(
        container.read(universalAdapterDiverMappingReadyProvider),
        isFalse,
      );
      notifier.setDiverTarget(_bo, const NewDiverTarget(_bo));
      expect(container.read(universalAdapterDiverMappingReadyProvider), isTrue);
    });
  });

  group('UniversalAdapter Divers step', () {
    Future<(UniversalAdapter, ProviderContainer)> adapterFor(
      WidgetTester tester,
      ImportPayload payload,
    ) async {
      final container = containerWith(payload);
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                adapter = UniversalAdapter(ref: ref);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return (adapter, container);
    }

    testWidgets('sits between Map Fields and Photos', (tester) async {
      final (adapter, _) = await adapterFor(tester, _multi);
      expect(adapter.acquisitionSteps.map((s) => s.label), [
        'Select File',
        'Confirm Source',
        'Map Fields',
        'Divers',
        'Photos',
      ]);
    });

    testWidgets('leaving Map Fields seeds the defaults', (tester) async {
      final (adapter, container) = await adapterFor(tester, _multi);
      await tester.runAsync(
        () => adapter.acquisitionSteps[2].onBeforeAdvance!(),
      );
      expect(container.read(universalImportNotifierProvider).diverMapping, {
        _ann: const ExistingDiverTarget('me'),
        _bo: const NewDiverTarget(_bo),
      });
    });

    testWidgets('leaving the Divers step expands the payload', (tester) async {
      final (adapter, container) = await adapterFor(tester, _multi);
      await tester.runAsync(() async {
        await adapter.acquisitionSteps[2].onBeforeAdvance!();
        await adapter.acquisitionSteps[3].onBeforeAdvance!();
      });
      final dives = container
          .read(universalImportNotifierProvider)
          .payload!
          .entitiesOf(ImportEntityType.dives);
      expect(dives.map((d) => d[DiverTarget.itemKey]), [
        'diver:me',
        'new:$_bo',
      ]);
    });

    testWidgets('buildBundle labels rows only across two profiles', (
      tester,
    ) async {
      final (adapter, _) = await adapterFor(
        tester,
        const ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'sourceUuid': 'd1', DiverTarget.itemKey: 'diver:me'},
              {'sourceUuid': 'd2', DiverTarget.itemKey: 'new:$_bo'},
            ],
          },
          sourceDivers: [
            SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
            SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
          ],
        ),
      );
      final bundle = (await tester.runAsync(adapter.buildBundle))!;
      final items = bundle.groups[wizard.ImportEntityType.dives]!.items;
      expect(items.map((i) => i.target?.name), ['Me', 'Bo Ray']);
      expect(items.map((i) => i.target?.isNew), [false, true]);
      expect(bundle.nextDiveNumberByTarget, {'diver:me': 7, 'new:$_bo': 1});
    });
  });
}

class _FakeDiveNumbers extends Fake implements DiveRepository {
  @override
  Future<int> getNextDiveNumber({String? diverId}) async => 7;
}
