import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';

import '../../../../helpers/test_app.dart';

final _now = DateTime(2024, 1, 1);

final _credentialedBuddy = Buddy(
  id: 'buddy-1',
  name: 'Alice Instructor',
  createdAt: _now,
  updatedAt: _now,
);
final _plainBuddy = Buddy(
  id: 'buddy-2',
  name: 'Bob Plain',
  createdAt: _now,
  updatedAt: _now,
);

final _instructorCredential = BuddyRoleCredential(
  id: 'cred-1',
  buddyId: 'buddy-1',
  role: BuddyRole.instructor,
  credentialNumber: '12345',
  agency: CertificationAgency.padi,
  createdAt: _now,
  updatedAt: _now,
);

/// Sets a tall screen so that bottom sheets and role selectors fit without
/// overflow.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

void main() {
  group('BuddyPicker - credential surfacing', () {
    testWidgets('shows credential label as part of the tile subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            allBuddiesProvider.overrideWith(
              (ref) async => [_credentialedBuddy, _plainBuddy],
            ),
            allBuddyRolesProvider.overrideWith(
              (ref) async => {
                'buddy-1': [_instructorCredential],
              },
            ),
          ],
          child: BuddyPicker(selectedBuddies: const [], onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(
        find.textContaining(_instructorCredential.displayLabel),
        findsOneWidget,
      );
    });

    testWidgets(
      'role sheet lists Instructor first with a credential icon for a '
      'credentialed buddy',
      (tester) async {
        _useTallScreen(tester);
        await tester.pumpWidget(
          testApp(
            overrides: [
              allBuddiesProvider.overrideWith(
                (ref) async => [_credentialedBuddy, _plainBuddy],
              ),
              allBuddyRolesProvider.overrideWith(
                (ref) async => {
                  'buddy-1': [_instructorCredential],
                },
              ),
            ],
            child: BuddyPicker(selectedBuddies: const [], onChanged: (_) {}),
          ),
        );
        await tester.pumpAndSettle();
        await _openSheet(tester);

        await tester.tap(find.text('Alice Instructor'));
        await tester.pumpAndSettle();

        // Instructor appears above Buddy in the role sheet for a
        // credentialed buddy.
        final instructorCenter = tester.getCenter(find.text('Instructor')).dy;
        final buddyCenter = tester.getCenter(find.text('Buddy')).dy;
        expect(instructorCenter, lessThan(buddyCenter));

        // Instructor row uses the credential icon rather than the default
        // person icon.
        final instructorTile = find.ancestor(
          of: find.text('Instructor'),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(
            of: instructorTile,
            matching: find.byIcon(Icons.workspace_premium),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('role sheet keeps default order for a buddy with no '
        'credentials', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        testApp(
          overrides: [
            allBuddiesProvider.overrideWith(
              (ref) async => [_credentialedBuddy, _plainBuddy],
            ),
            allBuddyRolesProvider.overrideWith(
              (ref) async => {
                'buddy-1': [_instructorCredential],
              },
            ),
          ],
          child: BuddyPicker(selectedBuddies: const [], onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await tester.tap(find.text('Bob Plain'));
      await tester.pumpAndSettle();

      // Default order: Buddy is first, ahead of Instructor.
      final buddyCenter = tester.getCenter(find.text('Buddy')).dy;
      final instructorCenter = tester.getCenter(find.text('Instructor')).dy;
      expect(buddyCenter, lessThan(instructorCenter));

      // Buddy row (no credential) uses the default person icon.
      final buddyTile = find.ancestor(
        of: find.text('Buddy'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: buddyTile, matching: find.byIcon(Icons.person)),
        findsOneWidget,
      );
    });
  });
}
