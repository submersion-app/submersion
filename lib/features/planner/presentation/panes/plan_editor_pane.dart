import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_list.dart';
import 'package:submersion/features/planner/presentation/mission/mission_toggle_row.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_dive_details_card.dart';
import 'package:submersion/features/planner/presentation/providers/plan_logged_dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_details_card.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_tanks_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The editing column of Mission Control: the dive's details, tanks and
/// segments always visible, everything else in the Setup accordion.
///
/// Tanks come first because a segment's tank dropdown can only offer
/// cylinders that already exist, so authoring the profile before the gas
/// means re-picking the tank on every segment afterwards.
///
/// On a setup-focus request the pane scrolls toward the accordion (its last
/// child) so the lazily-built accordion materializes and can consume the
/// pending focus itself.
class PlanEditorPane extends ConsumerStatefulWidget {
  const PlanEditorPane({super.key});

  @override
  ConsumerState<PlanEditorPane> createState() => _PlanEditorPaneState();
}

class _PlanEditorPaneState extends ConsumerState<PlanEditorPane> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(setupFocusSectionProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    });

    final missionOn = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );

    // A logged dive picked in the series bar: its details and tanks
    // read-only, and the segments of the plan it was dived from, if any
    // (issue #3565). It has no plan settings of its own.
    if (ref.watch(viewingLoggedDiveProvider)) {
      final plan = ref.watch(viewedLoggedDivePlanStateProvider);
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        children: [
          const LoggedDiveDetailsCard(),
          const LoggedDiveTanksCard(),
          const SizedBox(height: 12),
          if (plan != null)
            SegmentList(plan: plan)
          else
            Padding(
              key: const Key('loggedDiveNotPlanned'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.l10n.plannerSeries_loggedNotPlanned,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      );
    }

    // A plan whose dive has been dived is locked (issue #3565): it scrolls
    // and its settings open, but nothing in it takes input.
    final locked = ref.watch(planLockedProvider);
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        IgnorePointer(ignoring: locked, child: const PlanDiveDetailsCard()),
        IgnorePointer(ignoring: locked, child: const PlanTankList()),
        const SizedBox(height: 12),
        if (!locked) const MissionToggleRow(),
        if (missionOn)
          IgnorePointer(ignoring: locked, child: const MissionLegList())
        else if (locked)
          SegmentList(plan: ref.watch(divePlanNotifierProvider))
        else
          const SegmentList(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: PlanSectionHeader(context.l10n.divePlanner_label_planSettings),
        ),
        const PlanSetupAccordion(),
      ],
    );
  }
}
