import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_merge_form_controller.dart';

BuddyRoleCredential _makeCredential({
  required String id,
  required String buddyId,
  required BuddyRole role,
  String? credentialNumber,
}) {
  final now = DateTime(2024, 1, 1);
  return BuddyRoleCredential(
    id: id,
    buddyId: buddyId,
    role: role,
    credentialNumber: credentialNumber,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('mergeRoleCredentials', () {
    test('returns empty list when no candidate has credentials', () {
      expect(mergeRoleCredentials([[], [], []]), isEmpty);
    });

    test('keeps all credentials from a single candidate', () {
      final roles = [
        _makeCredential(id: 'a', buddyId: 'b1', role: BuddyRole.instructor),
        _makeCredential(id: 'b', buddyId: 'b1', role: BuddyRole.diveMaster),
      ];

      expect(mergeRoleCredentials([roles]), roles);
    });

    test('survivor wins role collisions with duplicates', () {
      final survivorInstructor = _makeCredential(
        id: 'surv-instructor',
        buddyId: 'survivor',
        role: BuddyRole.instructor,
        credentialNumber: '111',
      );
      final dupInstructor = _makeCredential(
        id: 'dup-instructor',
        buddyId: 'duplicate',
        role: BuddyRole.instructor,
        credentialNumber: '999',
      );

      final merged = mergeRoleCredentials([
        [survivorInstructor],
        [dupInstructor],
      ]);

      expect(merged, [survivorInstructor]);
    });

    test(
      'unions non-colliding credentials in candidate order, survivor first',
      () {
        final survivorInstructor = _makeCredential(
          id: 'surv-instructor',
          buddyId: 'survivor',
          role: BuddyRole.instructor,
        );
        final dup1DiveMaster = _makeCredential(
          id: 'dup1-dm',
          buddyId: 'dup1',
          role: BuddyRole.diveMaster,
        );
        final dup2DiveGuide = _makeCredential(
          id: 'dup2-guide',
          buddyId: 'dup2',
          role: BuddyRole.diveGuide,
        );
        final dup2DiveMaster = _makeCredential(
          id: 'dup2-dm',
          buddyId: 'dup2',
          role: BuddyRole.diveMaster,
        );

        final merged = mergeRoleCredentials([
          [survivorInstructor],
          [dup1DiveMaster],
          [dup2DiveGuide, dup2DiveMaster],
        ]);

        // dup2's divemaster loses the collision to dup1's (earlier candidate).
        expect(merged, [survivorInstructor, dup1DiveMaster, dup2DiveGuide]);
      },
    );

    test('empty survivor adopts all duplicate credentials', () {
      final dupInstructor = _makeCredential(
        id: 'dup-instructor',
        buddyId: 'duplicate',
        role: BuddyRole.instructor,
      );

      final merged = mergeRoleCredentials([
        [],
        [dupInstructor],
      ]);

      expect(merged, [dupInstructor]);
    });
  });
}
