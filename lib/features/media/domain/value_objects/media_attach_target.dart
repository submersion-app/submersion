import 'package:equatable/equatable.dart';

/// The entity a photo-picker session attaches its media to.
///
/// The picker's Gallery tab hands its selection back to the caller, which
/// decides where the rows go. The Files and URL tabs do not: they write rows
/// themselves, so they have to be told what to link those rows to. Before
/// this type existed they were told only a `diveId`, which is why a session
/// opened from a dive site had no reachable commit path at all (issue #1098)
/// - the Files tab's button was gated on the dive matcher having produced a
/// group, and a site can never produce one.
///
/// A sealed hierarchy rather than two nullable ids: a session attaches to a
/// dive or to a site, never both, and `switch` over it is exhaustive so the
/// analyzer flags any new decision point that forgets one of the two.
///
/// A null target (no instance at all) means the session has no owning entity
/// - the library importer - where date-based dive matching is the only thing
/// that can assign one.
sealed class MediaAttachTarget extends Equatable {
  const MediaAttachTarget();

  @override
  bool get stringify => true;
}

/// Media picked in this session belongs to one dive.
final class DiveAttachTarget extends MediaAttachTarget {
  const DiveAttachTarget(this.diveId);

  final String diveId;

  @override
  List<Object?> get props => [diveId];
}

/// Media picked in this session belongs to one dive site, as a direct
/// attachment.
///
/// Dive matching is meaningless here: a site has no time window, and a photo
/// that happens to fall inside some unrelated dive's window would land on
/// that dive rather than on the site the user was looking at.
final class SiteAttachTarget extends MediaAttachTarget {
  const SiteAttachTarget(this.siteId);

  final String siteId;

  @override
  List<Object?> get props => [siteId];
}
