part of 'site_detail_page.dart';

/// Below this pane width, at the normal text size, the pane header has no
/// room for a library's text button beside the site's name (issue #4928):
/// Connect on this device moves to the top of the site's menu, and a
/// reader's Suggest changes shows as an icon with its words as the tooltip.
/// It grows with the diver's text size, as the button's words do.
const double _kSitePaneCompactHeaderWidth = 560;

/// The pane menu's value for Connect on this device.
const String _kConnectHereAction = 'connectHere';

/// The site page's top bars: the full page's locked bar and the list
/// pane's header row (issue #4527, phase 2).
extension _SiteDetailBars on _SiteDetailContentState {
  /// The full page's locked top bar. [offered] is whether the lock shows;
  /// History sits beside the lock where the bar has room, else first in
  /// the menu, as on a dive.
  PreferredSizeWidget _lockedBar(
    BuildContext context,
    DiveSite site, {
    required bool offered,
  }) {
    final historyInBar =
        MediaQuery.sizeOf(context).width >= kRecordCompactBarWidth;
    return AppBar(
      title: Text(site.name),
      actions: [
        if (site.hasCoordinates)
          IconButton(
            icon: const Icon(Icons.terrain),
            tooltip: context.l10n.dive3d_seascape_siteTitle,
            onPressed: () =>
                _showFullscreenMap(context, ref, site, initialScape3d: true),
          ),
        if (historyInBar)
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: context.l10n.changeLog_history,
            onPressed: () => openChangeLogHistory(
              context,
              rootTable: 'dive_sites',
              rootId: site.id,
            ),
          ),
        if (offered) _unlockControl(site),
        ..._libraryButtons(context, ref, site),
        _siteMenu(context, site, historyItem: !historyInBar),
      ],
    );
  }

  /// The full page's menu, on the locked bar and on the unlocked one, as a
  /// dive's: the whole-record actions run from it while unlocked with
  /// nothing to save.
  Widget _siteMenu(
    BuildContext context,
    DiveSite site, {
    required bool historyItem,
    MenuController? controller,
  }) {
    final ownership = _watchOwnership(ref, site);
    return SiteDetailPropertiesMenu(
      controller: controller ?? _displayOptionsMenu,
      child: PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, ref, value, site),
        itemBuilder: (context) => _siteMenuItems(
          context,
          ref,
          site,
          historyItem: historyItem,
          ownership: ownership,
        ),
      ),
    );
  }

  /// The site's menu entries. [historyItem] puts History first, where the
  /// bar has no room for it; [ownership] adds Delete, Unhide or Remove.
  /// The whole-record ones are disabled under a caption saying why while
  /// they cannot run.
  List<PopupMenuEntry<String>> _siteMenuItems(
    BuildContext context,
    WidgetRef ref,
    DiveSite site, {
    required bool historyItem,
    _SiteOwnership? ownership,
  }) {
    final block = siteOperationBlock;
    final enabled = block == null || block == RecordOperationBlock.none;
    final reason = recordOperationReason(context.l10n, block, plural: true);
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String title, {
      Color? color,
    }) => PopupMenuItem(
      value: value,
      enabled: enabled,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: color == null ? null : TextStyle(color: color),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
    final own = ownership;
    final library = _libraryMenuItems(
      context,
      ref,
      site,
      operationsEnabled: enabled,
    );
    final owned = [
      if (own != null)
        // Delete for the owner; another profile only removes the shared
        // site from itself (issue #2594); neither while the profile is
        // unknown (issue #2682).
        if (own.canDestroy == true)
          item(
            'delete',
            Icons.delete,
            context.l10n.diveSites_detail_deleteMenu_label,
            color: Colors.red,
          )
        else if (own.hidden)
          item(
            'unhide',
            Icons.visibility_outlined,
            context.l10n.sharedItems_unhideAction,
          )
        else if (own.canDestroy == false && own.reachesHere)
          item(
            'remove',
            Icons.visibility_off_outlined,
            context.l10n.sharedItems_removeAction,
          ),
    ];
    // The reason only over record actions the menu shows.
    final offersRecordAction =
        owned.isNotEmpty ||
        library.any(
          (e) =>
              e is PopupMenuItem<String> &&
              kSiteRecordActions.contains(e.value),
        );
    return [
      if (historyItem)
        changeLogHistoryMenuItem(
          context,
          rootTable: 'dive_sites',
          rootId: site.id,
        ),
      openInConnectionsMenuItem(context),
      duplicateSiteMenuItem(context),
      displayOptionsMenuItem(context, 'displayOptions'),
      if (reason != null && offersRecordAction)
        recordOperationCaption<String>(context, reason),
      ...library,
      ...owned,
    ];
  }

  /// The lock for an editor; for a shared site library's reader, "Suggest
  /// changes", which opens a reader's sitting (issue #4527, plan 5).
  /// [iconOnly] shows Suggest changes as an icon, for a narrow pane.
  Widget _unlockControl(
    DiveSite site, {
    bool compact = false,
    bool iconOnly = false,
  }) {
    if (!_suggestsNow(watch: true)) return lockButton(site, compact: compact);
    if (iconOnly) {
      return IconButton(
        key: const ValueKey('site_suggest_unlock'),
        icon: const Icon(Icons.rate_review_outlined, size: 20),
        tooltip: context.l10n.sharedLibrary_suggest_title,
        onPressed: () => editController.unlock(site),
      );
    }
    return TextButton.icon(
      key: const ValueKey('site_suggest_unlock'),
      icon: Icon(Icons.rate_review_outlined, size: compact ? 18 : null),
      label: Text(context.l10n.sharedLibrary_suggest_title),
      onPressed: () => editController.unlock(site),
    );
  }

  /// The list pane's header row. [offered] is whether the lock shows;
  /// while the site is unlocked the shared pane header (Cancel, the title,
  /// the menu and Save) is laid over it ([RecordPaneRow]).
  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    DiveSite site, {
    bool offered = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final ownership = _watchOwnership(ref, site);
    // One per row, each with its own controller: while unlocked both rows
    // are mounted, the locked one unseen under the other. [connectFirst]
    // puts Connect on this device at the top, for a narrow pane.
    Widget menuWith(MenuController controller, {bool connectFirst = false}) =>
        SiteDetailPropertiesMenu(
          controller: controller,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == _kConnectHereAction) {
                _connectHere(context, ref, site);
                return;
              }
              _handleMenuAction(context, ref, value, site);
            },
            itemBuilder: (context) => [
              if (connectFirst) ...[
                PopupMenuItem(
                  value: _kConnectHereAction,
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(context.l10n.sharedLibrary_site_connectHere),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
              ],
              ..._siteMenuItems(
                context,
                ref,
                site,
                historyItem: true,
                ownership: ownership,
              ),
            ],
          ),
        );

    final textTheme = Theme.of(context).textTheme;
    final libraryButtons = _libraryButtons(context, ref, site);
    final locked = LayoutBuilder(
      builder: (context, constraints) {
        // How much the buttons' words grow: a platform's nonlinear scaler
        // grows a label far more than it would a 560 px "size".
        final labelSize = textTheme.labelLarge?.fontSize ?? 14;
        final growth =
            MediaQuery.textScalerOf(context).scale(labelSize) / labelSize;
        final compact =
            constraints.maxWidth < _kSitePaneCompactHeaderWidth * growth;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (widget.onClose != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onClose,
                  tooltip: context.l10n.common_action_back,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      site.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (site.locationString.isNotEmpty)
                      Text(
                        site.locationString,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (site.hasCoordinates)
                IconButton(
                  icon: const Icon(Icons.terrain, size: 20),
                  tooltip: context.l10n.dive3d_seascape_siteTitle,
                  onPressed: () => _showFullscreenMap(
                    context,
                    ref,
                    site,
                    initialScape3d: true,
                  ),
                ),
              if (offered)
                _unlockControl(site, compact: true, iconOnly: compact),
              if (!compact) ...libraryButtons,
              menuWith(
                _displayOptionsMenu,
                connectFirst: compact && libraryButtons.isNotEmpty,
              ),
            ],
          ),
        );
      },
    );
    return RecordPaneRow(
      locked: locked,
      unlocked: isSittingOpen
          ? editingPaneRow(
              widget.site,
              // A new site has nothing for a menu to act on yet.
              menu: isCreating
                  ? const SizedBox.shrink()
                  : menuWith(_unlockedDisplayOptionsMenu),
            )
          : null,
    );
  }
}
