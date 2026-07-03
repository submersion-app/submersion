import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_roles_editor.dart';

import '../../../../helpers/test_app.dart';

BuddyRoleCredential _makeCredential({
  String id = 'role-1',
  String buddyId = 'buddy-1',
  BuddyRole role = BuddyRole.instructor,
  String? credentialNumber,
  CertificationAgency? agency,
}) {
  final now = DateTime(2024, 1, 1);
  return BuddyRoleCredential(
    id: id,
    buddyId: buddyId,
    role: role,
    credentialNumber: credentialNumber,
    agency: agency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('BuddyRolesEditor', () {
    testWidgets('renders one row per credential with role name and number', (
      tester,
    ) async {
      final roles = [
        _makeCredential(
          role: BuddyRole.instructor,
          credentialNumber: '12345',
          agency: CertificationAgency.padi,
        ),
        _makeCredential(
          id: 'role-2',
          role: BuddyRole.diveMaster,
          credentialNumber: '99999',
        ),
      ];

      await tester.pumpWidget(
        testApp(
          child: BuddyRolesEditor(roles: roles, onChanged: (_) {}),
        ),
      );

      expect(find.text(BuddyRole.instructor.displayName), findsOneWidget);
      expect(find.text(BuddyRole.diveMaster.displayName), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('99999'), findsOneWidget);
    });

    testWidgets(
      'tapping Add role invokes onChanged with a new instructor entry',
      (tester) async {
        List<BuddyRoleCredential>? result;

        await tester.pumpWidget(
          testApp(
            child: BuddyRolesEditor(
              roles: const [],
              onChanged: (roles) => result = roles,
            ),
          ),
        );

        await tester.tap(find.text('Add role'));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.length, 1);
        expect(result!.first.role, BuddyRole.instructor);
      },
    );

    testWidgets('Add role is absent when all professional roles are used', (
      tester,
    ) async {
      final roles = kProfessionalBuddyRoles
          .map((role) => _makeCredential(id: role.name, role: role))
          .toList();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: BuddyRolesEditor(roles: roles, onChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('Add role'), findsNothing);
    });

    testWidgets(
      'editing the credential-number field invokes onChanged with the updated credential',
      (tester) async {
        List<BuddyRoleCredential>? result;
        final roles = [
          _makeCredential(role: BuddyRole.instructor, credentialNumber: null),
        ];

        await tester.pumpWidget(
          testApp(
            child: BuddyRolesEditor(
              roles: roles,
              onChanged: (updated) => result = updated,
            ),
          ),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Credential number'),
          '54321',
        );
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.single.credentialNumber, '54321');
        expect(result!.single.role, BuddyRole.instructor);
      },
    );

    testWidgets(
      'tapping the remove icon invokes onChanged without that credential',
      (tester) async {
        List<BuddyRoleCredential>? result;
        final roles = [
          _makeCredential(id: 'role-1', role: BuddyRole.instructor),
          _makeCredential(id: 'role-2', role: BuddyRole.diveMaster),
        ];

        await tester.pumpWidget(
          testApp(
            child: BuddyRolesEditor(
              roles: roles,
              onChanged: (updated) => result = updated,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.length, 1);
        expect(result!.single.role, BuddyRole.diveMaster);
      },
    );

    testWidgets(
      'clearing agency and credential number delivers nulled-out credential',
      (tester) async {
        List<BuddyRoleCredential>? result;
        final roles = [
          _makeCredential(
            role: BuddyRole.instructor,
            credentialNumber: '12345',
            agency: CertificationAgency.padi,
          ),
        ];

        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: BuddyRolesEditor(
                roles: roles,
                onChanged: (updated) => result = updated,
              ),
            ),
          ),
        );

        // Select the "not specified" (null) agency item.
        await tester.tap(find.text(CertificationAgency.padi.displayName));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Not specified').last);
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.single.agency, isNull);
        expect(result!.single.credentialNumber, '12345');

        // Clear the credential-number field. The editor was pumped with the
        // original credential (agency still PADI in this instance), so only
        // the number changes relative to it.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Credential number'),
          '',
        );
        await tester.pumpAndSettle();

        expect(result!.single.credentialNumber, isNull);
        expect(result!.single.agency, CertificationAgency.padi);
        expect(result!.single.role, BuddyRole.instructor);
      },
    );
  });
}
