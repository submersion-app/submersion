import 'package:equatable/equatable.dart';

/// Which dive the profile pop-out shows (#5078): the main window's dive
/// while following, or the dive it was pinned to.
class DiveFollowState extends Equatable {
  /// The last dive the main window showed. Kept when the main window moves
  /// to a screen with no dive, so the pop-out does not go blank.
  final String? followedDiveId;

  /// The dive the diver pinned the pop-out to, or null while following.
  final String? pinnedDiveId;

  const DiveFollowState({this.followedDiveId, this.pinnedDiveId});

  String? get shownDiveId => pinnedDiveId ?? followedDiveId;
  bool get isPinned => pinnedDiveId != null;

  /// The main window now shows [id]. A null id (no dive on its screen)
  /// keeps the last one.
  DiveFollowState followed(String? id) => id == null
      ? this
      : DiveFollowState(followedDiveId: id, pinnedDiveId: pinnedDiveId);

  /// Holds the dive shown now. Nothing shown, nothing to pin.
  DiveFollowState pin() => DiveFollowState(
    followedDiveId: followedDiveId,
    pinnedDiveId: shownDiveId,
  );

  /// Goes back to following, jumping to the main window's latest dive.
  DiveFollowState unpin() => DiveFollowState(followedDiveId: followedDiveId);

  /// The dive [id] no longer exists (deleted, or gone in a sync).
  DiveFollowState diveMissing(String id) => DiveFollowState(
    followedDiveId: followedDiveId == id ? null : followedDiveId,
    pinnedDiveId: pinnedDiveId == id ? null : pinnedDiveId,
  );

  @override
  List<Object?> get props => [followedDiveId, pinnedDiveId];
}
