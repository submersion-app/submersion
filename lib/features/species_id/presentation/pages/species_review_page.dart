import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';
import 'package:submersion/features/species_id/presentation/providers/species_review_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_review_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/discard_dialog.dart';

/// Species to review (issue #4727): what the app tagged on its own and what
/// it only suggests, for one dive or the whole log. Every decision is held
/// here until Save, which writes them as one History entry; Cancel or
/// leaving with decisions asks first. No unlock is needed: the page is a
/// deliberate mode with its own Save, like bulk edit.
class SpeciesReviewPage extends ConsumerStatefulWidget {
  const SpeciesReviewPage({super.key, required this.scope});

  final ReviewScope scope;

  @override
  ConsumerState<SpeciesReviewPage> createState() => _SpeciesReviewPageState();
}

class _SpeciesReviewPageState extends ConsumerState<SpeciesReviewPage> {
  var _edits = SpeciesReviewEdits.none;
  final _expanded = <String>{};
  var _saving = false;

  bool get _dirty => !_edits.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(speciesReviewProvider(widget.scope));
    final groups = groupsAsync.value ?? const <ReviewGroup>[];
    final heading = widget.scope is DiveReviewScope && groups.isNotEmpty
        ? _heading(l10n, groups.first)
        : null;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await showDiscardDialog(context) && context.mounted) {
          setState(() => _edits = SpeciesReviewEdits.none);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: _dirty ? 96 : null,
          leading: _dirty
              ? TextButton(
                  key: const ValueKey('species_review_cancel'),
                  onPressed: _saving ? null : () => Navigator.maybePop(context),
                  child: Text(l10n.common_action_cancel),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.speciesReview_title),
              if (heading != null)
                Text(heading, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('species_review_save'),
              onPressed: _dirty && !_saving ? () => _save(groups) : null,
              child: Text(l10n.common_action_save),
            ),
          ],
        ),
        body: groupsAsync.isLoading && groupsAsync.value == null
            ? const Center(child: CircularProgressIndicator())
            : groups.isEmpty
            ? Center(child: Text(l10n.speciesReview_nothing))
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final group in groups) ..._group(context, group),
                ],
              ),
      ),
    );
  }

  List<Widget> _group(BuildContext context, ReviewGroup group) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    return [
      if (widget.scope is LogReviewScope)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            _heading(l10n, group),
            style: theme.textTheme.titleMedium,
          ),
        ),
      if (group.tagged.isNotEmpty) ...[
        section(l10n.speciesReview_tagged),
        for (final row in group.tagged) _row(row),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              key: ValueKey('species_review_confirm_all_${group.diveId}'),
              onPressed: group.tagged.every(_edits.isRowSettled)
                  ? null
                  : () => setState(() {
                      for (final row in group.tagged) {
                        _edits = _edits.decideRow(row, keep: true);
                      }
                    }),
              child: Text(l10n.speciesReview_confirmAll),
            ),
          ),
        ),
      ],
      if (group.suggested.isNotEmpty) ...[
        section(l10n.speciesReview_suggested),
        for (final row in group.suggested) _row(row),
      ],
    ];
  }

  Widget _row(ReviewRow row) {
    final expandKey = '${row.key}|${row.items.first.media.id}';
    return SpeciesReviewRowTile(
      row: row,
      edits: _edits,
      expanded: _expanded.contains(expandKey),
      onToggle: () => setState(() {
        if (!_expanded.remove(expandKey)) _expanded.add(expandKey);
      }),
      onRow: (keep) => setState(() {
        _edits = keep == null
            ? _edits.undoRow(row)
            : _edits.decideRow(row, keep: keep);
      }),
      onItem: (item, keep) => setState(() {
        _edits = keep == null
            ? _edits.undoItem(row, item)
            : _edits.decideItem(row, item, keep: keep);
      }),
      onOpen: (item) => _open(row, item),
    );
  }

  Future<void> _open(ReviewRow row, ReviewItem item) async {
    if (_dirty && !await showDiscardDialog(context)) return;
    if (!mounted) return;
    setState(() => _edits = SpeciesReviewEdits.none);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MediaViewerPage(
          mediaList: [for (final i in row.items) i.media],
          initialMediaId: item.media.id,
          showGoToDive: true,
        ),
      ),
    );
  }

  Future<void> _save(List<ReviewGroup> groups) async {
    setState(() => _saving = true);
    try {
      await ref.read(speciesReviewSaverProvider).save(_edits, groups);
      if (mounted) setState(() => _edits = SpeciesReviewEdits.none);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _heading(AppLocalizations l10n, ReviewGroup group) =>
      switch (group.kind) {
        ReviewGroupKind.sitePhotos => l10n.speciesReview_sitePhotos,
        ReviewGroupKind.otherPhotos => l10n.speciesReview_otherPhotos,
        ReviewGroupKind.dive => [
          if (group.diveNumber != null)
            l10n.speciesReview_diveNumber(group.diveNumber!),
          ?group.siteName,
        ].join(', '),
      };
}
