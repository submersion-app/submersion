import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The editing column of Mission Control: segments and tanks always visible,
/// everything else in the Setup accordion.
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

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        const SegmentList(),
        const SizedBox(height: 12),
        const PlanTankList(),
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
