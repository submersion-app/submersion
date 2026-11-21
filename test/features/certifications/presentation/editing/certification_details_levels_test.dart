import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The Details editor's agency and certification menus (issue #4527, phase
/// 3): the level menu follows the row's agency, in its own groups.
void main() {
  late CustomCertificationRepository customRepository;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('owner-1', 'Owner', 0, 0)",
    );
    customRepository = CustomCertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A stored certification of [agency] at [level].
  Certification stored(String name, String agency, String level) =>
      Certification(
        id: 'c1',
        name: name,
        agency: agency,
        level: level,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

  /// The Details editor over [cert], a new certification's seed (PADI, no
  /// level) when null.
  Future<EditSession<Certification>> pumpEditor(
    WidgetTester tester, [
    Certification? cert,
  ]) async {
    // The open dropdown is a lazy ListView clipped to the surface, so items
    // past the fold are not in the widget tree at all. The longest menu
    // (PADI: "Not specified" + 2 headers + 9 ladder + 10 specialties +
    // "Other") needs roughly 1050px, so give every test a tall surface
    // rather than scrolling in each one.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final session = EditSession(cert ?? Certification.empty());
    addTearDown(session.dispose);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: SingleChildScrollView(
            child: CertificationDetailsCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Finder agencyDropdown() => find.byType(DropdownButtonFormField<String>);
  // The certification dropdown is keyed by CertificationOption, not
  // CertificationLevel: group headers need their own distinct values so no
  // two rows share one (see CertificationOption's doc comment).
  Finder levelDropdown() =>
      find.byType(DropdownButtonFormField<CertificationOption>);

  // The "Certification title" hint renders the derived title, so a bare find.text
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
    await pumpEditor(tester);

    expect(
      tester.getTopLeft(agencyDropdown()).dy,
      lessThan(tester.getTopLeft(levelDropdown()).dy),
    );
  });

  testWidgets('selecting CMAS restricts levels to CMAS grades + specialties', (
    tester,
  ) async {
    await pumpEditor(tester);

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
    final session = await pumpEditor(tester);

    // Default agency is PADI; pick a PADI-ladder level.
    await selectFromDropdown(tester, levelDropdown(), 'Advanced Open Water');
    expect(selectedCertification('Advanced Open Water'), findsOneWidget);

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(selectedCertification('Advanced Open Water'), findsNothing);
    expect(selectedCertification('Not specified'), findsOneWidget);
    expect(session.working.agency, CertificationAgency.cmas.name);
    expect(session.working.level, isNull);
  });

  testWidgets('switching agency keeps a compatible (specialty) level', (
    tester,
  ) async {
    await pumpEditor(tester);

    await selectFromDropdown(tester, levelDropdown(), 'Nitrox');
    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(selectedCertification('Nitrox'), findsOneWidget);
  });

  for (final agency in ['PADI', 'SDI']) {
    testWidgets('$agency offers Master Instructor (issue #3194)', (
      tester,
    ) async {
      await pumpEditor(tester);

      // PADI is the default agency; re-selecting it would match both the
      // closed button and its menu row.
      if (agency == 'PADI') {
        expect(
          find.descendant(of: agencyDropdown(), matching: find.text('PADI')),
          findsOneWidget,
        );
      } else {
        await selectFromDropdown(tester, agencyDropdown(), agency);
      }
      await selectFromDropdown(tester, levelDropdown(), 'Master Instructor');

      expect(selectedCertification('Master Instructor'), findsOneWidget);
    });
  }

  testWidgets('a stored level outside its agency\'s catalog renders and is '
      'left as it is', (tester) async {
    final session = await pumpEditor(
      tester,
      stored(
        'Legacy CMAS card',
        CertificationAgency.cmas.name,
        CertificationLevel.advancedOpenWater.name,
      ),
    );

    // Stored level renders even though it is not in the CMAS catalog, and
    // opening the editor does not rewrite it.
    expect(selectedCertification('Advanced Open Water'), findsOneWidget);
    expect(session.isDirty, isFalse);
  });

  testWidgets('certification dropdown shows group headers', (tester) async {
    await pumpEditor(tester);

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Specialties'), findsOneWidget);
  });

  testWidgets('group headers are not selectable', (tester) async {
    await pumpEditor(tester);

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
    await pumpEditor(tester);

    expect(selectedCertification('Not specified'), findsOneWidget);
    expect(find.text('Progression'), findsNothing);
  });

  testWidgets(
    'TDI shows its own five course categories, not Progression/Specialties '
    '(issue #3072)',
    (tester) async {
      await pumpEditor(tester);

      await selectFromDropdown(tester, agencyDropdown(), 'TDI');

      await tester.ensureVisible(levelDropdown());
      await tester.pumpAndSettle();
      await tester.tap(levelDropdown());
      await tester.pumpAndSettle();

      expect(find.text('Open Circuit'), findsOneWidget);
      expect(find.text('Progression'), findsNothing);
      expect(find.text('Specialties'), findsNothing);

      // TDI's menu (five headers + 34 courses) is far longer than the fold,
      // so later groups need scrolling into the lazy menu list first.
      final menuScrollable = find.byType(Scrollable).last;
      for (final label in const [
        'Rebreather',
        'Service',
        'Overhead',
        'Professional',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          100.0,
          scrollable: menuScrollable,
        );
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets(
    'a legacy ambiguous TDI level (techDiver) renders under the Specialties '
    'catch-all, not headerless after Professional (issue #3072)',
    (tester) async {
      await pumpEditor(
        tester,
        stored(
          'Tech Diver card',
          CertificationAgency.tdi.name,
          CertificationLevel.techDiver.name,
        ),
      );

      expect(selectedCertification('Tech Diver'), findsOneWidget);

      await tester.ensureVisible(levelDropdown());
      await tester.pumpAndSettle();
      await tester.tap(levelDropdown());
      await tester.pumpAndSettle();

      final menuScrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('Tech Diver').last,
        100.0,
        scrollable: menuScrollable,
      );
      // Without the fix, a legacy value with no TDI category rendered with
      // no header of its own right after the last category block
      // (Professional), so it visually read as belonging there. Fixed, it
      // gets its own Specialties catch-all header, same as a custom level.
      expect(find.text('Specialties'), findsOneWidget);
      expect(find.text('Tech Diver').last, findsOneWidget);
    },
  );

  testWidgets("a diver's own custom level under TDI still renders, under a "
      'catch-all Specialties group (issue #3072)', (tester) async {
    final custom = await customRepository.createLevel(
      diverId: 'owner-1',
      agencyId: CertificationAgency.tdi.name,
      name: 'Club Technical Diver',
      isProgression: false,
      isShared: true,
    );
    await pumpEditor(
      tester,
      stored('Club Technical Diver', CertificationAgency.tdi.name, custom.id),
    );

    // The custom level still renders as the selected value.
    expect(selectedCertification('Club Technical Diver'), findsOneWidget);

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    final menuScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Club Technical Diver').last,
      100.0,
      scrollable: menuScrollable,
    );
    expect(find.text('Club Technical Diver').last, findsOneWidget);
    expect(find.text('Specialties'), findsOneWidget);
  });

  testWidgets(
    'IART shows its own five course categories, not Progression/Specialties '
    '(issue #3357)',
    (tester) async {
      await pumpEditor(tester);

      await selectFromDropdown(tester, agencyDropdown(), 'IART');

      await tester.ensureVisible(levelDropdown());
      await tester.pumpAndSettle();
      await tester.tap(levelDropdown());
      await tester.pumpAndSettle();

      expect(find.text('Open Circuit'), findsOneWidget);
      expect(find.text('Progression'), findsNothing);
      expect(find.text('Specialties'), findsNothing);

      final menuScrollable = find.byType(Scrollable).last;
      for (final label in const [
        'Rebreather',
        'Overhead',
        'Service',
        'Professional',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          100.0,
          scrollable: menuScrollable,
        );
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets("a diver's own custom level under IART still renders, under a "
      'catch-all Specialties group (issue #3357)', (tester) async {
    final custom = await customRepository.createLevel(
      diverId: 'owner-1',
      agencyId: CertificationAgency.iart.name,
      name: 'Club Rebreather Diver',
      isProgression: false,
      isShared: true,
    );
    await pumpEditor(
      tester,
      stored('Club Rebreather Diver', CertificationAgency.iart.name, custom.id),
    );

    expect(selectedCertification('Club Rebreather Diver'), findsOneWidget);

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    final menuScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Club Rebreather Diver').last,
      100.0,
      scrollable: menuScrollable,
    );
    expect(find.text('Club Rebreather Diver').last, findsOneWidget);
    expect(find.text('Specialties'), findsOneWidget);
  });
}
