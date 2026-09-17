import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// Edits the tags of the equipment items in [equipmentIds] (issue #1942).
///
/// Opens [BulkEquipmentTagSheet]. Once the diver confirms, the tags go on
/// and come off every item in one transaction, and a SnackBar offers Undo.
/// Returns [BulkActionOutcome.cancelled] when the diver backs out, so the
/// selection survives, and [BulkActionOutcome.failed] when the write throws.
Future<BulkActionOutcome> showBulkEquipmentTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> equipmentIds,
}) async {
  if (equipmentIds.isEmpty) return BulkActionOutcome.cancelled;
  // Captured before the sheet opens: Undo can run after the list that
  // started this edit is gone.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final errorColor = Theme.of(context).colorScheme.error;
  final service = ref.read(bulkEquipmentTagServiceProvider);

  final delta = await showModalBottomSheet<MembershipDelta>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => BulkEquipmentTagSheet(
        equipmentIds: equipmentIds,
        scrollController: scrollController,
      ),
    ),
  );
  if (delta == null || delta.isEmpty) return BulkActionOutcome.cancelled;

  try {
    final prior = await service.apply(
      equipmentIds: equipmentIds,
      addTagIds: delta.addIds.toSet(),
      removeTagIds: delta.removeIds.toSet(),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.equipment_bulkTags_applied(equipmentIds.length)),
        duration: const Duration(seconds: 5),
        // A SnackBar with an action defaults to persist: true, which stops
        // the auto-dismiss. Force the 5 s dismiss and add a close icon, so
        // the banner can go without tapping Undo (#406).
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.equipment_bulkTags_undo,
          // A failed restore says so: the banner that offered Undo is
          // already gone, so silence would read as success.
          onPressed: () async {
            try {
              await service.undo(prior);
            } catch (e, stackTrace) {
              LoggerService.forClass(BulkEquipmentTagSheet).error(
                'Failed to undo a bulk equipment tag edit',
                error: e,
                stackTrace: stackTrace,
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.equipment_bulkTags_undoFailed),
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
      BulkEquipmentTagSheet,
    ).error('Failed to edit equipment tags', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.equipment_bulkTags_failed('$e')),
        backgroundColor: errorColor,
      ),
    );
    return BulkActionOutcome.failed;
  }
}

/// The bulk tag editor for equipment: one tri-state row per tag (on all; on
/// some, left as is; on none) for every equipment tag and every tag already
/// on a selected item, an Add button, and Apply behind a confirmation that
/// names every change (#1754).
///
/// Pops the confirmed [MembershipDelta]; any other way out pops null.
class BulkEquipmentTagSheet extends ConsumerStatefulWidget {
  const BulkEquipmentTagSheet({
    super.key,
    required this.equipmentIds,
    required this.scrollController,
  });

  final List<String> equipmentIds;

  /// Supplied by the enclosing [DraggableScrollableSheet].
  final ScrollController scrollController;

  @override
  ConsumerState<BulkEquipmentTagSheet> createState() =>
      _BulkEquipmentTagSheetState();
}

class _BulkEquipmentTagSheetState extends ConsumerState<BulkEquipmentTagSheet> {
  late final Future<void> _loading;
  Map<String, int> _counts = const {};
  List<BulkMembershipItem> _members = const [];
  MembershipDelta _delta = MembershipDelta.empty;

  /// Switches on the tags picked through Add. Rows on none of the items
  /// start unchecked here, so appending them alone would add nothing.
  ({int serial, Set<String> ids})? _ensureOn;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  static BulkMembershipItem _member(String id, String label) =>
      BulkMembershipItem(id: id, label: label, icon: Icons.label_outline);

  static int _byLabel(BulkMembershipItem a, BulkMembershipItem b) =>
      a.label.toLowerCase().compareTo(b.label.toLowerCase());

  Future<void> _load() async {
    final counts = await ref
        .read(equipmentTagRepositoryProvider)
        .tagCountsForEquipment(widget.equipmentIds);
    final tags = await ref.read(tagsProvider.future);
    final known = {for (final t in tags) t.id};
    _counts = counts;
    _members = [
      for (final t in tags)
        if (t.appliesTo(TagScope.equipment) || (counts[t.id] ?? 0) > 0)
          _member(t.id, t.name),
      // A linked tag missing from the diver's list keeps its row, named by
      // its id, as the dive editor does.
      for (final id in counts.keys)
        if (!known.contains(id)) _member(id, id),
    ]..sort(_byLabel);
  }

  void _addMembers(List<Tag> tags) {
    if (tags.isEmpty) return;
    final listed = {for (final m in _members) m.id};
    setState(() {
      _members = [
        ..._members,
        for (final t in tags)
          if (!listed.contains(t.id)) _member(t.id, t.name),
      ]..sort(_byLabel);
      _ensureOn = (
        serial: (_ensureOn?.serial ?? 0) + 1,
        ids: {for (final t in tags) t.id},
      );
    });
  }

  /// The dialog the dive bulk editor opens from its Tags Add button, scoped
  /// to equipment tags.
  void _addTags() {
    final l10n = context.l10n;
    var picked = <Tag>[];
    showDialog<void>(
      context: context,
      // The StatefulBuilder wraps the whole dialog, not just its content, so
      // the Browse action in the button row can restage `picked` too.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.equipment_bulkTags_tagsLabel),
          content: TagInputWidget(
            selectedTags: picked,
            onTagsChanged: (tags) => setDialogState(() => picked = tags),
            scope: TagScope.equipment,
          ),
          actions: [
            TextButton(
              // `ctx` is inside the dialog route, so the picker lands on the
              // same (root) navigator and opens above the dialog (#1366).
              onPressed: () => showTagPickerSheet(
                context,
                selected: picked,
                onPicked: (tags) => setDialogState(() => picked = tags),
                scope: TagScope.equipment,
                host: ctx,
              ),
              child: Text(l10n.tags_action_browse),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () {
                _addMembers(picked);
                Navigator.pop(ctx);
              },
              child: Text(l10n.common_action_add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final total = widget.equipmentIds.length;
    final sections = summarizeBulkMembership([
      (
        title: l10n.equipment_bulkTags_tagsLabel,
        delta: _delta,
        members: _members,
      ),
    ]);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.equipment_bulkTags_confirmTitle),
        content: SingleChildScrollView(
          child: BulkChangeSummary(
            sections: sections,
            addingHeading: l10n.equipment_bulkTags_confirmAdding(total),
            removingHeading: l10n.equipment_bulkTags_confirmRemoving(total),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('bulkEquipmentTags_confirm'),
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
    final total = widget.equipmentIds.length;
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.tags_picker_errorLoading('${snapshot.error}')),
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
                    title: l10n.equipment_bulkTags_title(total),
                    total: total,
                    labels: BulkMembershipLabels(
                      onAll: l10n.equipment_bulkTags_onAll,
                      onSome: l10n.equipment_bulkTags_onSome,
                      adding: l10n.equipment_bulkTags_adding,
                      removing: l10n.equipment_bulkTags_removing,
                      empty: l10n.equipment_bulkTags_empty,
                      add: l10n.common_action_add,
                    ),
                    items: _members,
                    counts: _counts,
                    onAdd: _addTags,
                    onChanged: (delta) => setState(() => _delta = delta),
                    ensureOn: _ensureOn,
                    // Every equipment tag is listed, so a tag on none of the
                    // items is an offer and starts unchecked.
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
                      key: const ValueKey('bulkEquipmentTags_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_action_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('bulkEquipmentTags_apply'),
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
