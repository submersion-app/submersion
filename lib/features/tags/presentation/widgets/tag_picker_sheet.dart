import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing tags the diver has used before, so tagging stays
/// consistent without having to remember earlier spellings (#1171).
///
/// Mirrors the equipment picker's placement and chrome, but multi-select:
/// tags are cheap to add in batches, so the sheet accumulates ticks and
/// reports them in a single [onTagsPicked] call.
///
/// Tags already on the dive are omitted entirely -- every row in the list is
/// an addition, which is what lets the confirm button count ticks.
///
/// [scope] says what is being tagged (issues #1765, #1942): the sheet lists
/// the tags offered in that scope first, most used there first, each with
/// its count in that scope. The diver's other tags follow under "Other
/// tags", and picking one also offers it in [scope] (issue #4406). Typing a
/// name no tag has offers to create it.
class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedTagIds,
    required this.onTagsPicked,
    this.scope = TagScope.dives,
  });

  /// Supplied by the enclosing [DraggableScrollableSheet] so dragging the
  /// list also resizes the sheet.
  final ScrollController scrollController;

  /// Tags already attached, filtered out of the list.
  final Set<String> selectedTagIds;

  /// Called with the ticked tags, most-used first.
  final void Function(List<Tag> tags) onTagsPicked;

  /// Whose tags these are: dive, site or equipment tags.
  final TagScope scope;

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final _searchController = TextEditingController();
  final _pickedIds = <String>{};
  String _query = '';

  /// True while picks are widened or a tag is created, so a second tap
  /// cannot report the same tags twice.
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String tagId) {
    setState(() {
      if (!_pickedIds.remove(tagId)) _pickedIds.add(tagId);
    });
  }

  /// Every tag in the order this sheet lists it: this scope's tags, "tags
  /// you use most" first, then the diver's other tags (issue #4406).
  ///
  /// The provider already orders by dive count, then each later scope's
  /// count, then name: exactly right for dives. A tag used only for sites
  /// ("to try") is not one of a dive's own tags, nor a dive-only tag one of
  /// a site's (issue #1765); from any other scope this scope's tags are
  /// ordered by their use here instead. Tags from other scopes keep the
  /// provider's order: picking one offers it here as well, so a diver who
  /// tagged dives and sites can reuse those tags on a photo. The sort is
  /// stable, so ties keep the provider's order.
  List<TagStatistic> _ordered(List<TagStatistic> stats) {
    final scope = widget.scope;
    final inScope = [
      for (final stat in stats)
        if (stat.tag.appliesTo(scope)) stat,
    ];
    if (scope != TagScope.dives) {
      mergeSort(inScope, compare: (a, b) => b.count(scope) - a.count(scope));
    }
    return [
      ...inScope,
      for (final stat in stats)
        if (!stat.tag.appliesTo(scope)) stat,
    ];
  }

  /// Picked tags in the order the sheet lists them rather than the order
  /// they happened to be ticked in.
  List<Tag> _pickedFrom(List<TagStatistic> ordered) => [
    for (final stat in ordered)
      if (_pickedIds.contains(stat.tag.id)) stat.tag,
  ];

  /// Reports the tags [pick] returns, first offering in this scope any that
  /// came from another scope, so a tag linked here is always one offered
  /// here (issue #1765).
  Future<void> _report(Future<List<Tag>> Function() pick) async {
    if (_busy) return;
    setState(() => _busy = true);
    final scope = widget.scope;
    try {
      final picked = await pick();
      final borrowed = [
        for (final tag in picked)
          if (!tag.appliesTo(scope)) tag.id,
      ];
      // The tag list and statistics reload on their own when tags change.
      if (borrowed.isNotEmpty) {
        await ref.read(tagRepositoryProvider).widenScope(borrowed, scope);
      }
      widget.onTagsPicked([
        for (final tag in picked)
          tag.appliesTo(scope)
              ? tag
              : tag.copyWith(scopes: {...tag.scopes, scope}),
      ]);
    } catch (e, stackTrace) {
      LoggerService.forClass(
        TagPickerSheet,
      ).error('Failed to add tags', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.common_error_tryAgain)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates a tag called [name] for this scope and reports it together
  /// with the ticked tags. getOrCreateTag reuses a tag of the same name
  /// rather than making a second one, should one appear meanwhile.
  void _create(String name, List<TagStatistic> ordered) => _report(() async {
    final tag = await ref
        .read(tagListNotifierProvider.notifier)
        .getOrCreateTag(
          name,
          colorHex:
              TagColors.predefined[widget.selectedTagIds.length %
                  TagColors.predefined.length],
          scope: widget.scope,
        );
    return [
      for (final picked in _pickedFrom(ordered))
        if (picked.id != tag.id) picked,
      tag,
    ];
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final statsAsync = ref.watch(tagStatisticsProvider).whenData(_ordered);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.tags_picker_title, style: theme.textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_action_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.tags_manage_searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: statsAsync.when(
            data: (ordered) => _buildList(context, ordered),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.tags_picker_errorLoading(error.toString()),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _pickedIds.isEmpty || _busy
                  ? null
                  : () => _report(
                      () async =>
                          _pickedFrom(statsAsync.valueOrNull ?? const []),
                    ),
              child: Text(l10n.tags_picker_addCount(_pickedIds.length)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<TagStatistic> ordered) {
    final l10n = context.l10n;
    final scope = widget.scope;
    final available = ordered
        .where((stat) => !widget.selectedTagIds.contains(stat.tag.id))
        .toList();

    final name = _query.trim();
    final query = name.toLowerCase();
    final visible = query.isEmpty
        ? available
        : available
              .where((stat) => stat.tag.name.toLowerCase().contains(query))
              .toList();

    // The empty state tells a diver to type a tag's name, so typing one the
    // diver has no tag for offers to create it. The match is the one
    // getOrCreateTag makes: trimmed, ignoring case.
    final canCreate =
        query.isNotEmpty &&
        !ordered.any((stat) => stat.tag.name.trim().toLowerCase() == query);

    if (visible.isEmpty && !canCreate) {
      return _EmptyState(
        icon: ordered.isEmpty ? Icons.label_outline : Icons.search_off,
        message: ordered.isEmpty
            ? l10n.tags_picker_empty
            : available.isEmpty
            ? l10n.tags_picker_allAdded
            : l10n.tags_picker_noMatches,
      );
    }

    final inScope = [
      for (final stat in visible)
        if (stat.tag.appliesTo(scope)) stat,
    ];
    final others = [
      for (final stat in visible)
        if (!stat.tag.appliesTo(scope)) stat,
    ];

    final rows = <WidgetBuilder>[
      if (canCreate)
        (context) => ListTile(
          key: const ValueKey('tag_picker_create'),
          leading: const Icon(Icons.add),
          title: Text(l10n.tags_action_createNamed(name)),
          onTap: _busy ? null : () => _create(name, ordered),
        ),
      for (final stat in inScope)
        (context) => _tile(
          stat,
          subtitle: tagScopeCount(l10n, scope, stat.count(scope)),
        ),
      if (others.isNotEmpty)
        (context) => _SectionHeader(l10n.tags_picker_otherTags),
      for (final stat in others)
        (context) => _tile(
          stat,
          subtitle: l10n.tags_manage_rowScopes(tagScopeNames(l10n, stat.tag)),
        ),
    ];

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index](context),
    );
  }

  Widget _tile(TagStatistic stat, {required String subtitle}) =>
      CheckboxListTile(
        value: _pickedIds.contains(stat.tag.id),
        onChanged: (_) => _toggle(stat.tag.id),
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: CircleAvatar(radius: 12, backgroundColor: stat.tag.color),
        title: Text(stat.tag.name),
        subtitle: Text(subtitle),
      );
}

/// Opens the [TagPickerSheet] over [selected] and reports the merged list
/// (existing plus newly picked) through [onPicked]. Shared by the dive and
/// site edit pages, so tags are browsed the same way on both.
///
/// [host] is the context the sheet is pushed from, so it decides which
/// navigator owns the picker; it defaults to [context]. A caller whose
/// Browse action lives inside a dialog must pass that dialog's context:
/// `showDialog` defaults to the root navigator while `showModalBottomSheet`
/// defaults to the nearest one, which under the app's `ShellRoute` is the
/// shell navigator sitting *below* the dialog. Pushed from the page, the
/// picker would open behind the dialog with the dialog's barrier eating
/// every tap (#1366).
void showTagPickerSheet(
  BuildContext context, {
  required List<Tag> selected,
  required ValueChanged<List<Tag>> onPicked,
  TagScope scope = TagScope.dives,
  BuildContext? host,
}) {
  showModalBottomSheet<void>(
    context: host ?? context,
    isScrollControlled: true,
    useSafeArea: true,
    // A modal sheet does not make room for the keyboard by itself; without
    // this the search field's results and the Add button sit under it.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => TagPickerSheet(
          scrollController: scrollController,
          selectedTagIds: selected.map((t) => t.id).toSet(),
          scope: scope,
          onTagsPicked: (tags) {
            // The sheet already excludes selected tags, but guard anyway so
            // a stale list can never produce a duplicate chip.
            final additions = tags.where(
              (tag) => !selected.any((t) => t.id == tag.id),
            );
            if (additions.isNotEmpty) onPicked([...selected, ...additions]);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    ),
  );
}

/// The heading over the Other tags section.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
