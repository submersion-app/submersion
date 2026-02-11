import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A compact dive profile chart overlay for the photo viewer.
///
/// Shows the depth profile with a marker indicating where the photo was taken.
/// Designed to be displayed in the corner of full-screen photo views.
class MiniDiveProfileOverlay extends StatelessWidget {
  /// The dive profile data points.
  final List<DiveProfilePoint> profile;

  /// The elapsed time in seconds when the photo was taken.
  final int photoElapsedSeconds;

  /// The depth in meters when the photo was taken (for label display).
  final double? photoDepthMeters;

  /// App settings for unit formatting.
  final AppSettings settings;

  /// Callback when the overlay is tapped (e.g., to dismiss or expand).
  final VoidCallback? onTap;

  const MiniDiveProfileOverlay({
    super.key,
    required this.profile,
    required this.photoElapsedSeconds,
    this.photoDepthMeters,
    required this.settings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: context.l10n.media_miniProfile_semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 160,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with depth label
              _buildHeader(context),
              const SizedBox(height: 4),
              // Mini chart
              Expanded(child: _buildMiniChart(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final formatter = UnitFormatter(settings);

    return Row(
      children: [
        Icon(
          Icons.show_chart,
          size: 12,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          context.l10n.media_miniProfile_headerLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (photoDepthMeters != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              formatter.formatDepth(photoDepthMeters, decimals: 0),
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniChart(BuildContext context) {
    // Calculate bounds
    final sortedProfile = List<DiveProfilePoint>.from(profile)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final maxTime = sortedProfile
        .map((p) => p.timestamp)
        .reduce(math.max)
        .toDouble();
    final maxDepth = sortedProfile.map((p) => p.depth).reduce(math.max);

    // Add padding to max depth for visual clarity
    final chartMaxDepth = maxDepth * 1.1;

    // Create depth line spots with NEGATED depths for proper orientation
    // (fl_chart Y-axis goes up, but we want depth to increase downward)
    final depthSpots = sortedProfile
        .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
        .toList();

    // Find the depth at the photo timestamp for the marker
    final photoDepth = _interpolateDepth(sortedProfile, photoElapsedSeconds);

    // Clamp photo timestamp to valid range for display
    final clampedPhotoTime = photoElapsedSeconds.toDouble().clamp(0.0, maxTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate marker position
        final chartWidth = constraints.maxWidth;
        final chartHeight = constraints.maxHeight;

        // X position: percentage of time range
        final xPercent = maxTime > 0 ? clampedPhotoTime / maxTime : 0.5;
        final markerX = chartWidth * xPercent;

        // Y position: percentage of depth range
        // Since chart goes from -chartMaxDepth (bottom) to 0 (top),
        // and photoDepth is positive, we calculate position from top
        final yPercent = chartMaxDepth > 0 ? photoDepth / chartMaxDepth : 0.5;
        final markerY = chartHeight * yPercent;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The chart
            LineChart(
              LineChartData(
                minX: 0,
                maxX: maxTime,
                minY: -chartMaxDepth, // Deepest point at bottom
                maxY: 0, // Surface at top
                clipData: const FlClipData.all(),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  // Depth line
                  LineChartBarData(
                    spots: depthSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: Colors.cyan.withValues(alpha: 0.8),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    // Fill ABOVE the line (toward surface/zero)
                    aboveBarData: BarAreaData(
                      show: true,
                      color: Colors.cyan.withValues(alpha: 0.15),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    // Photo timestamp marker line
                    VerticalLine(
                      x: clampedPhotoTime,
                      color: Colors.white.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [3, 3],
                    ),
                  ],
                ),
              ),
            ),

            // Photo marker dot (positioned on top of the chart)
            if (clampedPhotoTime >= 0 && clampedPhotoTime <= maxTime)
              Positioned(
                left: markerX - 6, // Center the 12px dot
                top: markerY - 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyan, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 6,
                    color: Colors.cyan,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Interpolate depth at a given timestamp from the profile data.
  double _interpolateDepth(List<DiveProfilePoint> profile, int timestamp) {
    if (profile.isEmpty) return 0;
    if (profile.length == 1) return profile.first.depth;

    // Find bracketing points
    DiveProfilePoint? before;
    DiveProfilePoint? after;

    for (final point in profile) {
      if (point.timestamp <= timestamp) {
        before = point;
      }
      if (point.timestamp >= timestamp && after == null) {
        after = point;
      }
    }

    // Handle edge cases
    if (before == null) return profile.first.depth;
    if (after == null) return profile.last.depth;
    if (before.timestamp == after.timestamp) return before.depth;

    // Linear interpolation
    final ratio =
        (timestamp - before.timestamp) / (after.timestamp - before.timestamp);
    return before.depth + (after.depth - before.depth) * ratio;
  }
}

/// A positioned wrapper for the mini profile overlay.
///
/// Places the overlay in the lower-right corner with animation.
class PositionedMiniProfileOverlay extends StatelessWidget {
  final List<DiveProfilePoint> profile;
  final int photoElapsedSeconds;
  final double? photoDepthMeters;
  final AppSettings settings;
  final bool visible;
  final VoidCallback? onTap;

  const PositionedMiniProfileOverlay({
    super.key,
    required this.profile,
    required this.photoElapsedSeconds,
    this.photoDepthMeters,
    required this.settings,
    this.visible = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16, // Lower right corner
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.8,
          duration: const Duration(milliseconds: 200),
          child: MiniDiveProfileOverlay(
            profile: profile,
            photoElapsedSeconds: photoElapsedSeconds,
            photoDepthMeters: photoDepthMeters,
            settings: settings,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
