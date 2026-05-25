import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Fullscreen, fully-interactive map of a dive's surface locations.
class DiveLocationsMapPage extends StatelessWidget {
  const DiveLocationsMapPage({
    super.key,
    required this.title,
    this.entry,
    this.exit,
    this.site,
  });

  final String title;
  final GeoPoint? entry;
  final GeoPoint? exit;
  final GeoPoint? site;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DiveLocationsMap(
        entry: entry,
        exit: exit,
        site: site,
        interactive: true,
      ),
    );
  }
}
