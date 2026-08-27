import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';

void main() {
  test('ensureOn on a "some" item adds it (to the dives missing it)', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.some},
      {'a': MembershipChoice.ensureOn},
    );
    expect(d.addIds, ['a']);
    expect(d.removeIds, isEmpty);
  });

  test('ensureOn on an "all" item is a no-op', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.all},
      {'a': MembershipChoice.ensureOn},
    );
    expect(d.addIds, isEmpty);
    expect(d.removeIds, isEmpty);
  });

  test('ensureOn on a "none" item (just added) adds it', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.none},
      {'a': MembershipChoice.ensureOn},
    );
    expect(d.addIds, ['a']);
    expect(d.removeIds, isEmpty);
  });

  test('ensureOff on "all" or "some" removes; on "none" is a no-op', () {
    final d = MembershipDelta.from(
      {
        'a': MembershipPresence.all,
        'b': MembershipPresence.some,
        'c': MembershipPresence.none,
      },
      {
        'a': MembershipChoice.ensureOff,
        'b': MembershipChoice.ensureOff,
        'c': MembershipChoice.ensureOff,
      },
    );
    expect(d.removeIds.toSet(), {'a', 'b'});
    expect(d.addIds, isEmpty);
  });

  test('leaveAsIs never changes anything', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.some},
      {'a': MembershipChoice.leaveAsIs},
    );
    expect(d.addIds, isEmpty);
    expect(d.removeIds, isEmpty);
    expect(d.isEmpty, isTrue);
  });
}
