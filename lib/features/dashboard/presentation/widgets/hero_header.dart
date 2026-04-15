import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Hero header widget with personalized greeting, key stats,
/// and animated ambient ocean effects (caustic shimmer + rising bubbles).
class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(dashboardDiverProvider);
    final statsAsync = ref.watch(diveStatisticsProvider);
    final theme = Theme.of(context);

    return Semantics(
      label: context.l10n.dashboard_semantics_greetingBanner,
      child: OceanBackground(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                      loading: () => Text(
                        context.l10n.dashboard_greeting_withoutName(
                          _getGreeting(context),
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      error: (_, _) => Text(
                        context.l10n.dashboard_greeting_withoutName(
                          _getGreeting(context),
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Headline stats
                    statsAsync.when(
                      data: (stats) {
                        final screenWidth = MediaQuery.sizeOf(context).width;
                        final isNarrow = screenWidth < 600;
                        return Text(
                          _buildHeadlineStats(
                            context,
                            stats,
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
              const SizedBox(width: 16),
              ExcludeSemantics(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 80,
                  height: 80,
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
    DiveStatistics stats, {
    bool isNarrow = false,
  }) {
    if (stats.totalDives == 0) return context.l10n.dashboard_hero_noDives;

    final parts = <String>[];

    final diveText = stats.totalDives == 1
        ? context.l10n.dashboard_hero_divesLoggedOne
        : context.l10n.dashboard_hero_divesLoggedOther(stats.totalDives);
    parts.add(diveText);

    final hours = stats.totalTimeSeconds / 3600;
    if (hours >= 1) {
      final hoursStr = hours < 10
          ? hours.toStringAsFixed(1)
          : hours.round().toString();
      parts.add(context.l10n.dashboard_hero_hoursUnderwater(hoursStr));
    } else if (stats.totalTimeSeconds > 0) {
      final minutes = stats.totalTimeSeconds ~/ 60;
      parts.add(context.l10n.dashboard_hero_minutesUnderwater(minutes));
    }

    return parts.join(isNarrow ? '\n' : ' \u2022 ');
  }
}
