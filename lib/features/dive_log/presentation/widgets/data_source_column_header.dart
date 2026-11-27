part of 'data_sources_section.dart';

// ---------------------------------------------------------------------------
// Per-source actions, menu and column header
// ---------------------------------------------------------------------------

/// What the user can do with one source, already gated by the section
/// (Split and Remove only on a multi-source dive, Remove not for a source
/// that shares its computer). Null means the action is not offered.
class _SourceActions {
  const _SourceActions({
    this.onSetPrimary,
    this.onSplit,
    this.onRemove,
    this.onTap,
  });

  final VoidCallback? onSetPrimary;
  final VoidCallback? onSplit;
  final VoidCallback? onRemove;

  /// Views the source (tap-to-view).
  final VoidCallback? onTap;

  bool canSetPrimary(DiveDataSource source) =>
      !source.isPrimary && onSetPrimary != null;

  /// Whether [source]'s menu would have an entry. A lone primary source has
  /// none, and an icon over an empty menu opens nothing (#2974).
  bool hasMenuFor(DiveDataSource source) =>
      canSetPrimary(source) || onSplit != null || onRemove != null;
}

/// The computer's model beneath its friendly name, but only when it adds
/// information: an un-renamed computer, whose name defaults to the model,
/// gets no subtitle.
String? _modelSubtitle(DiveDataSource source) =>
    source.computerName != null &&
        source.computerModel != null &&
        source.computerModel != source.computerName
    ? source.computerModel
    : null;

enum _SourceMenuAction { setPrimary, split, remove }

/// The per-source menu: Set as primary, Split and Remove, listed disabled
/// under [operationReason] when the page withholds them (#4527). Build it
/// only when [_SourceActions.hasMenuFor] is true.
class _SourceMenuButton extends StatelessWidget {
  const _SourceMenuButton({
    required this.source,
    required this.actions,
    required this.operationReason,
    this.compact = false,
  });

  final DiveDataSource source;
  final _SourceActions actions;
  final String? operationReason;

  /// Compact like the section header menu, so a column header holding it
  /// still fits two sources across a phone. The card keeps the standard
  /// size.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = operationReason == null;
    return PopupMenuButton<_SourceMenuAction>(
      icon: const Icon(Icons.more_vert, size: 20),
      style: compact
          ? IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            )
          : null,
      onSelected: (action) {
        switch (action) {
          case _SourceMenuAction.setPrimary:
            actions.onSetPrimary?.call();
          case _SourceMenuAction.split:
            actions.onSplit?.call();
          case _SourceMenuAction.remove:
            actions.onRemove?.call();
        }
      },
      itemBuilder: (context) => [
        if (operationReason case final reason?)
          recordOperationCaption<_SourceMenuAction>(context, reason),
        if (actions.canSetPrimary(source))
          _menuItem(
            _SourceMenuAction.setPrimary,
            Icons.star_outline,
            l10n.diveLog_sources_menu_setPrimary,
            enabled: enabled,
          ),
        if (actions.onSplit != null)
          _menuItem(
            _SourceMenuAction.split,
            Icons.call_split,
            l10n.diveLog_sources_menu_split,
            enabled: enabled,
          ),
        if (actions.onRemove != null)
          _menuItem(
            _SourceMenuAction.remove,
            Icons.delete_outline,
            l10n.diveLog_sources_menu_remove,
            enabled: enabled,
          ),
      ],
    );
  }
}

/// A source's column header in the comparison table, and its one entry on a
/// multi-source dive (#5081): the name (bold when primary), the model when
/// the computer was renamed, the Primary and Viewing chips, and the
/// per-source menu.
class _SourceColumnHeader extends StatelessWidget {
  const _SourceColumnHeader({
    required this.source,
    required this.isViewing,
    required this.actions,
    required this.operationReason,
  });

  final DiveDataSource source;
  final bool isViewing;
  final _SourceActions actions;
  final String? operationReason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.labelLarge;
    final model = _modelSubtitle(source);

    final chips = <Widget>[
      if (source.isPrimary)
        _Badge(
          label: l10n.diveLog_computerSource_badge_primary,
          color: colorScheme.primaryContainer,
        ),
      if (isViewing)
        _Badge(
          label: l10n.diveLog_sources_badge_viewing,
          color: colorScheme.tertiaryContainer,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                // Seats the name's first line level with the menu icon.
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  resolveSourceName(source, _labelsOf(context)),
                  style: source.isPrimary
                      ? headerStyle?.copyWith(fontWeight: FontWeight.bold)
                      : headerStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (actions.hasMenuFor(source))
              _SourceMenuButton(
                source: source,
                actions: actions,
                operationReason: operationReason,
                compact: true,
              ),
          ],
        ),
        if (model != null)
          Text(
            model,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 4, runSpacing: 4, children: chips),
        ],
      ],
    );
  }
}
