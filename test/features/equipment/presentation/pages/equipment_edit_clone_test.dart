import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/data/services/initial_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_clone_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_field.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The equipment form in clone mode (issue #3184).
void main() {
  late EquipmentRepository repository;
  late EquipmentTagRepository tagRepository;
  late EquipmentItem source;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
    tagRepository = EquipmentTagRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) VALUES '
      "('owner', 'Owner', 0, 0), ('sharee', 'Sharee', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, diver_id, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', NULL, 0, 0, 0, 0, 1), "
      "('t2', 'Owner only', 'owner', 0, 0, 0, 0, 1)",
    );
    source = await repository.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Reg A',
        type: EquipmentType.regulator,
        brand: 'Apeks',
        model: 'XTX50',
        serialNumber: 'SN-1',
      ),
    );
    await tagRepository.replaceTags(source.id, ['t1', 't2']);
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpClone(
    WidgetTester tester, {
    List<Object> extraOverrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  context.push('/equipment/new?cloneFrom=${source.id}'),
              child: const Text('OPEN CLONE'),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/new',
          builder: (context, state) => EquipmentEditPage(
            cloneFromId: state.uri.queryParameters['cloneFrom'],
          ),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
          ...extraOverrides,
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN CLONE'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String label) => tester
      .widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('opens titled Clone Equipment and pre-filled from the source', (
    tester,
  ) async {
    await pumpClone(tester);

    expect(find.text('Clone Equipment'), findsOneWidget);
    expect(fieldText(tester, 'Name *'), 'Reg A (copy)');
    expect(fieldText(tester, 'Brand'), 'Apeks');
    expect(fieldText(tester, 'Model'), 'XTX50');
    expect(fieldText(tester, 'Serial Number'), isEmpty);
  });

  testWidgets('starts with the source\'s tags', (tester) async {
    await pumpClone(tester);

    expect(find.widgetWithText(TagChip, 'Travel kit'), findsOneWidget);
    expect(find.widgetWithText(TagChip, 'Owner only'), findsOneWidget);
  });

  testWidgets('a sharee\'s clone leaves the owner\'s own tags behind', (
    tester,
  ) async {
    await pumpClone(
      tester,
      extraOverrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'sharee'),
      ],
    );

    expect(find.widgetWithText(TagChip, 'Travel kit'), findsOneWidget);
    expect(find.widgetWithText(TagChip, 'Owner only'), findsNothing);
  });

  group('first location', () {
    Future<void> placeSource(String? owner) async {
      final place = await EquipmentLocationRepository().createLocation(
        diverId: owner,
        name: 'Garage',
        kind: EquipmentLocationKind.storage,
      );
      await recordInitialLocation(
        moves: EquipmentLocationMoveRepository(),
        equipmentId: source.id,
        locationId: place.id,
      );
    }

    testWidgets('starts at the source\'s place, and saving puts it there', (
      tester,
    ) async {
      await placeSource(null);
      await pumpClone(tester);

      expect(
        find.descendant(
          of: find.byType(EquipmentLocationField),
          matching: find.text('Garage'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final clone = (await repository.getAllEquipment()).singleWhere(
        (e) => e.id != source.id,
      );
      final current = await EquipmentLocationMoveRepository()
          .getCurrentLocationIds();
      expect(current[clone.id], current[source.id]);
    });

    testWidgets('a sharee\'s clone does not start at the owner\'s place', (
      tester,
    ) async {
      await placeSource('owner');
      await pumpClone(
        tester,
        extraOverrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'sharee'),
        ],
      );

      expect(
        find.descendant(
          of: find.byType(EquipmentLocationField),
          matching: find.text('Garage'),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('saving creates the clone and opens it', (tester) async {
    await pumpClone(tester);

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    final all = await repository.getAllEquipment();
    expect(all, hasLength(2));
    final clone = all.singleWhere((e) => e.id != source.id);
    expect(
      (clone.name, clone.brand, clone.serialNumber),
      ('Reg A (copy)', 'Apeks', null),
    );
    expect(
      {for (final t in await tagRepository.getTagsForEquipment(clone.id)) t.id},
      {'t1', 't2'},
    );
    expect(find.text('DETAIL ${clone.id}'), findsOneWidget);
    expect(find.text('Equipment cloned'), findsOneWidget);
    // The original is untouched.
    final kept = await repository.getEquipmentById(source.id);
    expect((kept!.name, kept.serialNumber), ('Reg A', 'SN-1'));
  });

  testWidgets('a step that could not be copied is reported', (tester) async {
    await pumpClone(
      tester,
      extraOverrides: [
        equipmentCloneServiceProvider.overrideWithValue(_FailingCloneService()),
      ],
    );

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cloned, but some service clocks, sets or documents could not be '
        'copied.',
      ),
      findsOneWidget,
    );
    // It replaces the plain message rather than queueing behind it.
    expect(find.text('Equipment cloned'), findsNothing);
  });
}

class _FailingCloneService extends EquipmentCloneService {
  @override
  Future<Set<CloneExtrasStep>> copyExtras({
    required String sourceId,
    required String cloneId,
    required String? diverId,
  }) async => {CloneExtrasStep.documents};
}
