import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_battery_reading.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The device that recorded the track (the navigation console, e.g. a
/// Seacraft ENC) with its battery over the track (#4100).
///
/// Kept apart from the route figures and from the equipment card: the
/// voltage is the console's own cell, not the route's and not the
/// scooter's. A source that logs no battery shows its name alone.
class NavTrackRecorderCard extends StatelessWidget {
  const NavTrackRecorderCard({super.key, required this.route});

  final NavTrack route;

  @override
  Widget build(BuildContext context) {
    final battery = NavTrackBatteryReading.of(route.points);
    return Card(
      key: const ValueKey('nav-track-recorder-card'),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.explore_outlined),
        title: Text(route.source.label),
        subtitle: battery == null
            ? null
            : Text(
                context.l10n.navTrack_detail_battery(
                  formatFixedForDisplay(battery.start, 2),
                  formatFixedForDisplay(battery.end, 2),
                  formatSignedVolts(battery.change),
                ),
              ),
      ),
    );
  }
}

/// [volts] with two decimals and a sign, "+0.05" or "-0.12". The sign
/// follows the rounded figure, so a change too small to show reads "0.00"
/// rather than "+0.00" or "-0.00".
@visibleForTesting
String formatSignedVolts(double volts) {
  final magnitude = volts.abs().toStringAsFixed(2);
  final sign = double.parse(magnitude) == 0 ? '' : (volts > 0 ? '+' : '-');
  return '$sign${localiseDecimalText(magnitude)}';
}
