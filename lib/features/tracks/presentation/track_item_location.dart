import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';

/// The detail page a list item opens.
String trackLocationOf(TrackListItem item) => switch (item) {
  GpsTrackItem() => gpsTrackLocation(item.id),
  UnderwaterTrackItem() => underwaterTrackLocation(item.id),
};

/// Opens [item]'s detail page, keeping its row marked on the Tracks list once
/// the diver returns (issue #4024), mirroring the dive list's
/// `highlightedDiveIdProvider`.
void openTrack(BuildContext context, WidgetRef ref, TrackListItem item) {
  ref.read(highlightedTrackKeyProvider.notifier).state = item.selectionKey;
  context.push(trackLocationOf(item));
}

/// Stops marking a deleted [item] as last opened: there is nothing left to
/// come back to.
void forgetOpenedTrack(WidgetRef ref, TrackListItem item) {
  if (ref.read(highlightedTrackKeyProvider) == item.selectionKey) {
    ref.read(highlightedTrackKeyProvider.notifier).state = null;
  }
}
