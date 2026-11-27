import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/media/data/services/bulk_gear_link_service.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/gear_checklist.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// Links gear to the photos and videos in [mediaIds] (issue #5046).
///
/// Opens [BulkGearSheet]. Once the diver confirms, the links are made and
/// removed on every photo in one transaction, and a SnackBar offers Undo,
/// as bulk Edit tags does.
Future<BulkActionOutcome> showBulkGearSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> mediaIds,
}) async {
  if (mediaIds.isEmpty) return BulkActionOutcome.cancelled;
  // Captured before the sheet opens: Undo can run after the view that
  // started this edit is gone.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final errorColor = Theme.of(context).colorScheme.error;
  final service = BulkGearLinkService(ref.read(mediaGearRepositoryProvider));

  final delta = await showModalBottomSheet<MembershipDelta>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) =>
          BulkGearSheet(mediaIds: mediaIds, scrollController: scrollController),
    ),
  );
  if (delta == null || delta.isEmpty) return BulkActionOutcome.cancelled;

  try {
    final prior = await service.apply(
      mediaIds: mediaIds,
      addGearIds: delta.addIds.toSet(),
      removeGearIds: delta.removeIds.toSet(),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.media_bulkGear_applied(mediaIds.length)),
        duration: const Duration(seconds: 5),
        // An action makes a SnackBar persist; keep the 5 s dismiss (#406).
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.tags_bulk_undo,
          onPressed: () async {
            try {
              await service.undo(prior);
            } catch (e, stackTrace) {
              LoggerService.forClass(BulkGearSheet).error(
                'Failed to undo a bulk gear link',
                error: e,
                stackTrace: stackTrace,
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.media_bulkGear_undoFailed),
                  backgroundColor: errorColor,
                ),
              );
            }
          },
        ),
      ),
    );
    return BulkActionOutcome.completed;
  } catch (e, stackTrace) {
    LoggerService.forClass(
      BulkGearSheet,
    ).error('Failed to link gear', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.media_bulkGear_failed('$e')),
        backgroundColor: errorColor,
      ),
    );
    return BulkActionOutcome.failed;
  }
}

/// The bulk gear editor: one tri-state row per item already linked to some
/// of the photos (on all; on some, left as is; on none), Add for the rest of
/// the diver's gear, and Apply behind a confirmation naming every change.
///
/// Pops the confirmed [MembershipDelta]; any other way out pops null.
class BulkGearSheet extends ConsumerStatefulWidget {
  const BulkGearSheet({
    super.key,
    required this.mediaIds,
    required this.scrollController,
  });

  /// The photos and videos the links go on; never a document or gear photo.
  final List<String> mediaIds;

  /// Supplied by the enclosing [DraggableScrollableSheet].
  final ScrollController scrollController;

  @override
  ConsumerState<BulkGearSheet> createState() => _BulkGearSheetState();
}

class _BulkGearSheetState extends ConsumerState<BulkGearSheet> {
  late final Future<void> _loading;
  Map<String, int> _counts = const {};
  List<BulkMembershipItem> _members = const [];
  List<EquipmentItem> _gear = const [];
  MembershipDelta _delta = MembershipDelta.empty;
  ({int serial, Set<String> ids})? _ensureOn;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  BulkMembershipItem? _member(String id) {
    for (final g in _gear) {
      if (g.id == id) {
        return BulkMembershipItem(
          id: g.id,
          label: g.name,
          icon: equipmentItemIcon(g),
        );
      }
    }
    // Gear the diver cannot see is not offered: its links stay as they are.
    return null;
  }

  static int _byLabel(BulkMembershipItem a, BulkMembershipItem b) =>
      compareTextForSort(a.label, b.label);

  Future<void> _load() async {
    _gear = await ref.read(allEquipmentProvider.future);
    final counts = await ref
        .read(mediaGearRepositoryProvider)
        .gearCountsFor(widget.mediaIds);
    _counts = counts;
    _members = [for (final id in counts.keys) ?_member(id)]..sort(_byLabel);
  }

  Future<void> _addGear() async {
    final picked = await showGearChooser(context);
    if (picked == null || picked.isEmpty || !mounted) return;
    final listed = {for (final m in _members) m.id};
    setState(() {
      _members = [
        ..._members,
        for (final id in picked)
          if (!listed.contains(id)) ?_member(id),
      ]..sort(_byLabel);
      _ensureOn = (serial: (_ensureOn?.serial ?? 0) + 1, ids: picked);
    });
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final total = widget.mediaIds.length;
    final sections = summarizeBulkMembership([
      (title: l10n.media_info_gear, delta: _delta, members: _members),
    ]);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tags_bulk_confirmTitle),
        content: SingleChildScrollView(
          child: BulkChangeSummary(
            sections: sections,
            addingHeading: l10n.media_bulkGear_confirmAdding(total),
            removingHeading: l10n.media_bulkGear_confirmRemoving(total),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('bulkGear_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.common_action_apply),
          ),
        ],
      ),
    );
    // Cancel returns to the sheet with the edits kept.
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(_delta);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = widget.mediaIds.length;
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.media_bulkGear_failed('${snapshot.error}')),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                children: [
                  BulkMembershipEditor(
                    title: l10n.media_bulkGear_title(total),
                    total: total,
                    labels: BulkMembershipLabels(
                      onAll: l10n.tags_bulk_onAll,
                      onSome: l10n.tags_bulk_onSome,
                      adding: l10n.tags_bulk_adding,
                      removing: l10n.tags_bulk_removing,
                      empty: l10n.media_info_noGear,
                      add: l10n.common_action_add,
                    ),
                    items: _members,
                    counts: _counts,
                    onAdd: _addGear,
                    onChanged: (delta) => setState(() => _delta = delta),
                    ensureOn: _ensureOn,
                    absentStartsChecked: false,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const ValueKey('bulkGear_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_action_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('bulkGear_apply'),
                      onPressed: _delta.isEmpty ? null : _confirm,
                      child: Text(l10n.common_action_apply),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
