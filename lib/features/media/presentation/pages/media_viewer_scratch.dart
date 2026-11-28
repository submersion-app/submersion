part of 'media_viewer_page.dart';

/// The viewer over files the diver has not kept: the Identify viewer
/// (issue #5122). See [ViewerScratch].
extension _ViewerScratchMode on _MediaViewerPageState {
  /// The sitting that holds the species tagged on the file on screen. Its
  /// own, never saved: Keep reads it.
  EditSession<PhotoRecord>? _scratchSitting() {
    final items = _pageableMedia;
    if (items.isEmpty) return null;
    final item = items[_currentIndex.clamp(0, items.length - 1)];
    return _scratchSittings.putIfAbsent(
      item.id,
      () => EditSession(
        PhotoRecord(item: item, species: const [], people: const []),
      ),
    );
  }

  /// The species tagged on each file not kept yet.
  ScratchTags _heldScratchTags() => {
    for (final MapEntry(:key, :value) in _scratchSittings.entries)
      if (!_scratchKept.contains(key)) key: value.working.species,
  };

  /// Whether the diver tagged a species on a file not kept: leaving loses it.
  bool get _scratchHasUnkeptChoices => _scratchSittings.entries.any(
    (e) => !_scratchKept.contains(e.key) && e.value.isDirty,
  );

  /// Asks before leaving when that loses species the diver chose.
  Future<bool> _scratchLeave() async {
    if (!_scratchHasUnkeptChoices) return true;
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.media_identify_leaveTitle),
        content: Text(l10n.media_identify_leaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            key: const ValueKey('media_identify_leave'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.media_identify_leave),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  /// The system Back asks too, as the close button does.
  Widget _scratchPopScope({required Widget child}) {
    if (widget.scratch == null) return child;
    return PopScope(
      canPop: !_scratchHasUnkeptChoices,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _scratchLeave() && mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }

  Future<void> _keepFromBanner(MediaItem current) async {
    final kept = await widget.scratch!.onKeep(
      context,
      current,
      _heldScratchTags(),
    );
    if (!mounted || kept.isEmpty) return;
    _markScratchKept(kept);
  }

  /// "Not in your library", with Keep, over a file not kept; a line saying
  /// so once it is.
  Widget _scratchBanner(BuildContext context, MediaItem current) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final kept = _scratchKept.contains(current.id);
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
      child: Material(
        key: const ValueKey('media_identify_banner'),
        color: kept ? scheme.secondaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            children: [
              Icon(
                kept ? Icons.check_circle_outline : Icons.info_outline,
                size: 18,
                color: kept
                    ? scheme.onSecondaryContainer
                    : scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kept
                      ? l10n.media_identify_kept
                      : l10n.media_identify_notKeptBanner,
                  style: TextStyle(
                    color: kept
                        ? scheme.onSecondaryContainer
                        : scheme.onTertiaryContainer,
                  ),
                ),
              ),
              if (!kept)
                TextButton(
                  key: const ValueKey('media_identify_keep'),
                  onPressed: () => unawaited(_keepFromBanner(current)),
                  child: Text(l10n.media_identify_keep),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
