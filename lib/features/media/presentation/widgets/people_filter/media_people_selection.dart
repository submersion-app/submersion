import 'package:flutter/foundation.dart';

/// The people facet of the library filter as one draft value: "No one
/// tagged" (issue #4148), Me, and buddies (issue #1745), any-of.
///
/// "No one tagged" excludes everyone else, since together with a person it
/// could only match nothing: picking it clears the people, and picking a
/// person clears it. The toggles below are the one place that rule lives,
/// shared by the filter sheet and its People picker.
@immutable
class MediaPeopleSelection {
  final bool noPeople;
  final bool includeMe;
  final Set<String> buddyIds;

  const MediaPeopleSelection({
    this.noPeople = false,
    this.includeMe = false,
    this.buddyIds = const {},
  });

  static const none = MediaPeopleSelection();

  bool get isEmpty => !noPeople && !includeMe && buddyIds.isEmpty;

  MediaPeopleSelection copyWith({
    bool? noPeople,
    bool? includeMe,
    Set<String>? buddyIds,
  }) => MediaPeopleSelection(
    noPeople: noPeople ?? this.noPeople,
    includeMe: includeMe ?? this.includeMe,
    buddyIds: buddyIds ?? this.buddyIds,
  );

  MediaPeopleSelection withNoPeople(bool picked) =>
      picked ? const MediaPeopleSelection(noPeople: true) : none;

  MediaPeopleSelection withMe(bool picked) => MediaPeopleSelection(
    includeMe: picked,
    buddyIds: buddyIds,
    noPeople: !picked && noPeople,
  );

  MediaPeopleSelection withBuddy(String id, bool picked) =>
      MediaPeopleSelection(
        includeMe: includeMe,
        buddyIds: picked
            ? {...buddyIds, id}
            : {
                for (final b in buddyIds)
                  if (b != id) b,
              },
        noPeople: !picked && noPeople,
      );

  @override
  bool operator ==(Object other) =>
      other is MediaPeopleSelection &&
      other.noPeople == noPeople &&
      other.includeMe == includeMe &&
      setEquals(other.buddyIds, buddyIds);

  @override
  int get hashCode =>
      Object.hash(noPeople, includeMe, Object.hashAllUnordered(buddyIds));

  @override
  String toString() =>
      'MediaPeopleSelection(noPeople: $noPeople, includeMe: $includeMe, '
      'buddyIds: $buddyIds)';
}
