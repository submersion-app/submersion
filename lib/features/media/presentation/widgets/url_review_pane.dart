// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 15. Mirrors `FileReviewPane` (Phase 2) in shape, but the URL
// tab's [UrlTabState] (Task 14) does not yet expose a `match` field —
// staged URL lines are plain strings without per-dive grouping until a
// future task adds that pipeline. For now the pane renders a per-line
// preview list (one card per draft line), reserving the per-dive
// `ExpansionTile` shape for the real implementation in Phase 3b/3c.
//
// `NetworkThumbnail` (Task 16) is not in the tree yet, so the leading
// art slot is a neutral [Container] placeholder. Items whose remote
// metadata has not been verified yet (i.e. the import is still resolving
// `Last-Modified` / EXIF in the background) display a small spinner —
// `lastVerifiedAt == null` is the criterion the plan calls out, but
// during the staged-draft phase no row has been created yet, so every
// line is treated as "pending verification" until commit lands.
import 'package:flutter/material.dart';

import 'package:submersion/features/media/data/utils/url_validator.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// Review pane shown above the "Add" button in the URL tab.
///
/// Stateless — the parent [UrlTab] watches [urlTabNotifierProvider] and
/// passes the latest [UrlTabState] in. Mutations flow through the
/// notifier, not this widget.
class UrlReviewPane extends StatelessWidget {
  const UrlReviewPane({super.key, required this.state});

  final UrlTabState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = state.draftLines.where((l) => l.trim().isNotEmpty).toList();
    if (draft.isEmpty) {
      return Center(
        child: Text(
          // TODO(media): l10n
          'Paste URLs above or use Add URL to start.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    // TODO(media): l10n, pluralization
    final summary = '${draft.length} URL${draft.length == 1 ? '' : 's'} staged';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(summary, style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: draft.length,
            itemBuilder: (_, i) => _UrlReviewRow(line: draft[i]),
          ),
        ),
      ],
    );
  }
}

class _UrlReviewRow extends StatelessWidget {
  const _UrlReviewRow({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final result = UrlValidator.parse(line);
    final ok = result is UrlValidationOk;
    final theme = Theme.of(context);
    return ListTile(
      // TODO(Task 16): swap for NetworkThumbnail once
      // `lib/features/media/presentation/widgets/network_thumbnail.dart`
      // lands. Until then we render a neutral placeholder + a small
      // spinner because every draft line is unverified pre-commit
      // (`lastVerifiedAt == null`).
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              width: 48,
              height: 48,
              child: Icon(
                Icons.link,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
      title: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
      // TODO(media): l10n. Validation errors are shown inline next to the
      // multi-line draft field by [UrlTab]; we only surface a generic
      // "Invalid URL" / "Pending verification" hint here so the per-line
      // error message is not duplicated in the widget tree.
      subtitle: ok
          ? const Text('Pending verification')
          : Text(
              'Invalid URL',
              style: TextStyle(color: theme.colorScheme.error),
            ),
    );
  }
}
