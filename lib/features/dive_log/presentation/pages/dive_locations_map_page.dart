import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';

/// Fullscreen, fully-interactive map of a dive's surface locations.
class DiveLocationsMapPage extends StatelessWidget {
  const DiveLocationsMapPage({
    super.key,
    required this.title,
    this.entry,
    this.exit,
    this.site,
    this.trackRuns,
  });

  final String title;
  final GeoPoint? entry;
  final GeoPoint? exit;
  final GeoPoint? site;

  /// The GPS surface track the inline card draws, so the fullscreen copy
  /// shows the same track and frames it.
  final List<TrackRun>? trackRuns;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DiveLocationsMap(
        entry: entry,
        exit: exit,
        site: site,
        interactive: true,
        trackRuns: trackRuns,
        fitToTrack: trackRuns != null && trackRuns!.isNotEmpty,
      ),
    );
  }
}
