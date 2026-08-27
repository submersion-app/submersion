import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart'
    show BuddyWithDiveCount;
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';

import '../../../../helpers/test_app.dart';

final _now = DateTime(2024, 1, 1);

final _testRoles = [
  for (final (i, id) in DiveRole.builtInIds.indexed)
    DiveRole(
      id: id,
      name: id,
      isBuiltIn: true,
      sortOrder: i,
      createdAt: _now,
      updatedAt: _now,
    ),
];

/// Buddy with a pre-hydrated instructor cert level -- in production this
/// comes from `_withPrimaryCerts`, but this widget test overrides
/// `allBuddiesWithDiveCountProvider` directly, bypassing the repository, so
/// the fixture must carry the derived field itself.
final _instructorBuddy = Buddy(
  id: 'buddy-1',
  name: 'Alice Instructor',
  certificationLevel: CertificationLevel.instructor,
  createdAt: _now,
  updatedAt: _now,
);
final _plainBuddy = Buddy(
  id: 'buddy-2',
  name: 'Bob Plain',
  createdAt: _now,
  updatedAt: _now,
);

/// Buddy without a pre-hydrated cert level, used for the role-sheet ordering
/// tests so the background buddy-list subtitle doesn't also read
/// "Instructor" and collide with the role text inside the sheet.
final _credentialedBuddy = Buddy(
  id: 'buddy-1',
  name: 'Alice Instructor',
  createdAt: _now,
  updatedAt: _now,
);

final _instructorCert = Certification(
  id: 'cert-1',
  buddyId: 'buddy-1',
  name: 'Instructor Certification',
  agency: CertificationAgency.padi,
  level: CertificationLevel.instructor,
  cardNumber: '12345',
  createdAt: _now,
  updatedAt: _now,
);

List<BuddyWithDiveCount> _withCount(Iterable<Buddy> buddies) => [
  for (final b in buddies) BuddyWithDiveCount(buddy: b, diveCount: 0),
];

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
  group('BuddyPicker - certification-driven role hints', () {
    testWidgets('subtitle shows the primary cert level only', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            allDiveRolesProvider.overrideWith((ref) async => _testRoles),
            allBuddiesWithDiveCountProvider.overrideWith(
              (ref) async => _withCount([_instructorBuddy, _plainBuddy]),
            ),
            allBuddyCertificationsProvider.overrideWith(
              (ref) async => {
                'buddy-1': [_instructorCert],
              },
            ),
          ],
          child: BuddyPicker(selectedBuddies: const [], onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // The subtitle comes from buddy.certificationLevel (already
      // cert-derived), shown exactly once with no " | " doubled label.
      expect(find.text('Instructor'), findsOneWidget);
      expect(find.textContaining(' | '), findsNothing);
    });

    testWidgets(
      'role sheet lists Instructor first with a credential icon for a '
      'buddy holding an instructor cert',
      (tester) async {
        _useTallScreen(tester);
        await tester.pumpWidget(
          testApp(
            overrides: [
              allDiveRolesProvider.overrideWith((ref) async => _testRoles),
              allBuddiesWithDiveCountProvider.overrideWith(
                (ref) async => _withCount([_credentialedBuddy, _plainBuddy]),
              ),
              allBuddyCertificationsProvider.overrideWith(
                (ref) async => {
                  'buddy-1': [_instructorCert],
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

        // Instructor appears above Buddy in the role sheet for a buddy
        // holding an instructor cert.
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
        'professional certs', (tester) async {
      _useTallScreen(tester);
      await tester.pumpWidget(
        testApp(
          overrides: [
            allDiveRolesProvider.overrideWith((ref) async => _testRoles),
            allBuddiesWithDiveCountProvider.overrideWith(
              (ref) async => _withCount([_credentialedBuddy, _plainBuddy]),
            ),
            allBuddyCertificationsProvider.overrideWith(
              (ref) async => {
                'buddy-1': [_instructorCert],
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

      // Buddy row (no professional cert) uses the default person icon.
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
