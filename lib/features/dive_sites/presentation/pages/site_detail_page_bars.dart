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
            onPressed: () => context.push('/sites/${widget.siteId}/edit'),
          ),
        ..._libraryButtons(context, ref, site),
        SiteDetailPropertiesMenu(
          controller: _displayOptionsMenu,
          child: PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value, site),
            itemBuilder: (context) => [
              if (!historyInBar)
                changeLogHistoryMenuItem(
                  context,
                  rootTable: 'dive_sites',
                  rootId: site.id,
                ),
              openInConnectionsMenuItem(context),
              duplicateSiteMenuItem(context),
              displayOptionsMenuItem(context, 'displayOptions'),
              ..._libraryMenuItems(context, ref, site),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    DiveSite site,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    // Watched, as the trip page does, so the menu follows the profile once
    // it has loaded (issue #2594); null until then (issue #2682).
    final canDestroy = canDestroySharedItemOnceKnown(
      ref.watch(validatedCurrentDiverIdProvider),
      ownerId: site.diverId,
      isLibrarySite: site.isLibrarySite,
    );
    // A site this profile already removed offers Unhide (issue #2679).
    final hidden = watchHiddenHere(
      ref,
      SharedItemKind.site,
      site.id,
      canDestroy: canDestroy != false,
    );
    // Remove only while the site reaches this profile (issue #2151).
    final reachesHere = watchReachesHere(
      ref,
      SharedItemKind.site,
      site.id,
      libraryId: site.sharedLibraryId,
    );

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
          SiteDetailPropertiesMenu(
            controller: _displayOptionsMenu,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) =>
                  _handleMenuAction(context, ref, value, site),
              itemBuilder: (context) => [
                changeLogHistoryMenuItem(
                  context,
                  rootTable: 'dive_sites',
                  rootId: site.id,
                ),
                openInConnectionsMenuItem(context),
                duplicateSiteMenuItem(context),
                displayOptionsMenuItem(context, 'displayOptions'),
                ..._libraryMenuItems(context, ref, site),
                // Delete for the owner; another profile only removes the
                // shared site from itself (issue #2594); neither while the
                // profile is unknown (issue #2682).
                if (canDestroy == true)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: Text(
                        context.l10n.diveSites_detail_deleteMenu_label,
                        style: const TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else if (hidden)
                  PopupMenuItem(
                    value: 'unhide',
                    child: ListTile(
                      leading: const Icon(Icons.visibility_outlined),
                      title: Text(context.l10n.sharedItems_unhideAction),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else if (canDestroy == false && reachesHere)
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.visibility_off_outlined),
                      title: Text(context.l10n.sharedItems_removeAction),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
