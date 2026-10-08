import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_participant_names.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// The legacy scalar fallback is normalized like the junction names: trimmed,
/// and blank treated as nobody. The dive detail page reads the scalar the same
/// way (#1831), so a whitespace-only buddy is not exported as meaningful text.
void main() {
  Dive legacy({String? buddy, String? diveMaster}) => Dive(
    id: 'd',
    dateTime: DateTime(2020, 5, 1),
    buddy: buddy,
    diveMaster: diveMaster,
  );

  test('the scalar fallback is trimmed', () {
    final dive = legacy(buddy: '  Oldbuddy ', diveMaster: '\tOlddm  ');

    expect(dive.resolvedBuddyNames, 'Oldbuddy');
    expect(dive.resolvedDiveMasterNames, 'Olddm');
  });

  test('a blank scalar fallback is nobody', () {
    final dive = legacy(buddy: '   ', diveMaster: '');

    expect(dive.resolvedBuddyNames, isNull);
    expect(dive.resolvedDiveMasterNames, isNull);
  });

  test('anyone with a guide role is a dive master, never a buddy too '
      '(#1221)', () {
    final epoch = DateTime(2026);
    BuddyWithRole person(String name, List<String> roleIds) => BuddyWithRole(
      buddy: Buddy(id: name, name: name, createdAt: epoch, updatedAt: epoch),
      roles: [for (final id in roleIds) DiveRole.synthetic(id)],
    );
    final dive = Dive(
      id: 'd',
      dateTime: DateTime(2026),
      buddies: [
        person('Ana', [DiveRole.buddyId, DiveRole.diveGuideId]),
        person('Ben', [DiveRole.buddyId]),
      ],
    );
    expect(dive.resolvedDiveMasterNames, 'Ana');
    expect(dive.resolvedBuddyNames, 'Ben');
  });
}
