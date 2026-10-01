import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2596: a diver could not find how to change an imported dive's type.
/// The picker saved fine, but it sat inside the Conditions group, which is
/// collapsed by default, does not mount its rows while collapsed, and whose
/// header reads "Add conditions - water, visibility, weather". These tests pin
/// the picker to the always-open "The Dive" group and prove a type changed
/// there reaches storage.
void main() {
  late DiveRepository repository;
  final epoch = DateTime(2026);

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DiveTypeEntity diveType(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: epoch,
    updatedAt: epoch,
  );

  /// A dive as a computer download leaves it: typed recreational by default.
  Dive importedDive() => Dive(
    id: 'dive-imported',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 45.0,
    importSource: 'dive_computer',
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<void> pumpEditPage(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          diveTypesProvider.overrideWith(
            (ref) async => [
              diveType('recreational', 'Recreational'),
              diveType('technical', 'Technical'),
            ],
          ),
        ],
        locale: const Locale('en'),
        child: DiveEditPage(diveId: diveId, embedded: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the dive type picker shows without expanding any group', (
    tester,
  ) async {
    final created = await repository.createDive(importedDive());
    await pumpEditPage(tester, created.id);

    final picker = find.descendant(
      of: find.byType(TheDiveSection),
      matching: find.byType(DiveTypeMultiSelectField),
    );
    expect(picker, findsOneWidget);
    expect(tester.widget<DiveTypeMultiSelectField>(picker).selectedTypeIds, [
      'recreational',
    ]);
  });

  testWidgets('the Conditions group no longer holds the dive type picker', (
    tester,
  ) async {
    final created = await repository.createDive(importedDive());
    await pumpEditPage(tester, created.id);

    final header = find.text('Conditions');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ConditionsSection),
        matching: find.byType(DiveTypeMultiSelectField),
      ),
      findsNothing,
    );
    expect(find.byType(DiveTypeMultiSelectField), findsOneWidget);
  });

  testWidgets('an imported dive saves the type the diver picks', (
    tester,
  ) async {
    final created = await repository.createDive(importedDive());
    await pumpEditPage(tester, created.id);

    // Sets the types the way the diver's picker does.
    tester
        .widget<DiveTypeMultiSelectField>(
          find.descendant(
            of: find.byType(TheDiveSection),
            matching: find.byType(DiveTypeMultiSelectField),
          ),
        )
        .onChanged(['technical']);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repository.getDiveById(created.id);
    expect(saved!.diveTypeIds, ['technical']);
  });
}
