part of 'site_detail_page.dart';

/// The site page's top bars: the full page's locked bar and the list
/// pane's header row (issue #4527, phase 2).
extension _SiteDetailBars on _SiteDetailContentState {
  /// The full page's locked top bar. [offered] is whether the lock shows;
  /// on a page that [hosts] editing, History sits beside the lock where the
  /// bar has room, else first in the menu, as on a dive.
  PreferredSizeWidget _lockedBar(
    BuildContext context,
    DiveSite site, {
    required bool offered,
    required bool hosts,
  }) {
    final historyInBar =
        hosts && MediaQuery.sizeOf(context).width >= kRecordCompactBarWidth;
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
        if (offered) lockButton(site),
        // Only on the locked bar: an open sitting's bar replaces this one,
        // so the old form, which would save over the sitting through a
        // child route no leave check sees, is never offered over it.
        if (_canEditSite(ref, site))
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.diveSites_detail_editTooltip,
            // On a page that offers the lock the old address opens this page
            // unlocked, so Edit unlocks it in place, not over a copy.
            onPressed: offered
                ? () => editController.unlock(site)
                : () => context.push('/sites/${widget.siteId}/edit'),
          ),
        ..._libraryButtons(context, ref, site),
        _siteMenu(context, site, historyItem: !historyInBar, hosts: hosts),
      ],
    );
  }

  /// The full page's menu, on the locked bar and, on a page that [hosts]
  /// editing, on the unlocked one too, as a dive's: the whole-record
  /// actions run from it while unlocked with nothing to save. Today's page
  /// offers Delete, Unhide and Remove only once it hosts editing.
  Widget _siteMenu(
    BuildContext context,
    DiveSite site, {
    required bool historyItem,
    required bool hosts,
  }) {
    final ownership = hosts ? _watchOwnership(ref, site) : null;
    return SiteDetailPropertiesMenu(
      controller: _displayOptionsMenu,
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
      if (reason != null) recordOperationCaption<String>(context, reason),
      ..._libraryMenuItems(context, ref, site, operationsEnabled: enabled),
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
    final menu = SiteDetailPropertiesMenu(
      controller: _displayOptionsMenu,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (value) => _handleMenuAction(context, ref, value, site),
        itemBuilder: (context) => _siteMenuItems(
          context,
          ref,
          site,
          historyItem: true,
          ownership: ownership,
        ),
      ),
    );

    final locked = Container(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (site.locationString.isNotEmpty)
                  Text(
                    site.locationString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              onPressed: () =>
                  _showFullscreenMap(context, ref, site, initialScape3d: true),
            ),
          if (offered) lockButton(site, compact: true),
          if (_canEditSite(ref, site))
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: context.l10n.diveSites_detail_editTooltipShort,
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                if (currentPath.startsWith('/dives')) {
                  // If we're on the /dives path, keep it and just add mode=edit and site parameter.
                  // The MasterDetailScaffold in DiveListPage will handle showing the site edit panel
                  // because we'll have both ?site=... and &mode=edit in the query params.
                  final params = Map<String, String>.from(
                    state.uri.queryParameters,
                  );
                  params['mode'] = 'edit';
                  // We do NOT change 'selected' here, because 'selected' is used by DiveListPage's
                  // MasterDetailScaffold to identify the DIVE. If we change it to the siteId,
                  // the scaffold will try to find a dive with that siteId and fail.
                  params['site'] = widget.siteId;
                  // In place, not push: a pushed copy of the Dives list would
                  // stay behind after save, with a back arrow of its own (#3292).
                  context.goInPlace(
                    Uri(path: currentPath, queryParameters: params).toString(),
                  );
                } else {
                  // Default to /sites path for site-related navigation if not on /dives.
                  context.go('/sites?selected=${widget.siteId}&mode=edit');
                }
              },
            ),
          ..._libraryButtons(context, ref, site),
          menu,
        ],
      ),
    );
    return RecordPaneRow(
      locked: locked,
      unlocked: isSittingOpen ? editingPaneRow(widget.site, menu: menu) : null,
    );
  }
}
