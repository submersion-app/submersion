import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the wiring of [diveTypesAfterSiteAssign] into the dive editor
/// (issue #2037): assigning a site adds the dive types its site types stand
/// for.
///
/// Prefill is the vehicle because it and the site picker share the one
/// `_assignSite` funnel. The rule's own branches (taking back, sticky manual
/// edits, the never-empty guard) are covered by
/// test/features/dive_log/presentation/utils/dive_type_autofill_test.dart.
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

  SiteTypeEntity siteType(String id, String name) => SiteTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: epoch,
    updatedAt: epoch,
  );

  /// New-dive pages host a continuous animation, so pumpAndSettle never
  /// settles; a bounded pump loop drains async work and animations instead.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpNewDivePage(
    WidgetTester tester, {
    List<SiteTypeEntity> siteTypes = const [],
    Object? siteTypesError,
    Future<List<SiteTypeEntity>>? siteTypesFuture,
    void Function(String savedId)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          diveTypesProvider.overrideWith(
            (ref) async => [
              diveType('recreational', 'Recreational'),
              diveType('wreck', 'Wreck'),
              diveType('cave', 'Cave'),
            ],
          ),
          siteTypesForSiteProvider('site-1').overrideWith((ref) async {
            if (siteTypesError != null) throw siteTypesError;
            return siteTypesFuture ?? siteTypes;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              embedded: true,
              prefill: const DivePrefill(
                site: DiveSite(id: 'site-1', name: 'Thistlegorm'),
              ),
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  /// The Conditions section is collapsed by default and its children are not
  /// mounted while collapsed. The whole header row is the toggle tap target.
  Future<void> expandConditions(WidgetTester tester) async {
    final header = find.text('Conditions');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await pumpFrames(tester);
  }

  List<String> selectedDiveTypeIds(WidgetTester tester) => tester
      .widget<DiveTypeMultiSelectField>(find.byType(DiveTypeMultiSelectField))
      .selectedTypeIds;

  testWidgets('a wreck site adds the wreck dive type', (tester) async {
    await pumpNewDivePage(
      tester,
      siteTypes: [siteType('wreck', 'Wreck'), siteType('reef', 'Reef')],
    );
    await expandConditions(tester);

    expect(selectedDiveTypeIds(tester), ['recreational', 'wreck']);
  });

  /// Sets the dive types the way the diver's picker does.
  Future<void> pickDiveTypes(WidgetTester tester, List<String> ids) async {
    tester
        .widget<DiveTypeMultiSelectField>(find.byType(DiveTypeMultiSelectField))
        .onChanged(ids);
    await pumpFrames(tester);
  }

  Future<void> clearSite(WidgetTester tester) async {
    tester.widget<TheDiveSection>(find.byType(TheDiveSection)).onClearSite!();
    await pumpFrames(tester);
  }

  testWidgets('clearing the site takes back the type it added', (tester) async {
    await pumpNewDivePage(tester, siteTypes: [siteType('wreck', 'Wreck')]);
    await expandConditions(tester);

    await clearSite(tester);

    expect(selectedDiveTypeIds(tester), ['recreational']);
  });

  testWidgets('a type the diver re-ticks by hand survives clearing the site', (
    tester,
  ) async {
    await pumpNewDivePage(tester, siteTypes: [siteType('wreck', 'Wreck')]);
    await expandConditions(tester);

    await pickDiveTypes(tester, ['recreational']);
    await pickDiveTypes(tester, ['recreational', 'wreck']);
    await clearSite(tester);

    expect(selectedDiveTypeIds(tester), ['recreational', 'wreck']);
  });

  testWidgets('a failed read of the site types leaves the dive types alone', (
    tester,
  ) async {
    await pumpNewDivePage(tester, siteTypesError: StateError('db closed'));
    await expandConditions(tester);

    expect(selectedDiveTypeIds(tester), ['recreational']);
  });

  testWidgets('a save tapped before the site types arrive keeps them', (
    tester,
  ) async {
    // The saved dive points at the site, so it must exist.
    await tester.runAsync(
      () => SiteRepository().createSite(
        const DiveSite(id: 'site-1', name: 'Thistlegorm'),
      ),
    );
    final lookup = Completer<List<SiteTypeEntity>>();
    String? savedId;
    await pumpNewDivePage(
      tester,
      siteTypesFuture: lookup.future,
      onSaved: (id) => savedId = id,
    );

    await tester.tap(find.text('Save'));
    await pumpFrames(tester);
    expect(savedId, isNull, reason: 'the save must wait for the snap');

    lookup.complete([siteType('wreck', 'Wreck')]);
    for (var i = 0; i < 100 && savedId == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(savedId, isNotNull);
    final saved = await tester.runAsync(() => repository.getDiveById(savedId!));
    expect(saved!.diveTypeIds, containsAll(['recreational', 'wreck']));
  });

  testWidgets('a site with no matching type leaves the dive types alone', (
    tester,
  ) async {
    await pumpNewDivePage(tester, siteTypes: [siteType('reef', 'Reef')]);
    await expandConditions(tester);

    expect(selectedDiveTypeIds(tester), ['recreational']);
  });
}
