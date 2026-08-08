import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/providers/media_inbox_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Post-import batch confirmation (Media section Phase 4): one screen with
/// every confident auto-match pre-checked; confirming links the checked
/// items grouped by dive. Everything else stays in the Unlinked inbox.
class MediaImportLinkPage extends ConsumerStatefulWidget {
  const MediaImportLinkPage({super.key, required this.mediaIds});

  final List<String> mediaIds;

  @override
  ConsumerState<MediaImportLinkPage> createState() =>
      _MediaImportLinkPageState();
}

class _MediaImportLinkPageState extends ConsumerState<MediaImportLinkPage> {
  /// Ids the user has UNchecked (default state is checked-when-confident,
  /// so tracking removals keeps the initial build side-effect free).
  final Set<String> _unchecked = {};

  bool _isChecked(String id, InboxSuggestion? suggestion) =>
      suggestion?.match.kind == TimestampMatchKind.confident &&
      !_unchecked.contains(id);

  Future<void> _confirm(Map<String, InboxSuggestion> suggestions) async {
    // Group checked ids by their suggested dive so the sync-safe reassign
    // runs once per dive.
    final byDive = <String, List<String>>{};
    for (final id in widget.mediaIds) {
      final suggestion = suggestions[id];
      if (!_isChecked(id, suggestion)) continue;
      final diveId = suggestion!.match.diveId;
      if (diveId == null) continue;
      byDive.putIfAbsent(diveId, () => []).add(id);
    }

    final repo = ref.read(mediaRepositoryProvider);
    var linked = 0;
    for (final MapEntry(:key, :value) in byDive.entries) {
      await repo.reassignMediaToDive(value, key);
      linked += value.length;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.media_import_linkedResult(linked))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = <String, InboxSuggestion>{
      for (final id in widget.mediaIds)
        id: ?ref.watch(inboxSuggestionProvider(id)).value,
    };
    final checkedCount = widget.mediaIds
        .where((id) => _isChecked(id, suggestions[id]))
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.media_import_linkTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.mediaIds.length,
              itemBuilder: (context, index) {
                final id = widget.mediaIds[index];
                final media = ref.watch(mediaByIdProvider(id)).value;
                final suggestion = suggestions[id];
                final title = media?.originalFilename ?? id;
                final confident =
                    suggestion?.match.kind == TimestampMatchKind.confident;

                if (!confident) {
                  return ListTile(
                    enabled: false,
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(context.l10n.media_import_staysUnlinked),
                  );
                }
                return CheckboxListTile(
                  value: _isChecked(id, suggestion),
                  onChanged: (_) => setState(() {
                    if (!_unchecked.remove(id)) _unchecked.add(id);
                  }),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    context.l10n.media_inbox_linkChip(
                      suggestion?.diveNumber ?? 0,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: checkedCount == 0
                    ? null
                    : () => _confirm(suggestions),
                child: Text(
                  context.l10n.media_import_linkConfirm(checkedCount),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
