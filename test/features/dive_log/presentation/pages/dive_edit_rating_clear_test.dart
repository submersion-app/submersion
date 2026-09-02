import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1333: a diver who set a star rating by accident had no way back to
/// no rating at all. The row-level gestures are covered in
/// test/shared/widgets/forms/form_row_test.dart; what these tests pin is the
/// hop between them and storage, where the page turns zero stars into the null
/// the dives table needs. Zero and null are both falsy-looking and the entity
/// accepts either, so nothing but an end-to-end save catches a regression here.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive({int? rating}) => Dive(
    id: 'dive-rating',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    rating: rating,
    tanks: const [],
    profile: const [],
    equipment: const [],
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
        ],
        locale: const Locale('en'),
        child: DiveEditPage(diveId: diveId, embedded: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The group is collapsed by default and does not mount its rows until it
  /// opens; the header row is the toggle.
  Future<void> expandExperience(WidgetTester tester) async {
    final header = find.text('Experience');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the clear affordance saves the dive with no rating', (
    tester,
  ) async {
    final created = await repository.createDive(buildDive(rating: 4));
    await pumpEditPage(tester, created.id);
    await expandExperience(tester);

    expect(find.byIcon(Icons.star), findsNWidgets(4));
    await tester.tap(find.byTooltip('Clear rating'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsNothing);

    await save(tester);

    final saved = await repository.getDiveById(created.id);
    expect(saved!.rating, isNull);
  });

  testWidgets('re-tapping the current rating saves the dive with no rating', (
    tester,
  ) async {
    final created = await repository.createDive(buildDive(rating: 4));
    await pumpEditPage(tester, created.id);
    await expandExperience(tester);

    await tester.tap(find.byIcon(Icons.star).at(3));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsNothing);

    await save(tester);

    final saved = await repository.getDiveById(created.id);
    expect(saved!.rating, isNull);
  });

  testWidgets('an untouched rating survives an open and save', (tester) async {
    final created = await repository.createDive(buildDive(rating: 4));
    await pumpEditPage(tester, created.id);
    await expandExperience(tester);

    await save(tester);

    final saved = await repository.getDiveById(created.id);
    expect(saved!.rating, 4);
  });
}
