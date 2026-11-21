import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certification_agencies/presentation/widgets/certification_agency_dropdown.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Each certification card editor sets only its own card's values (issue
/// #4527, phase 3).
void main() {
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
