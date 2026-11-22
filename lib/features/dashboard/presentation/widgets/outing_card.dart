import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_outings_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/outing_sites_map.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One postcard on Home's Recent outings panel: a cover, then the outing's
/// name, dates and numbers. The cover is the outing's chosen photo or video;
/// without one, or when it cannot be drawn, a map of the sites dived, or the
/// depth skyline when no site has a position.
class OutingCard extends ConsumerStatefulWidget {
  final HomeOuting outing;

  /// The depth, in metres, every card's skyline is drawn against, so a pool
  /// session reads shallow beside a reef trip.
  final double skylineScaleMeters;
  final VoidCallback onTap;

  const OutingCard({
    required this.outing,
    required this.skylineScaleMeters,
    required this.onTap,
    super.key,
  });

  @override
  ConsumerState<OutingCard> createState() => _OutingCardState();
}

class _OutingCardState extends ConsumerState<OutingCard> {
  bool _coverFailed = false;
  bool _coverReady = false;

  @override
  void didUpdateWidget(OutingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outing.cover?.id != widget.outing.cover?.id) {
      _coverFailed = false;
      _coverReady = false;
    } else if (!identical(oldWidget.outing, widget.outing)) {
      // Fresh data after a media or dive change: try a failed cover again
      // (a file back on its drive, a photo a sync delivered).
      _coverFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final outing = widget.outing.outing;
    final cover = widget.outing.cover;
    final name = outing.name ?? l10n.dashboard_outings_unnamed;
    final dates = outingDates(units, l10n, outing.firstDay, outing.lastDay);
    final stats = [
      l10n.dashboard_outings_dives(outing.diveCount),
      if (outing.maxDepth != null)
        l10n.dashboard_outings_maxDepth(
          units.formatDepth(outing.maxDepth, decimals: 0),
        ),
      if (outing.speciesCount > 0)
        l10n.dashboard_outings_species(outing.speciesCount),
    ];

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [name, dates, ...stats].join(', '),
      // excludeSemantics drops the InkWell's own action; put it back.
      onTap: widget.onTap,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The whole cover is part of the card's tap: a photo still
              // downloading would otherwise take the tap to retry.
              Expanded(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      fit: StackFit.expand,
                      children: [
                        // Shown until the cover has drawn, and for good when
                        // it cannot: a missing file, a photo still on its
                        // way, a video with no poster. A map of the sites
                        // dived, faded into the text strip, or the depth
                        // skyline when no site has a position. Gone once
                        // the photo has drawn, so a photo card holds no map
                        // or tiles it never shows.
                        if (cover == null || _coverFailed || !_coverReady)
                          if (outing.sites.isNotEmpty)
                            _MapCover(
                              fadeColor: scheme.surface,
                              // A map places its camera once; a new key
                              // places it again when the sites change.
                              child: OutingSitesMap(
                                key: ValueKey(Object.hashAll(outing.sites)),
                                sites: outing.sites,
                              ),
                            )
                          else
                            OutingSkyline(
                              depths: outing.depths,
                              scaleMeters: widget.skylineScaleMeters,
                            ),
                        if (cover != null && !_coverFailed)
                          Opacity(
                            opacity: _coverReady ? 1 : 0,
                            child: MediaItemView(
                              item: cover,
                              thumbnail: true,
                              fit: BoxFit.cover,
                              targetSize:
                                  box.biggest *
                                  MediaQuery.devicePixelRatioOf(context),
                              onImageReady: (_, _) {
                                if (mounted && !_coverReady) {
                                  setState(() => _coverReady = true);
                                }
                              },
                              onImageFailed: () {
                                if (mounted) {
                                  setState(() => _coverFailed = true);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      dates,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stats.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A map cover that fades into the card's text strip below it. Lighter than
/// the dive details header's fade, whose text sits on the map: here only
/// the bottom edge needs to meet the strip. The map stops [_inset] short of
/// the bottom, under a band the fade has made solid, so a sub-pixel offset
/// during an overscroll cannot show its edge as a bright line (the header
/// backdrop's reason for the same inset).
class _MapCover extends StatelessWidget {
  final Color fadeColor;
  final Widget child;

  const _MapCover({required this.fadeColor, required this.child});

  static const double _inset = 6;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight;
      final solid = h > _inset ? (h - _inset) / h : 0.0;
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: _inset),
            child: child,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.55 * solid, solid, 1],
                  colors: [
                    fadeColor.withValues(alpha: 0),
                    fadeColor.withValues(alpha: 0.15),
                    fadeColor,
                    fadeColor,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// An outing's dates: one day, or the first through the last.
String outingDates(
  UnitFormatter units,
  AppLocalizations l10n,
  DateTime first,
  DateTime last,
) => DateUtils.isSameDay(first, last)
    ? units.formatDate(first)
    : units.formatDateRange(first, last, l10n: l10n);

/// An outing's dives as bars hanging from a surface line, each as long as
/// that dive was deep against [scaleMeters], on the theme's container tint.
class OutingSkyline extends StatelessWidget {
  final List<double> depths;
  final double scaleMeters;

  const OutingSkyline({
    required this.depths,
    required this.scaleMeters,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SkylinePainter(
          depths: depths,
          scaleMeters: scaleMeters,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  final List<double> depths;
  final double scaleMeters;
  final Color color;

  _SkylinePainter({
    required this.depths,
    required this.scaleMeters,
    required this.color,
  });

  static const double _maxBar = 12;
  static const double _gapRatio = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || depths.isEmpty) return;
    final side = size.width * 0.1;
    final top = size.height * 0.2;
    final room = size.height - top - size.height * 0.1;
    final span = size.width - 2 * side;
    final n = depths.length;
    final bar = math.min(_maxBar, span / (n + (n - 1) * _gapRatio));
    final gap = bar * _gapRatio;
    final used = n * bar + (n - 1) * gap;
    final left = (size.width - used) / 2;
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(side, top - 1.5, span, 1.5),
      Paint()..color = color.withValues(alpha: 0.5),
    );
    final scale = scaleMeters <= 0 ? 1.0 : scaleMeters;
    for (var i = 0; i < n; i++) {
      final h = math.max(2.0, depths[i].clamp(0, scale) / scale * room);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + i * (bar + gap), top, bar, h),
          Radius.circular(math.min(2, bar / 3)),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SkylinePainter old) =>
      old.depths != depths ||
      old.scaleMeters != scaleMeters ||
      old.color != color;
}
