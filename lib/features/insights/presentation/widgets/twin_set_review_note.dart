import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/tank_configuration/twin_set_candidates.dart';
import 'package:submersion/features/insights/presentation/open_chart_dives.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/twin_set_review_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('TwinSetReviewNote');

/// The offer on the Tank configuration card to re-role the Back Gas
/// cylinders the retired twin set guess counted (issue #3374): how many
/// dives carry one, with Mark as twin sets (after a confirmation), Review
/// dives (the dive list on exactly those dives) and Dismiss (remembered per
/// diver on this device).
///
/// Renders nothing while the candidates load, when the load failed, when
/// there are none, or once dismissed.
class TwinSetReviewNote extends ConsumerWidget {
  const TwinSetReviewNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(twinSetCandidatesProvider).value;
    if (candidates == null || candidates.tankIds.isEmpty) {
      return const SizedBox.shrink();
    }
    if (ref.watch(twinSetReviewDismissedProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.insights_gas_twinSetReview_title(candidates.diveIds.length),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.insights_gas_twinSetReview_body(
              units.formatTankVolume(twinSetMinVolumeLiters, null),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _mark(context, ref, candidates),
                child: Text(l10n.insights_gas_twinSetReview_mark),
              ),
              TextButton(
                onPressed: () => openHeldChartDives(
                  context,
                  ref,
                  chart: l10n.insights_gas_tankConfig_title,
                  row: l10n.insights_gas_twinSetReview_chart,
                  ids: candidates.diveIds,
                ),
                child: Text(l10n.insights_gas_twinSetReview_review),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(twinSetReviewDismissedProvider.notifier).dismiss(),
                child: Text(l10n.insights_gas_twinSetReview_dismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _mark(
    BuildContext context,
    WidgetRef ref,
    TwinSetCandidates candidates,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.insights_gas_twinSetReview_confirmTitle),
        content: Text(
          l10n.insights_gas_twinSetReview_confirmBody(
            candidates.tankIds.length,
            l10n.insights_gas_twinSetReview_diveCount(
              candidates.diveIds.length,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.insights_gas_twinSetReview_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.insights_gas_twinSetReview_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Only rows still at Back Gas: a role a peer changed since the note
      // was built was a choice, and stands.
      final changed = await ref
          .read(diveRepositoryProvider)
          .setTankRoles(
            candidates.tankIds,
            TankRole.twinSet,
            onlyFrom: TankRole.backGas,
          );
      if (!context.mounted) return;
      ref.invalidate(twinSetCandidatesProvider);
      ref.invalidate(tankConfigurationStatsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.insights_gas_twinSetReview_done(changed))),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set twin set roles',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.insights_gas_twinSetReview_failed)),
      );
    }
  }
}
