import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The offset the Set-time dialog opens on for [item] (issue #1090): the
/// diver's pin if there is one, else the automatic position if it is inside
/// the dive window, else the dive start.
///
/// The result is always inside `0..profileLengthSeconds`, the dialog's
/// range. The window includes the pre/post-dive buffers, so an automatic
/// position can sit at -1:30 or past the last sample; the nearest moment
/// the diver can actually pin is the start or the end, and choosing it here
/// keeps that rule at the one place both call sites share instead of in a
/// clamp inside the dialog the caller cannot see.
int setTimeSeedFor(MediaItem item, {required int profileLengthSeconds}) {
  final enrichment = item.enrichment;
  final positioned =
      enrichment?.isWithinDiveWindow(profileLengthSeconds) ?? false;
  final seed =
      item.manualElapsedSeconds ??
      (positioned ? enrichment!.elapsedSeconds! : 0);
  return seed.clamp(0, profileLengthSeconds);
}
