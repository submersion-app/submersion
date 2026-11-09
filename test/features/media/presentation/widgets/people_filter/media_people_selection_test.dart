import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/people_filter/media_people_selection.dart';

/// The people facet of the library filter as one draft value (issues #1745,
/// #4148). "No one tagged" excludes everyone else: together with a person it
/// could only match nothing.
void main() {
  const me = MediaPeopleSelection(includeMe: true);
  const alex = MediaPeopleSelection(buddyIds: {'alex'});

  test('starts empty', () {
    expect(MediaPeopleSelection.none.isEmpty, isTrue);
    expect(me.isEmpty, isFalse);
    expect(alex.isEmpty, isFalse);
    expect(const MediaPeopleSelection(noPeople: true).isEmpty, isFalse);
  });

  test('picking "No one tagged" clears Me and the buddies', () {
    final picked = me.copyWith(buddyIds: {'alex'}).withNoPeople(true);
    expect(picked, const MediaPeopleSelection(noPeople: true));
  });

  test('unpicking "No one tagged" leaves nothing picked', () {
    expect(
      const MediaPeopleSelection(noPeople: true).withNoPeople(false),
      MediaPeopleSelection.none,
    );
  });

  test('picking Me clears "No one tagged" and keeps the buddies', () {
    final picked = const MediaPeopleSelection(noPeople: true).withMe(true);
    expect(picked, me);
    expect(alex.withMe(true), me.copyWith(buddyIds: {'alex'}));
    expect(me.withMe(false), MediaPeopleSelection.none);
  });

  test('picking a buddy clears "No one tagged" and keeps the rest', () {
    expect(
      const MediaPeopleSelection(noPeople: true).withBuddy('alex', true),
      alex,
    );
    expect(
      me.withBuddy('alex', true).withBuddy('bea', true),
      const MediaPeopleSelection(includeMe: true, buddyIds: {'alex', 'bea'}),
    );
    expect(
      const MediaPeopleSelection(
        buddyIds: {'alex', 'bea'},
      ).withBuddy('alex', false),
      const MediaPeopleSelection(buddyIds: {'bea'}),
    );
  });

  test('equality compares the buddy sets by content', () {
    expect(
      const MediaPeopleSelection(buddyIds: {'a', 'b'}),
      const MediaPeopleSelection(buddyIds: {'b', 'a'}),
    );
    expect(
      const MediaPeopleSelection(buddyIds: {'a', 'b'}).hashCode,
      const MediaPeopleSelection(buddyIds: {'b', 'a'}).hashCode,
    );
  });
}
