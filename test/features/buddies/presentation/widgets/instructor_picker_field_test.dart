import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/instructor_picker_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

import '../../../../helpers/test_app.dart';

Buddy _makeBuddy(String id, String name) {
  final now = DateTime(2024, 1, 1);
  return Buddy(id: id, name: name, createdAt: now, updatedAt: now);
}

Certification _makeCertification({
  required String id,
  required String buddyId,
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level = CertificationLevel.instructor,
  String? cardNumber,
}) {
  final now = DateTime(2024, 1, 1);
  return Certification(
    id: id,
    buddyId: buddyId,
    name: 'Certification',
    agency: agency,
    level: level,
    cardNumber: cardNumber,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('InstructorPickerField', () {
    final credentialedBuddy = _makeBuddy('buddy-1', 'Alice Instructor');
    final plainBuddy = _makeBuddy('buddy-2', 'Bob Plain');
    final instructorCert = _makeCertification(
      id: 'cert-1',
      buddyId: 'buddy-1',
      agency: CertificationAgency.padi,
      level: CertificationLevel.instructor,
      cardNumber: '12345',
    );

    List<dynamic> overridesFor(
      List<Buddy> buddies,
      Map<String, List<Certification>> certsByBuddy,
      List<dynamic> extra,
    ) => [
      allBuddiesProvider.overrideWith((ref) async => buddies),
      allBuddyCertificationsProvider.overrideWith((ref) async => certsByBuddy),
      ...extra,
    ];

    testWidgets('instructor-level buddies listed first with cert annotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: overridesFor(
            [plainBuddy, credentialedBuddy],
            {
              'buddy-1': [instructorCert],
            },
            [],
          ),
          child: InstructorPickerField(
            instructorId: null,
            onSelected: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      // Instructor-level buddy is annotated with the cert label.
      expect(
        find.text('Alice Instructor (PADI Instructor #12345)'),
        findsOneWidget,
      );
      expect(find.text('Bob Plain'), findsOneWidget);

      // Instructor-level buddy appears before the plain buddy in menu order.
      final aliceCenter = tester
          .getCenter(find.text('Alice Instructor (PADI Instructor #12345)'))
          .dy;
      final bobCenter = tester.getCenter(find.text('Bob Plain')).dy;
      expect(aliceCenter, lessThan(bobCenter));
    });

    testWidgets('Master Instructor qualifies', (tester) async {
      final masterInstructorBuddy = _makeBuddy('buddy-3', 'Carol Master');
      final masterInstructorCert = _makeCertification(
        id: 'cert-2',
        buddyId: 'buddy-3',
        agency: CertificationAgency.ssi,
        level: CertificationLevel.masterInstructor,
        cardNumber: '99999',
      );

      await tester.pumpWidget(
        testApp(
          overrides: overridesFor(
            [plainBuddy, masterInstructorBuddy],
            {
              'buddy-3': [masterInstructorCert],
            },
            [],
          ),
          child: InstructorPickerField(
            instructorId: null,
            onSelected: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      expect(
        find.text('Carol Master (SSI Master Instructor #99999)'),
        findsOneWidget,
      );
      expect(find.text('Bob Plain'), findsOneWidget);

      // Master-instructor buddy is grouped first, ahead of the plain buddy.
      final carolCenter = tester
          .getCenter(find.text('Carol Master (SSI Master Instructor #99999)'))
          .dy;
      final bobCenter = tester.getCenter(find.text('Bob Plain')).dy;
      expect(carolCenter, lessThan(bobCenter));
    });

    testWidgets(
      'selecting an instructor-level buddy fires onSelected(buddy, cert)',
      (tester) async {
        Buddy? selectedBuddy;
        Certification? selectedCert;

        await tester.pumpWidget(
          testApp(
            overrides: overridesFor(
              [plainBuddy, credentialedBuddy],
              {
                'buddy-1': [instructorCert],
              },
              [],
            ),
            child: InstructorPickerField(
              instructorId: null,
              onSelected: (buddy, cert) {
                selectedBuddy = buddy;
                selectedCert = cert;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Alice Instructor (PADI Instructor #12345)').last,
        );
        await tester.pumpAndSettle();

        expect(selectedBuddy?.id, 'buddy-1');
        expect(selectedCert, instructorCert);
        expect(selectedCert?.cardNumber, '12345');
      },
    );

    testWidgets(
      'selecting a non-instructor buddy fires onSelected(buddy, null)',
      (tester) async {
        Buddy? selectedBuddy;
        Certification? selectedCert;
        bool wasCalled = false;

        await tester.pumpWidget(
          testApp(
            overrides: overridesFor(
              [plainBuddy, credentialedBuddy],
              {
                'buddy-1': [instructorCert],
              },
              [],
            ),
            child: InstructorPickerField(
              instructorId: null,
              onSelected: (buddy, cert) {
                wasCalled = true;
                selectedBuddy = buddy;
                selectedCert = cert;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bob Plain').last);
        await tester.pumpAndSettle();

        expect(wasCalled, isTrue);
        expect(selectedBuddy?.id, 'buddy-2');
        expect(selectedCert, isNull);
      },
    );

    testWidgets('selecting None fires onSelected(null, null)', (tester) async {
      Buddy? selectedBuddy = credentialedBuddy;
      Certification? selectedCert = instructorCert;
      bool wasCalled = false;

      await tester.pumpWidget(
        testApp(
          overrides: overridesFor(
            [plainBuddy, credentialedBuddy],
            {
              'buddy-1': [instructorCert],
            },
            [],
          ),
          child: InstructorPickerField(
            instructorId: 'buddy-1',
            onSelected: (buddy, cert) {
              wasCalled = true;
              selectedBuddy = buddy;
              selectedCert = cert;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None (manual entry)').last);
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
      expect(selectedBuddy, isNull);
      expect(selectedCert, isNull);
    });

    testWidgets(
      'divemaster-only buddy is NOT grouped first (instructor-level only)',
      (tester) async {
        final divemasterBuddy = _makeBuddy('buddy-4', 'Dana Divemaster');
        final divemasterCert = _makeCertification(
          id: 'cert-3',
          buddyId: 'buddy-4',
          agency: CertificationAgency.padi,
          level: CertificationLevel.diveMaster,
          cardNumber: '55555',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overridesFor(
              // Divemaster-only buddy comes first in the source list; if it
              // were wrongly treated as instructor-level it would stay
              // first in the grouped-first ordering below.
              [divemasterBuddy, credentialedBuddy],
              {
                'buddy-4': [divemasterCert],
                'buddy-1': [instructorCert],
              },
              [],
            ),
            child: InstructorPickerField(
              instructorId: null,
              onSelected: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();

        // Divemaster-only buddy is not annotated -- it does not qualify.
        expect(find.text('Dana Divemaster'), findsOneWidget);
        expect(
          find.text('Alice Instructor (PADI Instructor #12345)'),
          findsOneWidget,
        );

        // The genuinely instructor-level buddy is grouped ahead of the
        // divemaster-only buddy, even though it appeared later in the
        // source list.
        final aliceCenter = tester
            .getCenter(find.text('Alice Instructor (PADI Instructor #12345)'))
            .dy;
        final danaCenter = tester.getCenter(find.text('Dana Divemaster')).dy;
        expect(aliceCenter, lessThan(danaCenter));
      },
    );
  });
}
