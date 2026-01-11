import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../providers/dashboard_providers.dart';

/// Hero header widget with personalized greeting and key stats
class HeroHeader extends ConsumerWidget {
  const HeroHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(dashboardDiverProvider);
    final statsAsync = ref.watch(diveStatisticsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    // Use container colors in dark mode for better contrast with dark surfaces
    final gradientColors = isDark
        ? [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.9),
            colors.tertiaryContainer.withValues(alpha: 0.8),
          ]
        : [
            colors.primary,
            colors.primary.withValues(alpha: 0.8),
            colors.tertiary.withValues(alpha: 0.6),
          ];
    final textColor = isDark ? colors.onPrimaryContainer : colors.onPrimary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // App icon
          Positioned(
            right: 16,
            top: 8,
            child: Image.asset('assets/icon/icon.png', width: 80, height: 80),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                diverAsync.when(
                  data: (diver) {
                    final greeting = _getGreeting();
                    final name = diver?.name.split(' ').first ?? 'Diver';
                    return Text(
                      '$greeting, $name!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                  loading: () => Text(
                    '${_getGreeting()}!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  error: (_, _) => Text(
                    '${_getGreeting()}!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Headline stats - responsive based on screen width
                statsAsync.when(
                  data: (stats) {
                    // On phones (< 600px), only show dive count to save space
                    // On tablets/desktop, show both dives and hours
                    final screenWidth = MediaQuery.sizeOf(context).width;
                    final showHours = screenWidth >= 600;
                    return Text(
                      _buildHeadlineStats(stats, showHours: showHours),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: textColor.withValues(alpha: 0.9),
                      ),
                    );
                  },
                  loading: () => Text(
                    'Loading your dive stats...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                  error: (_, _) => Text(
                    'Ready to explore the depths?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _buildHeadlineStats(DiveStatistics stats, {bool showHours = true}) {
    if (stats.totalDives == 0) {
      return 'Ready to log your first dive?';
    }

    final parts = <String>[];

    // Total dives
    final diveText = stats.totalDives == 1
        ? '1 dive logged'
        : '${stats.totalDives} dives logged';
    parts.add(diveText);

    // Total hours - only show on wider screens
    if (showHours) {
      final hours = stats.totalTimeSeconds / 3600;
      if (hours >= 1) {
        final hoursText = hours < 10
            ? '${hours.toStringAsFixed(1)} hours underwater'
            : '${hours.round()} hours underwater';
        parts.add(hoursText);
      } else if (stats.totalTimeSeconds > 0) {
        final minutes = stats.totalTimeSeconds ~/ 60;
        parts.add('$minutes minutes underwater');
      }
    }

    return parts.join(' • ');
  }
}
