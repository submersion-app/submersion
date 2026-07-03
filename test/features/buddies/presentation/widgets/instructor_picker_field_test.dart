import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/instructor_picker_field.dart';

import '../../../../helpers/test_app.dart';

Buddy _makeBuddy(String id, String name) {
  final now = DateTime(2024, 1, 1);
  return Buddy(id: id, name: name, createdAt: now, updatedAt: now);
}

BuddyRoleCredential _makeCredential({
  required String buddyId,
  BuddyRole role = BuddyRole.instructor,
  String? credentialNumber,
  CertificationAgency? agency,
}) {
  final now = DateTime(2024, 1, 1);
  return BuddyRoleCredential(
    id: '$buddyId-${role.name}',
    buddyId: buddyId,
    role: role,
    credentialNumber: credentialNumber,
    agency: agency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('InstructorPickerField', () {
    final credentialedBuddy = _makeBuddy('buddy-1', 'Alice Instructor');
    final plainBuddy = _makeBuddy('buddy-2', 'Bob Plain');
    final credential = _makeCredential(
      buddyId: 'buddy-1',
      credentialNumber: '12345',
      agency: CertificationAgency.padi,
    );

    List<dynamic> overridesFor(List<Buddy> buddies, List<dynamic> extra) => [
      allBuddiesProvider.overrideWith((ref) async => buddies),
      allBuddyRolesProvider.overrideWith(
        (ref) async => {
          'buddy-1': [credential],
        },
      ),
      ...extra,
    ];

    testWidgets(
      'lists credentialed buddies first and shows the credential label',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: overridesFor([plainBuddy, credentialedBuddy], []),
            child: InstructorPickerField(
              instructorId: null,
              onSelected: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();

        // Credentialed buddy is annotated with its credential label.
        expect(
          find.text('Alice Instructor (${credential.displayLabel})'),
          findsOneWidget,
        );
        expect(find.text('Bob Plain'), findsOneWidget);

        // Credentialed buddy appears before the plain buddy in menu order.
        final aliceCenter = tester
            .getCenter(
              find.text('Alice Instructor (${credential.displayLabel})'),
            )
            .dy;
        final bobCenter = tester.getCenter(find.text('Bob Plain')).dy;
        expect(aliceCenter, lessThan(bobCenter));
      },
    );

    testWidgets(
      'selecting a credentialed buddy fires onSelected with buddy and credential',
      (tester) async {
        Buddy? selectedBuddy;
        BuddyRoleCredential? selectedCredential;

        await tester.pumpWidget(
          testApp(
            overrides: overridesFor([plainBuddy, credentialedBuddy], []),
            child: InstructorPickerField(
              instructorId: null,
              onSelected: (buddy, cred) {
                selectedBuddy = buddy;
                selectedCredential = cred;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Alice Instructor (${credential.displayLabel})').last,
        );
        await tester.pumpAndSettle();

        expect(selectedBuddy?.id, 'buddy-1');
        expect(selectedCredential, credential);
      },
    );

    testWidgets(
      'selecting a non-credentialed buddy fires onSelected(buddy, null)',
      (tester) async {
        Buddy? selectedBuddy;
        BuddyRoleCredential? selectedCredential;
        bool wasCalled = false;

        await tester.pumpWidget(
          testApp(
            overrides: overridesFor([plainBuddy, credentialedBuddy], []),
            child: InstructorPickerField(
              instructorId: null,
              onSelected: (buddy, cred) {
                wasCalled = true;
                selectedBuddy = buddy;
                selectedCredential = cred;
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
        expect(selectedCredential, isNull);
      },
    );

    testWidgets('selecting None fires onSelected(null, null)', (tester) async {
      Buddy? selectedBuddy = credentialedBuddy;
      BuddyRoleCredential? selectedCredential = credential;
      bool wasCalled = false;

      await tester.pumpWidget(
        testApp(
          overrides: overridesFor([plainBuddy, credentialedBuddy], []),
          child: InstructorPickerField(
            instructorId: 'buddy-1',
            onSelected: (buddy, cred) {
              wasCalled = true;
              selectedBuddy = buddy;
              selectedCredential = cred;
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
      expect(selectedCredential, isNull);
    });
  });
}
