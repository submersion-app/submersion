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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
            theme.colorScheme.tertiary.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Decorative wave pattern
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.waves,
              size: 150,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            right: 40,
            top: 10,
            child: Icon(
              Icons.scuba_diving,
              size: 60,
              color: Colors.white.withValues(alpha: 0.15),
            ),
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                  loading: () => Text(
                    '${_getGreeting()}!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  error: (_, _) => Text(
                    '${_getGreeting()}!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Headline stats
                statsAsync.when(
                  data: (stats) => Text(
                    _buildHeadlineStats(stats),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  loading: () => Text(
                    'Loading your dive stats...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  error: (_, _) => Text(
                    'Ready to explore the depths?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
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

  String _buildHeadlineStats(DiveStatistics stats) {
    if (stats.totalDives == 0) {
      return 'Ready to log your first dive?';
    }

    final parts = <String>[];

    // Total dives
    final diveText = stats.totalDives == 1
        ? '1 dive logged'
        : '${stats.totalDives} dives logged';
    parts.add(diveText);

    // Total hours
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

    return parts.join(' • ');
  }
}
