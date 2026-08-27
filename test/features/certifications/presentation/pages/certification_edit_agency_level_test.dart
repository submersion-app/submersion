import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late CertificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> buildHarness(
    WidgetTester tester, {
    String? certificationId,
  }) async {
    // The open dropdown is a lazy ListView clipped to the surface, so items
    // past the fold are not in the widget tree at all. The longest menu
    // (PADI: "Not specified" + 2 headers + 9 ladder + 10 specialties +
    // "Other") needs roughly 1050px, so give every test a tall surface
    // rather than scrolling in each one.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...overrides,
        certificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CertificationEditPage(
            certificationId: certificationId,
            embedded: true,
          ),
        ),
      ),
    );
  }

  Finder agencyDropdown() =>
      find.byType(DropdownButtonFormField<CertificationAgency>);
  // The certification dropdown is keyed by CertificationOption, not
  // CertificationLevel: group headers need their own distinct values so no
  // two rows share one (see CertificationOption's doc comment).
  Finder levelDropdown() =>
      find.byType(DropdownButtonFormField<CertificationOption>);

  // The "Name on card" hint renders the derived title, so a bare find.text
  // for a certification matches both the dropdown and the hint. Scope to the
  // dropdown when asserting what is selected.
  Finder selectedCertification(String label) =>
      find.descendant(of: levelDropdown(), matching: find.text(label));

  Future<void> selectFromDropdown(
    WidgetTester tester,
    Finder dropdown,
    String optionLabel,
  ) async {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The overlay duplicates the selected item's label; .last hits the menu.
    // The menu's internal ListView only mounts items within its sliver
    // cache extent, so a plain finder can miss items below the fold -
    // scrollUntilVisible drags the menu's Scrollable until the item is
    // actually built before ensureVisible/tap touch it. Use the unmodified
    // finder here (not `.last`), since `.last` throws on zero matches
    // instead of reporting "not found yet".
    await tester.scrollUntilVisible(
      find.text(optionLabel),
      100.0,
      scrollable: find.byType(Scrollable).last,
    );
    final item = find.text(optionLabel).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets('agency dropdown appears above level dropdown', (tester) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(agencyDropdown()).dy,
      lessThan(tester.getTopLeft(levelDropdown()).dy),
    );
  });

  testWidgets('selecting CMAS restricts levels to CMAS grades + specialties', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('2★ Diver'), findsOneWidget);
    expect(find.text('Nitrox'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('switching agency resets an incompatible level', (tester) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    // Default agency is PADI; pick a PADI-ladder level.
    await selectFromDropdown(tester, levelDropdown(), 'Advanced Open Water');
    expect(selectedCertification('Advanced Open Water'), findsOneWidget);

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(selectedCertification('Advanced Open Water'), findsNothing);
    expect(selectedCertification('Not specified'), findsOneWidget);
  });

  testWidgets('switching agency keeps a compatible (specialty) level', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, levelDropdown(), 'Nitrox');
    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(selectedCertification('Nitrox'), findsOneWidget);
  });

  testWidgets(
    'existing record with out-of-catalog level renders and survives save',
    (tester) async {
      final now = DateTime(2024);
      final cert = await repository.createCertification(
        Certification(
          id: '',
          name: 'Legacy CMAS card',
          agency: CertificationAgency.cmas,
          level: CertificationLevel.advancedOpenWater,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        await buildHarness(tester, certificationId: cert.id),
      );
      await tester.pumpAndSettle();

      // Stored level renders even though it is not in the CMAS catalog.
      expect(selectedCertification('Advanced Open Water'), findsOneWidget);

      // Save without touching agency or level; the value must survive.
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 1));

      final saved = await tester.runAsync(
        () => repository.getCertificationById(cert.id),
      );
      expect(saved!.level, CertificationLevel.advancedOpenWater);
      expect(saved.agency, CertificationAgency.cmas);
    },
  );

  testWidgets('certification dropdown shows group headers', (tester) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Specialties'), findsOneWidget);
  });

  testWidgets('group headers are not selectable', (tester) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progression'));
    await tester.pumpAndSettle();

    // The menu is still open and nothing was selected.
    expect(find.text('Specialties'), findsOneWidget);
  });

  testWidgets('closed dropdown shows Not specified, not a group header', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    expect(selectedCertification('Not specified'), findsOneWidget);
    expect(find.text('Progression'), findsNothing);
  });
}
