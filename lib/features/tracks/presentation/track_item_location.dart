import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// The detail page a list item opens.
String trackLocationOf(TrackListItem item) => switch (item) {
  GpsTrackItem() => gpsTrackLocation(item.id),
  UnderwaterTrackItem() => underwaterTrackLocation(item.id),
};
