import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_diver_avatar.dart';
import 'package:submersion/features/insights/domain/career_totals.dart';
import 'package:submersion/features/insights/presentation/providers/career_totals_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// A full-width ocean header with a compact greeting, career stats, and logo.
/// The existing ocean painter owns all bubble shapes, motion, and timing.
class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(dashboardDiverProvider);
    final careerAsync = ref.watch(careerTotalsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final greeting = _getGreeting(context);
    final greetingText = diverAsync.when(
      data: (diver) => l10n.dashboard_greeting_withName(
        greeting,
        diver?.name.split(' ').first ?? l10n.dashboard_hero_diverFallbackName,
      ),
      loading: () => l10n.dashboard_greeting_withoutName(greeting),
      error: (_, _) => l10n.dashboard_greeting_withoutName(greeting),
    );

    return Semantics(
      label: l10n.dashboard_semantics_greetingBanner,
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0x2BFFFFFF) : const Color(0x24000000),
            ),
          ),
        ),
        child: OceanBackground(
          // Null keeps the shared light palette exactly as it is today.
          backgroundGradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B304A), Color(0xFF061B2D)],
                )
              : null,
          backgroundHighlight: isDark
              ? const RadialGradient(
                  center: Alignment(-0.84, -1),
                  radius: 0.65,
                  colors: [Color(0xAA16A5B3), Color(0x0016A5B3)],
                  transform: _HeaderHighlightTransform(),
                )
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Available pane width matters more than the window width.
              // Enlarged text gets a stacked layout instead of being scaled down.
              final wide =
                  constraints.maxWidth >= ResponsiveBreakpoints.desktop &&
                  MediaQuery.textScalerOf(context).scale(18) <= 24;
              final identity = Row(
                children: [
                  const HeroDiverAvatar(),
                  Expanded(
                    child: Text(
                      greetingText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
              final logo = ExcludeSemantics(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: wide ? 58 : 46,
                  height: wide ? 58 : 46,
                ),
              );
              Widget status(String text) => Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              );
              final stats = careerAsync.when(
                data: (career) => career.combinedDives == 0
                    ? status(_noDivesHeadline(context, ref))
                    : _HeroStats(career: career, showPlaces: wide),
                loading: () => status(l10n.dashboard_hero_loading),
                error: (_, _) => status(l10n.dashboard_hero_error),
              );
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 30 : 20,
                  vertical: wide ? 27 : 21,
                ),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: identity),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: stats,
                            ),
                          ),
                          const SizedBox(width: 28),
                          logo,
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: identity),
                              const SizedBox(width: 16),
                              logo,
                            ],
                          ),
                          const SizedBox(height: 12),
                          stats,
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.l10n.dashboard_greeting_morning;
    if (hour < 17) return context.l10n.dashboard_greeting_afternoon;
    return context.l10n.dashboard_greeting_evening;
  }

  /// Zero career dives can mean every logged dive was excluded from stats.
  String _noDivesHeadline(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(logbookDiveCountsProvider)
        .when(
          loading: () => l10n.dashboard_hero_loading,
          error: (_, _) => l10n.dashboard_hero_error,
          data: (counts) => counts.allExcluded
              ? l10n.insights_empty_allExcluded_title
              : l10n.dashboard_hero_noDives,
        );
  }
}

/// Stretch the glow to the header's aspect ratio, anchored at its origin.
/// This affects only the static background, never the ocean-effect painter.
class _HeaderHighlightTransform extends GradientTransform {
  const _HeaderHighlightTransform();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final center = const Alignment(-0.84, -1).withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(
        bounds.width / bounds.shortestSide,
        bounds.height / bounds.shortestSide,
        1,
        1,
      )
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}

/// Career totals include prior experience; sites/countries remain logged-only.
class _HeroStats extends ConsumerWidget {
  final CareerTotals career;
  final bool showPlaces;

  const _HeroStats({required this.career, required this.showPlaces});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final seconds = career.combinedTimeSeconds;
    final hours = seconds / 3600;
    final shortDive = seconds > 0 && seconds < 3600;
    final items = <(String, String)>[
      ('${career.combinedDives}', l10n.dashboard_hero_statDives),
      (
        shortDive
            ? '${seconds ~/ 60}'
            : hours > 0 && hours < 10
            ? hours.toStringAsFixed(1)
            : '${hours.round()}',
        shortDive
            ? l10n.insights_focus_unit_minutes
            : l10n.dashboard_hero_statHours,
      ),
    ];
    if (showPlaces) {
      final sites = ref.watch(diveStatisticsProvider).valueOrNull?.totalSites;
      final countries =
          ref
              .watch(dashboardQuickStatsProvider)
              .valueOrNull
              ?.countriesVisited ??
          0;
      if (sites != null) items.add(('$sites', l10n.dashboard_hero_statSites));
      if (countries > 0) {
        items.add(('$countries', l10n.dashboard_hero_statCountries));
      }
    }
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        for (final (value, label) in items)
          Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
