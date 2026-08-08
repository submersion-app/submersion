import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/providers/media_inbox_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Unlinked inbox: media attached to no dive or site, each with an
/// auto-match suggestion chip (confident or ambiguous) and manual actions
/// (link to dive, link to site, keep in library).
class MediaUnlinkedInboxView extends ConsumerWidget {
  const MediaUnlinkedInboxView({super.key});

  Future<void> _linkToDive(WidgetRef ref, String mediaId, String diveId) async {
    await ref.read(mediaRepositoryProvider).reassignMediaToDive([
      mediaId,
    ], diveId);
  }

  Future<void> _pickAndLinkDive(
    BuildContext context,
    WidgetRef ref,
    String mediaId,
  ) async {
    final diveId = await showDivePickerSheet(context);
    if (diveId == null) return;
    await _linkToDive(ref, mediaId, diveId);
  }

  Future<void> _pickAndLinkSite(
    BuildContext context,
    WidgetRef ref,
    String mediaId,
  ) async {
    final sites = ref.read(sitesProvider).value ?? const [];
    final siteId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final site in sites)
              ListTile(
                title: Text(site.name),
                onTap: () => Navigator.of(sheetContext).pop(site.id),
              ),
          ],
        ),
      ),
    );
    if (siteId == null) return;
    await ref.read(mediaRepositoryProvider).linkMediaToSite([mediaId], siteId);
  }

  Future<void> _chooseAmbiguous(
    BuildContext context,
    WidgetRef ref,
    String mediaId,
    List<String> candidateDiveIds,
  ) async {
    final diveId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final id in candidateDiveIds)
              _AmbiguousDiveTile(
                diveId: id,
                onTap: () => Navigator.of(sheetContext).pop(id),
              ),
          ],
        ),
      ),
    );
    if (diveId == null) return;
    await _linkToDive(ref, mediaId, diveId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unlinkedInboxProvider);

    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.entries.isEmpty) {
      return Center(child: Text(context.l10n.media_inbox_empty));
    }

    final locale = Localizations.localeOf(context).toString();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (state.hasMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 400) {
          ref.read(unlinkedInboxProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: state.entries.length,
        itemBuilder: (context, index) {
          final entry = state.entries[index];
          final item = entry.item;
          final suggestion = ref.watch(inboxSuggestionProvider(item.id)).value;

          return ListTile(
            leading: SizedBox(
              width: 56,
              height: 56,
              child: MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: const Size(112, 112),
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              item.originalFilename ??
                  DateFormat.yMMMd(locale).format(item.takenAt.toLocal()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              DateFormat.yMMMd(locale).add_jm().format(item.takenAt.toLocal()),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (suggestion != null &&
                    suggestion.match.kind == TimestampMatchKind.confident)
                  ActionChip(
                    avatar: const Icon(Icons.link, size: 18),
                    // Unnumbered dives have no "#N" to show; fall back to the
                    // generic label rather than rendering "Link to #0".
                    label: Text(
                      suggestion.diveNumber == null
                          ? context.l10n.media_inbox_linkToDive
                          : context.l10n.media_inbox_linkChip(
                              suggestion.diveNumber!,
                            ),
                    ),
                    onPressed: () =>
                        _linkToDive(ref, item.id, suggestion.match.diveId!),
                  )
                else if (suggestion != null &&
                    suggestion.match.kind == TimestampMatchKind.ambiguous)
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 18),
                    label: Text(context.l10n.media_inbox_chooseDive),
                    onPressed: () => _chooseAmbiguous(
                      context,
                      ref,
                      item.id,
                      suggestion.match.candidateDiveIds,
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    switch (action) {
                      case 'linkDive':
                        await _pickAndLinkDive(context, ref, item.id);
                      case 'linkSite':
                        await _pickAndLinkSite(context, ref, item.id);
                      case 'keep':
                        await ref
                            .read(mediaRepositoryProvider)
                            .markRetainedInLibrary([item.id]);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'linkDive',
                      child: Text(context.l10n.media_inbox_linkToDive),
                    ),
                    PopupMenuItem(
                      value: 'linkSite',
                      child: Text(context.l10n.media_inbox_linkToSite),
                    ),
                    PopupMenuItem(
                      value: 'keep',
                      child: Text(context.l10n.media_inbox_keep),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Candidate row in the ambiguous chooser: dive number, name/site, date.
class _AmbiguousDiveTile extends ConsumerWidget {
  const _AmbiguousDiveTile({required this.diveId, required this.onTap});

  final String diveId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).value;
    final locale = Localizations.localeOf(context).toString();
    final label = dive == null
        ? diveId
        : [
            if (dive.diveNumber != null) '#${dive.diveNumber}',
            if (dive.name != null && dive.name!.isNotEmpty)
              dive.name!
            else if (dive.site?.name != null)
              dive.site!.name,
          ].join(' ');
    return ListTile(
      title: Text(label),
      subtitle: dive == null
          ? null
          : Text(DateFormat.yMMMd(locale).format(dive.dateTime)),
      onTap: onTap,
    );
  }
}
