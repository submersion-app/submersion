import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/tags/data/services/bulk_tag_service.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// The words a bulk tag edit uses that name what is being tagged.
typedef BulkTagSheetLabels = ({
  String Function(int count) confirmAdding,
  String Function(int count) confirmRemoving,
  String empty,
});

/// Edits the tags of the [scope] items in [itemIds] (issues #1942, #1970)
/// through [service].
///
/// Opens [BulkTagSheet]. Once the diver confirms, the tags go on and come
/// off every item in one transaction, and a SnackBar offers Undo. Returns
/// [BulkActionOutcome.cancelled] when the diver backs out, so the selection
/// survives, and [BulkActionOutcome.failed] when the write throws.
Future<BulkActionOutcome> showBulkTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required TagScope scope,
  required BulkTagService service,
  required List<String> itemIds,
  required BulkTagSheetLabels labels,
  String keyPrefix = 'bulkTags',
}) async {
  if (itemIds.isEmpty) return BulkActionOutcome.cancelled;
  // Captured before the sheet opens: Undo can run after the view that
  // started this edit is gone.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final errorColor = Theme.of(context).colorScheme.error;

  final delta = await showModalBottomSheet<MembershipDelta>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => BulkTagSheet(
        scope: scope,
        itemIds: itemIds,
        labels: labels,
        keyPrefix: keyPrefix,
        scrollController: scrollController,
      ),
    ),
  );
  if (delta == null || delta.isEmpty) return BulkActionOutcome.cancelled;

  try {
    final prior = await service.apply(
      itemIds: itemIds,
      addTagIds: delta.addIds.toSet(),
      removeTagIds: delta.removeIds.toSet(),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.tags_bulk_applied(itemIds.length)),
        duration: const Duration(seconds: 5),
        // A SnackBar with an action defaults to persist: true, which stops
        // the auto-dismiss. Force the 5 s dismiss and add a close icon, so
        // the banner can go without tapping Undo (#406).
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.tags_bulk_undo,
          // A failed restore says so: the banner that offered Undo is
          // already gone, so silence would read as success.
          onPressed: () async {
            try {
              await service.undo(prior);
            } catch (e, stackTrace) {
              LoggerService.forClass(BulkTagSheet).error(
                'Failed to undo a bulk tag edit',
                error: e,
                stackTrace: stackTrace,
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.tags_bulk_undoFailed),
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
      BulkTagSheet,
    ).error('Failed to edit tags', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.tags_bulk_failed('$e')),
        backgroundColor: errorColor,
      ),
    );
    return BulkActionOutcome.failed;
  }
}

/// The bulk tag editor: one tri-state row per tag (on all; on some, left as
/// is; on none) for every [scope] tag and every tag already on a selected
/// item, an Add button, and Apply behind a confirmation that names every
/// change (#1754).
///
/// Pops the confirmed [MembershipDelta]; any other way out pops null.
class BulkTagSheet extends ConsumerStatefulWidget {
  const BulkTagSheet({
    super.key,
    required this.scope,
    required this.itemIds,
    required this.labels,
    required this.scrollController,
    this.keyPrefix = 'bulkTags',
  });

  final TagScope scope;
  final List<String> itemIds;
  final BulkTagSheetLabels labels;

  /// Prefix of the buttons' keys (`<prefix>_apply` and so on), for tests.
  final String keyPrefix;

  /// Supplied by the enclosing [DraggableScrollableSheet].
  final ScrollController scrollController;

  @override
  ConsumerState<BulkTagSheet> createState() => _BulkTagSheetState();
}

class _BulkTagSheetState extends ConsumerState<BulkTagSheet> {
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
        .read(tagLinkRepositoryProvider(widget.scope))
        .tagCountsFor(widget.itemIds);
    final tags = await ref.read(tagsProvider.future);
    final known = {for (final t in tags) t.id};
    _counts = counts;
    _members = [
      for (final t in tags)
        if (t.appliesTo(widget.scope) || (counts[t.id] ?? 0) > 0)
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
  /// to [BulkTagSheet.scope].
  void _addTags() {
    final l10n = context.l10n;
    var picked = <Tag>[];
    showDialog<void>(
      context: context,
      // The StatefulBuilder wraps the whole dialog, not just its content, so
      // the Browse action in the button row can restage `picked` too.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.tags_bulk_tagsLabel),
          content: TagInputWidget(
            selectedTags: picked,
            onTagsChanged: (tags) => setDialogState(() => picked = tags),
            scope: widget.scope,
          ),
          actions: [
            TextButton(
              // `ctx` is inside the dialog route, so the picker lands on the
              // same (root) navigator and opens above the dialog (#1366).
              onPressed: () => showTagPickerSheet(
                context,
                selected: picked,
                onPicked: (tags) => setDialogState(() => picked = tags),
                scope: widget.scope,
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
    final total = widget.itemIds.length;
    final sections = summarizeBulkMembership([
      (title: l10n.tags_bulk_tagsLabel, delta: _delta, members: _members),
    ]);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tags_bulk_confirmTitle),
        content: SingleChildScrollView(
          child: BulkChangeSummary(
            sections: sections,
            addingHeading: widget.labels.confirmAdding(total),
            removingHeading: widget.labels.confirmRemoving(total),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: ValueKey('${widget.keyPrefix}_confirm'),
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
    final total = widget.itemIds.length;
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
                    title: l10n.tags_bulk_title(total),
                    total: total,
                    labels: BulkMembershipLabels(
                      onAll: l10n.tags_bulk_onAll,
                      onSome: l10n.tags_bulk_onSome,
                      adding: l10n.tags_bulk_adding,
                      removing: l10n.tags_bulk_removing,
                      empty: widget.labels.empty,
                      add: l10n.common_action_add,
                    ),
                    items: _members,
                    counts: _counts,
                    onAdd: _addTags,
                    onChanged: (delta) => setState(() => _delta = delta),
                    ensureOn: _ensureOn,
                    // Every tag of the scope is listed, so a tag on none of
                    // the items is an offer and starts unchecked.
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
                      key: ValueKey('${widget.keyPrefix}_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_action_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: ValueKey('${widget.keyPrefix}_apply'),
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
