import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/statistics/domain/career_totals.dart';
import 'package:submersion/features/statistics/presentation/providers/career_totals_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Hero header widget with personalized greeting, key stats,
/// and animated ambient ocean effects (caustic shimmer + rising bubbles).
///
/// At desktop widths (>=800) the app logo anchors left and subdued
/// lifetime stats fill the center; on phones the header keeps the
/// compact greeting + headline stats layout.
///
/// Dive and time totals come from [careerTotalsProvider], so they include the
/// diver's pre-app logbook and agree with the Statistics overview (issue #808).
class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(dashboardDiverProvider);
    final careerAsync = ref.watch(careerTotalsProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Semantics(
      label: context.l10n.dashboard_semantics_greetingBanner,
      child: OceanBackground(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          // Compact insets; tightest on the right so the logo sits close
          // to the banner edge.
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Greeting
                    diverAsync.when(
                      data: (diver) {
                        final greeting = _getGreeting(context);
                        final name =
                            diver?.name.split(' ').first ??
                            context.l10n.dashboard_hero_diverFallbackName;
                        return Text(
                          context.l10n.dashboard_greeting_withName(
                            greeting,
                            name,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                      loading: () => Text(
                        context.l10n.dashboard_greeting_withoutName(
                          _getGreeting(context),
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      error: (_, _) => Text(
                        context.l10n.dashboard_greeting_withoutName(
                          _getGreeting(context),
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isDesktop)
                      Text(
                        DateFormat.yMMMMd(
                          Localizations.localeOf(context).toString(),
                        ).format(DateTime.now()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      )
                    else
                      // Headline stats (phone)
                      careerAsync.when(
                        data: (career) {
                          final screenWidth = MediaQuery.sizeOf(context).width;
                          final isNarrow = screenWidth < 600;
                          return Text(
                            _buildHeadlineStats(
                              context,
                              career,
                              isNarrow: isNarrow,
                            ),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          );
                        },
                        loading: () => Text(
                          context.l10n.dashboard_hero_loading,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        error: (_, _) => Text(
                          context.l10n.dashboard_hero_error,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 24),
                const Expanded(flex: 2, child: _QuietStats()),
              ],
              const SizedBox(width: 16),
              ExcludeSemantics(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 64,
                  height: 64,
                ),
              ),
            ],
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

  String _buildHeadlineStats(
    BuildContext context,
    CareerTotals career, {
    bool isNarrow = false,
  }) {
    final dives = career.combinedDives;
    if (dives == 0) return context.l10n.dashboard_hero_noDives;

    final parts = <String>[];

    // "N dives logged" would misdescribe a total that includes the diver's
    // prior offset -- those dives are precisely the ones NOT logged in-app, and
    // the Statistics breakdown reserves "logged" for the in-app count. Divers
    // without prior experience keep the original copy.
    final String diveText;
    if (career.hasPriorDives) {
      diveText = dives == 1
          ? context.l10n.dashboard_hero_divesTotalOne
          : context.l10n.dashboard_hero_divesTotalOther(dives);
    } else {
      diveText = dives == 1
          ? context.l10n.dashboard_hero_divesLoggedOne
          : context.l10n.dashboard_hero_divesLoggedOther(dives);
    }
    parts.add(diveText);

    final totalTimeSeconds = career.combinedTimeSeconds;
    final hours = totalTimeSeconds / 3600;
    if (hours >= 1) {
      final hoursStr = hours < 10
          ? hours.toStringAsFixed(1)
          : hours.round().toString();
      parts.add(context.l10n.dashboard_hero_hoursUnderwater(hoursStr));
    } else if (totalTimeSeconds > 0) {
      final minutes = totalTimeSeconds ~/ 60;
      parts.add(context.l10n.dashboard_hero_minutesUnderwater(minutes));
    }

    return parts.join(isNarrow ? '\n' : ' • ');
  }
}

/// Subdued lifetime stats for the desktop hero: regular weight, reduced
/// opacity, hairline dividers -- present but never louder than the
/// greeting.
class _QuietStats extends ConsumerWidget {
  const _QuietStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final careerAsync = ref.watch(careerTotalsProvider);
    final quickAsync = ref.watch(dashboardQuickStatsProvider);
    final career = careerAsync.valueOrNull;
    if (career == null || career.combinedDives == 0) {
      return const SizedBox.shrink();
    }
    // Sites stay logged-only: the prior-experience offset records dives and
    // time, not the distinct sites behind them.
    final totalSites = ref
        .watch(diveStatisticsProvider)
        .valueOrNull
        ?.totalSites;
    final countries = quickAsync.valueOrNull?.countriesVisited ?? 0;
    final hours = (career.combinedTimeSeconds / 3600).round();

    final items = <(String, String)>[
      ('${career.combinedDives}', context.l10n.dashboard_hero_statDives),
      ('$hours', context.l10n.dashboard_hero_statHours),
      if (totalSites != null)
        ('$totalSites', context.l10n.dashboard_hero_statSites),
      if (countries > 0)
        ('$countries', context.l10n.dashboard_hero_statCountries),
    ];

    final theme = Theme.of(context);
    // FittedBox: at mid desktop widths the five stat columns can exceed
    // the space between greeting and banner edge; scale down rather than
    // overflow the row.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withValues(alpha: 0.15),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  items[i].$1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  items[i].$2.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 1.2,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
