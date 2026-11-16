import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/link_plan_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_plan_link_sitting.dart';
import 'package:submersion/features/planner/presentation/plan_link_actions.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Compare card's editor: which plan is linked to the dive, with Link
/// (the plan sheet, then today's confirm) and Unlink, held until Save
/// (issue #4527, plan 6). What-ifs are records of their own and are made in
/// the lab, open or locked.
class DiveCompareCardEditor extends ConsumerStatefulWidget {
  const DiveCompareCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveCompareCardEditor> createState() =>
      _DiveCompareCardEditorState();
}

class _DiveCompareCardEditorState extends ConsumerState<DiveCompareCardEditor> {
  EditSession<Dive> get session => widget.session;

  @override
  void initState() {
    super.initState();
    _redrawWhenRead();
  }

  /// The link is read as the sitting starts, and keeping it tells no one:
  /// an editor opened before it is in draws again once it is.
  void _redrawWhenRead() {
    session.settled().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _retry() {
    reloadDivePlanLink(session);
    _redrawWhenRead();
    setState(() {});
  }

  Future<void> _link(BuildContext context) async {
    final diveId = session.stored.id;
    final planId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LinkPlanSheet(diveId: diveId),
    );
    if (planId == null || !context.mounted) return;
    final confirmed = await confirmPlanLink(
      context,
      ref,
      planId: planId,
      diveId: diveId,
    );
    if (!confirmed) return;
    setPlanLink(session, planId);
  }

  Future<void> _unlink(BuildContext context) async {
    if (!await confirmPlanUnlink(context)) return;
    setPlanLink(session, null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final link = sittingPlanLink(session);
        if (link == null && planLinkLoadFailed(session)) {
          return SittingLoadFailed(onRetry: _retry);
        }
        if (link == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final planId = link.planId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (planId != null)
              FutureBuilder(
                // Keyed by the plan, so a new link reads its own name.
                key: ValueKey(planId),
                future: ref.read(divePlanRepositoryProvider).getPlan(planId),
                builder: (context, snapshot) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text(snapshot.data?.name ?? ''),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _link(context),
                  icon: const Icon(Icons.link),
                  label: Text(l10n.diveLab_compare_linkPlan),
                ),
                if (planId != null)
                  TextButton(
                    onPressed: () => _unlink(context),
                    child: Text(l10n.diveLab_compare_unlinkPlan),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
