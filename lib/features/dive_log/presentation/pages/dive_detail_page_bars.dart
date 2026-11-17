part of 'dive_detail_page.dart';

/// The standalone page's top bar, its overflow menu and the keys that step
/// between dives: moved out of the page to keep it under its line limit.
mixin _DiveDetailPageBars
    on
        ConsumerState<DiveDetailPage>,
        _DiveDetailPageActions,
        _DiveDetailPageExports,
        _DiveDetailPageEditing {
  GlobalKey get _appBarMenuKey;
  MenuController get _displayOptionsMenu;
  void _navigateToDive(String neighborId);

  /// The standalone page's locked top bar. [shown] is the dive the cards
  /// display, which a sitting starts from.
  PreferredSizeWidget _standaloneBar(Dive dive, Dive shown) {
    // Standalone mode: Full Scaffold with AppBar. On a phone-width window
    // the title has no room beside five action icons, so the favorite toggle,
    // the one action that reads as well from a menu, moves into the overflow.
    final compactActions =
        MediaQuery.sizeOf(context).width < _kCompactAppBarWidth;
    final favoriteLabel = dive.isFavorite
        ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
        : context.l10n.diveLog_detail_tooltip_addToFavorites;
    return AppBar(
      // Titled like the desktop pane's header, not "Dive Details" (#4445).
      title: Text(
        diveTitle(context, dive),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        DiveNavButtons(diveId: diveId, onNavigate: _navigateToDive),
        // With editing offered favourite is a field of the header card, so
        // a locked page shows it as a state only, at every width: the menu
        // has no favourite item then (issue #4527).
        if (editingOffered && dive.isFavorite)
          Icon(
            Icons.favorite,
            color: Colors.red,
            semanticLabel: context.l10n.enum_diveField_isFavorite,
          )
        else if (!editingOffered && !compactActions)
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: dive.isFavorite ? Colors.red : null,
            ),
            tooltip: favoriteLabel,
            onPressed: () {
              ref
                  .read(paginatedDiveListProvider.notifier)
                  .toggleFavorite(diveId);
            },
          ),
        if (editingOffered) lockButton(shown),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: context.l10n.diveLog_detail_tooltip_editDive,
          onPressed: () => context.push('/dives/$diveId/edit'),
        ),
        _overflowMenu(
          dive,
          _appBarMenuKey,
          showFavorite: compactActions && !editingOffered,
        ),
      ],
    );
  }

  Widget _overflowMenu(
    Dive dive,
    GlobalKey menuKey, {
    bool showFavorite = false,
  }) {
    return DiveDetailOverflowMenu(
      dive: dive,
      embedded: widget.embedded,
      menuKey: menuKey,
      displayOptions: _displayOptionsMenu,
      showFavorite: showFavorite,
      onSelected: (value, linkedPreDive) =>
          _onMenuSelected(value, dive, linkedPreDive, menuKey),
    );
  }

  void _onMenuSelected(
    String value,
    Dive dive,
    PreDiveSession? linkedPreDive,
    GlobalKey menuKey,
  ) {
    switch (value) {
      case 'toggleFavorite':
        ref.read(paginatedDiveListProvider.notifier).toggleFavorite(diveId);
      case 'displayOptions':
        _displayOptionsMenu.open();
      case 'export':
        _showExportOptions(dive, shareAnchorFrom(menuKey.currentContext));
      case 'reparse':
        _reparseDive(dive);
      case 'resync':
        _resyncDive(dive);
      case 'logNearMiss':
        context.push('/incidents/new?diveId=$diveId');
      case 'markLogged' || 'markComplete':
        _markAsLogged(dive);
      case 'addHeartRate':
        _addHeartRate(dive);
      case 'logForBuddy':
        _logForBuddy(dive);
      case 'linkPreDive':
        _linkPreDiveChecklist(dive);
      case 'unlinkPreDive':
        _unlinkPreDiveChecklist(linkedPreDive!);
      case 'whatIf':
        openWhatIf(context, dive);
      case 'viewInPlanner':
        final planId = ref.read(planForLoggedDiveProvider(dive.id)).value;
        if (planId != null) openSavedPlanInPlanner(context, planId);
      case 'planRepetitive':
        logFailure(
          _planRepetitiveDive(dive),
          _DiveDetailPageState,
          'plan a repetitive dive',
        );
      case 'delete':
        _showDeleteConfirmation();
      case 'open':
        // Open in full-page mode. push (not go) so there's a back button and
        // the pushed page skips the master-detail redirect above instead of
        // bouncing straight back into the pane it was opened from.
        context.push('/dives/$diveId');
    }
  }
}

/// Left/Right arrow-key bindings for previous/next dive around [child]. Up/Down
/// are left untouched so vertical scrolling still works.
///
/// Watches the neighbors itself, so a change to them leaves [child] alone.
class _DiveShortcuts extends ConsumerWidget {
  const _DiveShortcuts({
    required this.diveId,
    required this.onNavigate,
    required this.child,
    this.enabled = true,
  });

  final String diveId;

  /// Off during an editing sitting, when the arrow keys belong to the text
  /// being typed: a binding here would swallow them before a field saw them.
  final bool enabled;
  final void Function(String neighborId) onNavigate;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neighbors = ref.watch(diveNeighborsProvider(diveId));
    return CallbackShortcuts(
      bindings: !enabled
          ? const {}
          : {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                final id = neighbors.previousId;
                if (id != null) onNavigate(id);
              },
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                final id = neighbors.nextId;
                if (id != null) onNavigate(id);
              },
            },
      child: Focus(child: child),
    );
  }
}

/// Below this window width the standalone app bar keeps only the actions
/// that leave room for its title; the rest go into the overflow menu.
const double _kCompactAppBarWidth = 600;
