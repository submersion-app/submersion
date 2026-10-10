import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Opening a saved dive with no water type of its own shows its site's, as
/// the detail page does through `Dive.effectiveWaterType` (issue #3196).
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> createDiveAtSite({
    required WaterType? siteWater,
    WaterType? diveWater,
  }) async {
    final site = await SiteRepository().createSite(
      DiveSite(id: '', name: 'Blue Hole', waterType: siteWater),
    );
    return repository.createDive(
      Dive(
        id: 'dive-water',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryTime: DateTime(2026, 3, 28, 10, 5),
        bottomTime: const Duration(minutes: 40),
        maxDepth: 20.0,
        site: site,
        waterType: diveWater,
        tanks: const [],
        profile: const [],
        gear: looseGear(const []),
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      ),
    );
  }

  Future<void> pumpExistingDivePage(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
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

  /// The Conditions section is collapsed by default and its children are not
  /// mounted while collapsed.
  Future<void> expandConditions(WidgetTester tester) async {
    final header = find.text('Conditions');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  testWidgets('a dive with no water type shows and saves the site one', (
    tester,
  ) async {
    final dive = await createDiveAtSite(siteWater: WaterType.salt);
    await pumpExistingDivePage(tester, dive.id);
    await expandConditions(tester);

    expect(find.text('Salt Water'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await repository.getDiveById(dive.id))!.waterType, WaterType.salt);
  });

  testWidgets('the dive own water type wins over the site one', (tester) async {
    final dive = await createDiveAtSite(
      siteWater: WaterType.salt,
      diveWater: WaterType.fresh,
    );
    await pumpExistingDivePage(tester, dive.id);
    await expandConditions(tester);

    expect(find.text('Fresh Water'), findsOneWidget);
    expect(find.text('Salt Water'), findsNothing);
  });

  testWidgets('clearing the site drops a water type it only lent', (
    tester,
  ) async {
    final dive = await createDiveAtSite(siteWater: WaterType.salt);
    await pumpExistingDivePage(tester, dive.id);

    final siteRow = find.ancestor(
      of: find.text('Blue Hole'),
      matching: find.byType(FormRow),
    );
    await tester.tap(
      find.descendant(of: siteRow, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repository.getDiveById(dive.id))!;
    expect(saved.site, isNull);
    expect(saved.waterType, isNull);
  });

  testWidgets('clearing the site keeps a water type the dive owns', (
    tester,
  ) async {
    final dive = await createDiveAtSite(
      siteWater: WaterType.salt,
      diveWater: WaterType.brackish,
    );
    await pumpExistingDivePage(tester, dive.id);

    final siteRow = find.ancestor(
      of: find.text('Blue Hole'),
      matching: find.byType(FormRow),
    );
    await tester.tap(
      find.descendant(of: siteRow, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getDiveById(dive.id))!.waterType,
      WaterType.brackish,
    );
  });

  testWidgets('a water type picked by hand survives clearing the site', (
    tester,
  ) async {
    final dive = await createDiveAtSite(siteWater: WaterType.salt);
    await pumpExistingDivePage(tester, dive.id);
    await expandConditions(tester);

    await tester.tap(find.text('Salt Water'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Fresh Water'));
    await tester.pumpAndSettle();

    final siteRow = find.ancestor(
      of: find.text('Blue Hole'),
      matching: find.byType(FormRow),
    );
    await tester.scrollUntilVisible(
      siteRow,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(of: siteRow, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await repository.getDiveById(dive.id))!.waterType, WaterType.fresh);
  });
}
