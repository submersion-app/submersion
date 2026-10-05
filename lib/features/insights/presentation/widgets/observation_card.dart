import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/presentation/formatters/observation_sentence.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Opens an Insights category in the detail pane on desktop, or pushes it
/// on a phone, matching how the category list navigates.
void _openInsightsCategory(BuildContext context, String id) {
  if (ResponsiveBreakpoints.isMasterDetail(context)) {
    context.go('/insights?selected=$id');
  } else {
    context.push('/insights/$id');
  }
}

/// "See all": the Observations page, as a detail pane or a pushed page.
void openObservationsPage(BuildContext context) =>
    _openInsightsCategory(context, 'observations');

void openObservationTarget(BuildContext context, ObservationTarget target) {
  switch (target) {
    case InsightsCategoryTarget(:final categoryId):
      _openInsightsCategory(context, categoryId);
    case DiveTarget(:final diveId):
      context.push('/dives/$diveId');
    case SiteTarget(:final siteId):
      context.push('/sites/$siteId');
    case BuddyTarget(:final buddyId):
      context.push('/buddies/$buddyId');
    case DiveLogTarget():
      context.go('/dives');
  }
}

IconData _icon(Observation o) => switch (o.kind) {
  ObservationKind.safety => Icons.health_and_safety_outlined,
  ObservationKind.milestone => Icons.emoji_events_outlined,
  ObservationKind.trend => switch (o.facts) {
    TrendFacts(direction: TrendDirection.down) => Icons.trending_down,
    _ => Icons.trending_up,
  },
  ObservationKind.pattern => Icons.repeat,
};

enum _Action { dismiss, mute }

/// One observation: its sentence, a tap to where the numbers live, and a
/// menu to dismiss it or mute its kind, each with Undo.
class ObservationCard extends ConsumerWidget {
  final Observation observation;
  const ObservationCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    final canDismiss = ref.watch(currentDiverProvider).valueOrNull != null;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(_icon(observation), color: scheme.primary),
        title: Text(observationSentence(observation, l10n, units)),
        onTap: () => openObservationTarget(context, observation.target),
        trailing: PopupMenuButton<_Action>(
          tooltip: l10n.insights_observations_actions,
          onSelected: (action) => switch (action) {
            _Action.dismiss => _dismiss(context, ref),
            _Action.mute => _mute(context, ref),
          },
          itemBuilder: (context) => [
            if (canDismiss)
              PopupMenuItem(
                value: _Action.dismiss,
                child: Text(l10n.insights_observations_dismiss),
              ),
            PopupMenuItem(
              value: _Action.mute,
              child: Text(l10n.insights_observations_mute),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _undoBar(String message, String undo, VoidCallback onUndo) =>
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // A SnackBar with an action persists by default; force the 5 s
        // dismiss and a close icon (#406).
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(label: undo, onPressed: onUndo),
      );

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final diver = ref.read(currentDiverProvider).valueOrNull;
    if (diver == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final repo = ref.read(observationDismissalsRepositoryProvider);
    final rule = observation.ruleId;
    final fingerprint = observation.fingerprint;
    try {
      await repo.dismiss(
        diverId: diver.id,
        rule: rule,
        fingerprint: fingerprint,
      );
    } catch (_) {
      // The repository has logged it; the observation stays visible.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.insights_observations_dismissFailed)),
      );
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        _undoBar(
          l10n.insights_observations_dismissed,
          l10n.insights_observations_undo,
          () => unawaited(
            repo
                .undismiss(
                  diverId: diver.id,
                  rule: rule,
                  fingerprint: fingerprint,
                )
                // Logged by the repository; nothing more to show here.
                .catchError((Object _) {}),
          ),
        ),
      );
  }

  Future<void> _mute(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    final rule = observation.ruleId;
    await notifier.setObservationRuleMuted(rule, true);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        _undoBar(
          l10n.insights_observations_muted,
          l10n.insights_observations_undo,
          () => unawaited(notifier.setObservationRuleMuted(rule, false)),
        ),
      );
  }
}
