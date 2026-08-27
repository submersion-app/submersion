import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _kFocusZoom = 16.0;
const double _kMapHeight = 180.0;

/// The dive detail "Surface GPS" section: an interactive map of the entry/exit
/// GPS fixes and the associated dive site, plus copyable coordinate rows.
class SurfaceGpsSection extends ConsumerStatefulWidget {
  const SurfaceGpsSection({
    super.key,
    required this.dive,
    this.sourceName,
    @visibleForTesting this.controller,
  });

  final Dive dive;
  final String? sourceName;

  /// Test-only injection point for the inline map's controller.
  final MapController? controller;

  @override
  ConsumerState<SurfaceGpsSection> createState() => _SurfaceGpsSectionState();
}

class _SurfaceGpsSectionState extends ConsumerState<SurfaceGpsSection> {
  late final MapController _controller = widget.controller ?? MapController();

  void _focusOn(GeoPoint p) {
    _controller.move(LatLng(p.latitude, p.longitude), _kFocusZoom);
  }

  Future<void> _copy(BuildContext context, GeoPoint p) async {
    await Clipboard.setData(ClipboardData(text: p.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.diveLog_detail_coordinatesCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DiveLocationsMapPage(
          title: context.l10n.diveLog_detail_locationsMap_title,
          entry: widget.dive.entryLocation,
          exit: widget.dive.exitLocation,
          site: widget.dive.site?.location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final entry = dive.entryLocation;
    final exit = dive.exitLocation;
    final site = dive.site?.location;
    final isExpanded = ref.watch(surfaceGpsSectionExpandedProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    String? driftText;
    if (entry != null && exit != null) {
      final dist = distanceMeters(entry, exit);
      final bearing = initialBearingDegrees(entry, exit);
      driftText = '${units.formatDistance(dist)} · ${formatBearing(bearing)}';
    }

    final collapsedSubtitle = driftText != null
        ? '${context.l10n.diveLog_detail_label_drift}: $driftText'
        : (entry != null
              ? context.l10n.diveLog_detail_surfaceGps_entryOnly
              : context.l10n.diveLog_detail_surfaceGps_exitOnly);

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_surfaceGps,
      icon: Icons.my_location,
      collapsedSubtitle: collapsedSubtitle,
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref
            .read(collapsibleSectionProvider.notifier)
            .setSurfaceGpsExpanded(expanded);
      },
      // Build the (heavy) map content only when expanded so the page never
      // holds a second offscreen FlutterMap.
      contentBuilder: (context) => isExpanded
          ? _content(context, units, entry, exit, site, driftText)
          : const SizedBox.shrink(),
    );
  }

  /// Points of the covering track, windowed to the dive unless the user has
  /// asked for the whole recording.
  ///
  /// Resolved here rather than in [build] so a collapsed section performs no
  /// blob decode - watching the track provider one level up would defeat the
  /// laziness the contentBuilder gate exists for.
  List<TrackRun> _trackRuns(GpsTrack track) {
    if (ref.watch(surfaceGpsFullTrackProvider)) {
      return bucketizeTrack(track.effectivePoints, TrackColorMode.uniform);
    }
    // Wall-clock-as-UTC seconds, matching the point timestamps.
    const marginSeconds = 15 * 60;
    final dive = widget.dive;
    final entrySec = dive.effectiveEntryTime.millisecondsSinceEpoch ~/ 1000;
    // effectiveRuntime, not bottomTime: runtime is surface-to-surface, which
    // is the window the boat was out. bottomTime excludes descent and ascent,
    // so on a deco dive it can fall short by twenty minutes or more, and it is
    // null on plenty of imported dives - which collapsed the window to the
    // entry instant plus the margin.
    final exitSec = entrySec + (dive.effectiveRuntime?.inSeconds ?? 0);
    return bucketizeTrack(
      windowTrack(
        track.effectivePoints,
        fromEpochSeconds: entrySec - marginSeconds,
        toEpochSeconds: exitSec + marginSeconds,
      ),
      TrackColorMode.uniform,
    );
  }

  Widget _content(
    BuildContext context,
    UnitFormatter units,
    GeoPoint? entry,
    GeoPoint? exit,
    GeoPoint? site,
    String? driftText,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final track = ref.watch(trackForDiveProvider(widget.dive.id)).value;
    final runs = track == null ? null : _trackRuns(track);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: _kMapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DiveLocationsMap(
                      entry: entry,
                      exit: exit,
                      site: site,
                      interactive: true,
                      controller: _controller,
                      trackRuns: runs,
                      fitToTrack: runs != null && runs.isNotEmpty,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: colorScheme.surface.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        key: const ValueKey('gps-expand'),
                        icon: const Icon(Icons.fullscreen),
                        tooltip: context.l10n.diveLog_detail_locationsMap_title,
                        onPressed: () => _openFullscreen(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (entry != null)
            _GpsCoordinateRow(
              dotColor: kGpsEntryColor,
              label: context.l10n.diveLog_detail_surfaceGps_entry,
              point: entry,
              units: units,
              coordKey: const ValueKey('gps-coord-entry'),
              copyKey: const ValueKey('gps-copy-entry'),
              sourceName: widget.sourceName,
              onFocus: () => _focusOn(entry),
              onCopy: () => _copy(context, entry),
            ),
          if (exit != null)
            _GpsCoordinateRow(
              dotColor: kGpsExitColor,
              label: context.l10n.diveLog_detail_surfaceGps_exit,
              point: exit,
              units: units,
              coordKey: const ValueKey('gps-coord-exit'),
              copyKey: const ValueKey('gps-copy-exit'),
              sourceName: widget.sourceName,
              onFocus: () => _focusOn(exit),
              onCopy: () => _copy(context, exit),
            ),
          if (site != null)
            _GpsCoordinateRow(
              dotColor: colorScheme.primary,
              label: context.l10n.diveLog_detail_surfaceGps_site,
              point: site,
              units: units,
              coordKey: const ValueKey('gps-coord-site'),
              copyKey: const ValueKey('gps-copy-site'),
              onFocus: () => _focusOn(site),
              onCopy: () => _copy(context, site),
            ),
          if (driftText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_calls,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${context.l10n.diveLog_detail_label_drift}: $driftText',
                  ),
                ],
              ),
            ),
          if (track != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  // "Surface track", never "your route": during the dive the
                  // recording phone is on the boat, so this is the surface
                  // support path, not the diver's.
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('gps-track-link'),
                      onTap: () => context.push('/gps-log/${track.id}'),
                      child: Text(
                        '${l10n.diveLog_detail_surfaceGps_track}: '
                        // This provider hydrates points, so the trimmed count
                        // is always knowable here; the fallback is only for
                        // the impossible unhydrated case.
                        '${l10n.diveLog_detail_surfaceGps_trackFixes(track.effectivePointCount ?? track.pointCount)}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    key: const ValueKey('gps-track-full-chip'),
                    label: Text(l10n.diveLog_detail_surfaceGps_showFullTrack),
                    selected: ref.watch(surfaceGpsFullTrackProvider),
                    onSelected: (value) =>
                        ref.read(surfaceGpsFullTrackProvider.notifier).state =
                            value,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One coordinate row: colored dot, label, tappable (focus) coordinate link,
/// and a copy button.
class _GpsCoordinateRow extends StatelessWidget {
  const _GpsCoordinateRow({
    required this.dotColor,
    required this.label,
    required this.point,
    required this.units,
    required this.coordKey,
    required this.copyKey,
    required this.onFocus,
    required this.onCopy,
    this.sourceName,
  });

  final Color dotColor;
  final String label;
  final GeoPoint point;
  final UnitFormatter units;
  final Key coordKey;
  final Key copyKey;
  final VoidCallback onFocus;
  final VoidCallback onCopy;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final coordText = units.formatCoordinates(point.latitude, point.longitude);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: coordKey,
              onTap: onFocus,
              child: Text(
                coordText,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          if (sourceName != null) ...[
            FieldAttributionBadge(sourceName: sourceName),
            const SizedBox(width: 4),
          ],
          IconButton(
            key: copyKey,
            icon: const Icon(Icons.copy, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
