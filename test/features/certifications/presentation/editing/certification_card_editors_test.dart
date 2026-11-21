import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_agency_dropdown.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Each certification card editor sets only its own card's values (issue
/// #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();

  Certification cert() => Certification(
    id: 'c1',
    name: 'My card',
    agency: 'padi',
    level: 'openWater',
    cardNumber: '123',
    instructorName: 'Jo',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  Future<void> pumpEditor(WidgetTester tester, Widget editor) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(body: SingleChildScrollView(child: editor)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Details sets only Details', (tester) async {
    final session = EditSession(cert());
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDetailsCardEditor(session: session));

    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-card-number')),
      '456',
    );
    await tester.enterText(find.byKey(const ValueKey('cert-edit-title')), 'X');
    await tester.tap(find.byKey(const ValueKey('cert-edit-add-recognition')));
    await tester.pumpAndSettle();

    expect(session.changedCardIds, {'details'});
    expect(session.working.cardNumber, '456');
    expect(session.working.name, 'X');
    expect(session.working.additionalCredentials, hasLength(1));
  });

  String textOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  Finder levelField(int i) =>
      find.byType(DropdownButtonFormField<CertificationOption>).at(i);

  testWidgets('Details opens on the stored values, under the title\'s label '
      'and helper', (tester) async {
    final session = EditSession(cert());
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDetailsCardEditor(session: session));

    expect(textOf(tester, 'cert-edit-title'), 'My card');
    expect(textOf(tester, 'cert-edit-card-number'), '123');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cert-edit-agency-0')),
        matching: find.text('PADI'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: levelField(0), matching: find.text('Open Water')),
      findsOneWidget,
    );
    expect(find.text(l.certifications_edit_label_title), findsOneWidget);
    expect(find.text(l.certifications_edit_helper_title), findsOneWidget);
  });

  testWidgets('one recognition has no remove button; adding one gives each '
      'row its own', (tester) async {
    final session = EditSession(cert());
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDetailsCardEditor(session: session));
    final remove = find.byTooltip(l.certifications_edit_removeRecognition);

    expect(find.byKey(const ValueKey('cert-edit-agency-1')), findsNothing);
    expect(remove, findsNothing);

    await tester.tap(find.byKey(const ValueKey('cert-edit-add-recognition')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cert-edit-agency-1')), findsOneWidget);
    expect(remove, findsNWidgets(2));

    await tester.tap(remove.last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cert-edit-agency-1')), findsNothing);
    expect(remove, findsNothing);
    expect(session.working.additionalCredentials, isEmpty);
    expect(session.working.level, 'openWater');
  });

  testWidgets('a stored card with two recognitions shows a row each', (
    tester,
  ) async {
    final session = EditSession(
      cert().copyWith(
        additionalCredentials: const [
          CertificationCredential(agency: 'ssi', level: 'nitrox'),
        ],
      ),
    );
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDetailsCardEditor(session: session));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cert-edit-agency-1')),
        matching: find.text('SSI'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: levelField(1), matching: find.text('Nitrox')),
      findsOneWidget,
    );
    expect(session.isDirty, isFalse);
  });

  testWidgets('a new certification\'s title stays blank when a level is '
      'picked', (tester) async {
    final session = EditSession(Certification.empty());
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDetailsCardEditor(session: session));
    expect(textOf(tester, 'cert-edit-title'), isEmpty);

    await tester.tap(levelField(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Water').last);
    await tester.pumpAndSettle();

    expect(session.working.level, 'openWater');
    expect(session.working.name, isEmpty);
    expect(textOf(tester, 'cert-edit-title'), isEmpty);
  });

  // A stored name that only repeats the agency and level (the old form
  // filled it in until 2026-08) shows blank, so the hint offers the
  // derived title instead of repeating it.
  group('a derived title', () {
    Certification derived() => cert().copyWith(name: 'PADI : Open Water');

    String titleText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('cert-edit-title')))
        .controller!
        .text;

    testWidgets('shows blank, and opening it changes nothing', (tester) async {
      final session = EditSession(derived());
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      expect(titleText(tester), isEmpty);
      expect(session.isDirty, isFalse);
    });

    testWidgets('a custom title still shows', (tester) async {
      final session = EditSession(cert());
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      expect(titleText(tester), 'My card');
    });

    testWidgets('is cleared with the agency it repeated', (tester) async {
      final session = EditSession(derived());
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      tester
          .widget<CertificationAgencyDropdown>(
            find.byKey(const ValueKey('cert-edit-agency-0')),
          )
          .onChanged('ssi');
      await tester.pumpAndSettle();

      expect(session.working.agency, 'ssi');
      expect(session.working.name, isEmpty);
      expect(titleText(tester), isEmpty);
    });

    // The custom catalog can arrive, or change on a sync, after the editor
    // opens: whether a title repeats its credentials follows it.
    testWidgets('follows the catalog when it changes under an open editor', (
      tester,
    ) async {
      final catalog = StateProvider<CertificationCatalog>(
        (ref) => CertificationCatalog.builtInOnly,
      );
      final clubX = CertificationCatalog(
        agencies: [
          CustomCertificationAgency(
            id: 'u1',
            diverId: 'a',
            name: 'Club X',
            colorArgb: 0xFF3B82F6,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );
      final session = EditSession(
        Certification(
          id: 'c1',
          name: 'Club X',
          agency: 'u1',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
      addTearDown(session.dispose);
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            catalog,
            certificationCatalogSyncProvider.overrideWith(
              (ref) => ref.watch(catalog),
            ),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              child: CertificationDetailsCardEditor(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CertificationDetailsCardEditor)),
      );
      expect(titleText(tester), 'Club X');

      container.read(catalog.notifier).state = clubX;
      await tester.pumpAndSettle();
      expect(titleText(tester), isEmpty);

      container.read(catalog.notifier).state = CertificationCatalog.builtInOnly;
      await tester.pumpAndSettle();
      expect(titleText(tester), 'Club X');
      expect(session.isDirty, isFalse);
    });

    testWidgets('a title typed in the sitting stays when the level changes', (
      tester,
    ) async {
      final session = EditSession(cert().copyWith(name: ''));
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      await tester.enterText(
        find.byKey(const ValueKey('cert-edit-title')),
        'Open Water',
      );
      await tester.pumpAndSettle();
      await tester.tap(levelField(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced Open Water').last);
      await tester.pumpAndSettle();

      expect(session.working.level, 'advancedOpenWater');
      expect(session.working.name, 'Open Water');
      expect(titleText(tester), 'Open Water');
    });

    testWidgets('stays as stored when only a recognition is added', (
      tester,
    ) async {
      final session = EditSession(derived());
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      await tester.tap(find.byKey(const ValueKey('cert-edit-add-recognition')));
      await tester.pumpAndSettle();

      expect(session.working.name, 'PADI : Open Water');
      expect(titleText(tester), isEmpty);
    });

    // The menu opens on the selected level, scrolled: the one to pick may
    // be out of its view.
    Future<void> pickLevel(WidgetTester tester, String level) async {
      await tester.tap(levelField(0));
      await tester.pumpAndSettle();
      final item = find.text(level).last;
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    testWidgets('comes back with the level it repeats, leaving nothing to '
        'save', (tester) async {
      final session = EditSession(derived());
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      await pickLevel(tester, 'Advanced Open Water');
      expect(session.working.name, isEmpty);
      await pickLevel(tester, 'Open Water');

      expect(session.working.name, 'PADI : Open Water');
      expect(session.isDirty, isFalse);
      expect(titleText(tester), isEmpty);
    });

    // Typing the stored text is no change to the sitting, but it is the
    // diver's title now.
    testWidgets('the stored text typed back stays when the level changes', (
      tester,
    ) async {
      final session = EditSession(derived());
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );

      await tester.enterText(
        find.byKey(const ValueKey('cert-edit-title')),
        'PADI : Open Water',
      );
      await tester.pumpAndSettle();
      await pickLevel(tester, 'Advanced Open Water');

      expect(session.working.name, 'PADI : Open Water');
      expect(titleText(tester), 'PADI : Open Water');
    });

    // Only a title shown blank follows the credentials: one the diver can
    // see is theirs, even while a level picked on the way repeats it.
    testWidgets('a custom title shown stays when the level passes through '
        'one it repeats', (tester) async {
      final session = EditSession(
        Certification(
          id: 'c1',
          name: 'Open Water',
          agency: 'padi',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
      addTearDown(session.dispose);
      await pumpEditor(
        tester,
        CertificationDetailsCardEditor(session: session),
      );
      expect(titleText(tester), 'Open Water');

      await pickLevel(tester, 'Open Water');
      await pickLevel(tester, 'Advanced Open Water');

      expect(session.working.level, 'advancedOpenWater');
      expect(session.working.name, 'Open Water');
      expect(titleText(tester), 'Open Water');
    });
  });

  testWidgets('Instructor sets only Instructor', (tester) async {
    final session = EditSession(cert());
    addTearDown(session.dispose);
    await pumpEditor(
      tester,
      CertificationInstructorCardEditor(session: session),
    );

    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-instructor-number')),
      '77',
    );
    await tester.pumpAndSettle();

    expect(session.changedCardIds, {'instructor'});
    expect(session.working.instructorNumber, '77');
    expect(session.working.instructorName, 'Jo');
  });

  testWidgets('Card photos sets only Card photos', (tester) async {
    final session = EditSession(cert());
    addTearDown(session.dispose);
    await pumpEditor(
      tester,
      CertificationCardPhotosEditor(
        session: session,
        pickPhoto: (_) async => Uint8List.fromList([5]),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(session.changedCardIds, {'cardPhotos'});
    expect(session.working.photoFront, [5]);
  });

  testWidgets('Dates sets the issue date from the picker', (tester) async {
    final session = EditSession(
      cert().copyWith(issueDate: DateTime(2024, 3, 10)),
    );
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDatesCardEditor(session: session));

    await tester.tap(find.byKey(const ValueKey('cert-edit-issue-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(session.changedCardIds, {'dates'});
    expect(session.working.issueDate, DateTime(2024, 3, 15));
  });

  testWidgets('Dates clears an expiry as a change of Dates', (tester) async {
    final session = EditSession(cert().copyWith(expiryDate: DateTime(2030)));
    addTearDown(session.dispose);
    await pumpEditor(tester, CertificationDatesCardEditor(session: session));

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(session.changedCardIds, {'dates'});
    expect(session.working.expiryDate, isNull);
  });
}
