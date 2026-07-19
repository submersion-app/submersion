import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/safety/presentation/utils/no_fly_format.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Safety hub: current no-fly status plus entry points to the safety
/// tooling (emergency card and near-miss log arrive in later phases).
class SafetyHubPage extends ConsumerStatefulWidget {
  const SafetyHubPage({super.key});

  @override
  ConsumerState<SafetyHubPage> createState() => _SafetyHubPageState();
}

class _SafetyHubPageState extends ConsumerState<SafetyHubPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the countdown display once a minute while the page is open.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusAsync = ref.watch(noFlyStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyHub_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Only render the all-clear/active card from real data. During
          // loading or on error, show an explicit state instead of letting a
          // null value read as "no flying restriction" on a safety banner.
          statusAsync.when(
            data: (status) => _NoFlyCard(status: status),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
            error: (_, _) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(l10n.common_error_tryAgain),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.emergency_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.safetyHub_emergencyCardLink),
              subtitle: Text(l10n.safetyHub_emergencyCardLink_subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/safety/emergency-card'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.hourglass_bottom),
              title: Text(l10n.safetyHub_surfaceIntervalLink),
              subtitle: Text(l10n.safetyHub_surfaceIntervalLink_subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/planning/surface-interval'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.safetyHub_settingsLink),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/safety'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFlyCard extends StatelessWidget {
  final NoFlyStatus? status;

  const _NoFlyCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
    final active = status != null && status!.until.isAfter(now);

    if (!active) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.flight_takeoff, color: theme.colorScheme.primary),
          title: Text(l10n.safetyHub_noFly_clear_title),
          subtitle: Text(l10n.safetyHub_noFly_clear_subtitle),
        ),
      );
    }

    final remaining = status!.remaining(now);
    final untilLocal = status!.until.toLocal();
    final untilText = DateFormat.E().add_jm().format(untilLocal);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.airplanemode_inactive,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.safetyHub_noFly_active_title(
                      formatNoFlyRemaining(remaining),
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.safetyHub_noFly_until(untilText),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _categoryText(l10n, status!.category),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.safetyHub_noFly_disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryText(AppLocalizations l10n, NoFlyCategory category) {
    final hours = status!.interval.inHours;
    return switch (category) {
      NoFlyCategory.single => l10n.safetyHub_noFly_category_single(hours),
      NoFlyCategory.repetitive => l10n.safetyHub_noFly_category_repetitive(
        hours,
      ),
      NoFlyCategory.deco => l10n.safetyHub_noFly_category_deco(hours),
    };
  }
}
