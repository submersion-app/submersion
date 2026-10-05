import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';

void main() {
  const dm = DiveRole.diveMasterId;
  const guide = DiveRole.diveGuideId;
  const buddy = DiveRole.buddyId;
  const solo = DiveRole.soloId;
  const instructor = DiveRole.instructorId;

  group('normalize', () {
    test('orders built-ins by seed order, then custom ids ascending', () {
      expect(DiveRoleSet.normalize(['zz-custom', dm, 'aa-custom', guide]), [
        guide,
        dm,
        'aa-custom',
        'zz-custom',
      ]);
    });

    test('dedupes and drops blank ids', () {
      expect(DiveRoleSet.normalize([dm, '', dm]), [dm]);
    });

    test('drops Solo when it sits beside another role', () {
      expect(DiveRoleSet.normalize([solo, instructor]), [instructor]);
      expect(DiveRoleSet.normalize([solo]), [solo]);
    });

    test('a buddy set is never empty', () {
      expect(DiveRoleSet.normalizeBuddy(const []), [buddy]);
      expect(DiveRoleSet.normalizeBuddy([dm]), [dm]);
    });
  });

  test('generic Buddy ranks after every other role', () {
    // Buddy is the default, so a set that also names a specific role keeps
    // that role as the primary older app versions display.
    expect(DiveRoleSet.normalize([buddy, instructor]), [instructor, buddy]);
    expect(DiveRoleSet.normalize([buddy, 'zz-custom']), ['zz-custom', buddy]);
    expect(DiveRoleSet.primary([buddy, dm]), dm);
  });

  test('primary is the first normalized id', () {
    expect(DiveRoleSet.primary([dm, guide]), guide);
    expect(DiveRoleSet.primary(const []), isNull);
  });

  group('resolve', () {
    test('no scalar means no roles, whatever the junction holds', () {
      expect(DiveRoleSet.resolve(scalar: null, junction: [dm]), isEmpty);
    });

    test('an empty junction falls back to the scalar', () {
      expect(DiveRoleSet.resolve(scalar: dm, junction: const []), [dm]);
    });

    test('a junction whose primary is the scalar is the set', () {
      expect(DiveRoleSet.resolve(scalar: guide, junction: [dm, guide]), [
        guide,
        dm,
      ]);
    });

    test("an older peer's scalar change wins over a stale junction", () {
      expect(DiveRoleSet.resolve(scalar: instructor, junction: [dm, guide]), [
        instructor,
      ]);
      // A member that is not the primary also marks the junction stale.
      expect(DiveRoleSet.resolve(scalar: dm, junction: [dm, guide]), [dm]);
    });

    test('a buddy always resolves to at least Buddy', () {
      expect(DiveRoleSet.resolveBuddy(scalar: null, junction: const []), [
        buddy,
      ]);
    });
  });

  test('union merges and Solo-normalizes', () {
    expect(
      DiveRoleSet.union([
        [solo],
        [dm],
      ]),
      [dm],
    );
    expect(
      DiveRoleSet.union([
        [guide],
        [dm, guide],
      ]),
      [guide, dm],
    );
  });

  test('accumulate drops Buddy when another role is present', () {
    expect(DiveRoleSet.accumulate([buddy, dm]), [dm]);
    expect(DiveRoleSet.accumulate([buddy]), [buddy]);
    expect(DiveRoleSet.accumulate(const []), [buddy]);
  });

  group('toggle', () {
    test('adds and removes an ordinary role', () {
      expect(DiveRoleSet.toggle([dm], guide), [guide, dm]);
      expect(DiveRoleSet.toggle([guide, dm], guide), [dm]);
    });

    test('ticking Solo clears everything else', () {
      expect(DiveRoleSet.toggle([dm, guide], solo), [solo]);
    });

    test('ticking another role clears Solo', () {
      expect(DiveRoleSet.toggle([solo], dm), [dm]);
    });
  });
}
