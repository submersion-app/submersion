part of 'buddy_detail_page.dart';

/// The buddy page's header in the list pane.
extension _BuddyDetailPaneHeader on _BuddyDetailContent {
  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            photo: buddy.photo,
            initials: buddy.initials,
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buddy.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (buddyCertificationLineL10n(
                      buddy,
                      context.l10n,
                      catalog: context.certificationCatalog,
                    ) !=
                    null)
                  Text(
                    buddyCertificationLineL10n(
                      buddy,
                      context.l10n,
                      catalog: context.certificationCatalog,
                    )!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (host != null) host!.lockButton(buddy, compact: true),
          BuddyFavoriteButton(
            buddyId: buddy.id,
            isFavorite: buddy.isFavorite,
            iconSize: 20,
            readOnly: host != null,
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: context.l10n.common_action_edit,
            onPressed: host != null
                ? () => host!.editController.unlock(buddy)
                : () {
                    final state = GoRouterState.of(context);
                    context.go(
                      '${state.uri.path}?selected=${buddy.id}&mode=edit',
                    );
                  },
          ),
          _menu(context, ref, compact: true),
        ],
      ),
    );
  }
}
