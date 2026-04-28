// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 15 (initial scaffold) + Task 16 (NetworkThumbnail swap).
//
// Mirrors `FileReviewPane` (Phase 2) in shape, but the URL tab's
// [UrlTabState] (Task 14) does not yet expose a `match` field — staged
// URL lines are plain strings without per-dive grouping until a future
// task adds that pipeline. For now the pane renders a per-line preview
// list (one card per draft line), reserving the per-dive
// `ExpansionTile` shape for the real implementation in Phase 3b/3c.
//
// Task 16 swapped the original [Container]+spinner placeholder for
// [NetworkThumbnail] so the leading art slot now resolves the actual
// remote bytes (with `Authorization` headers from
// `NetworkCredentialsService` when needed). For invalid URL lines we
// keep the neutral surface placeholder because [Uri.parse] would still
// succeed for some malformed inputs and `NetworkThumbnail` would fire
// off a doomed request — letting the validator gate the network call
// avoids burning auth lookups on lines the user is still typing.
import 'package:flutter/material.dart';

import 'package:submersion/features/media/data/utils/url_validator.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_thumbnail.dart';

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
      // Valid URLs paint via [NetworkThumbnail] (resolves auth headers
      // from `NetworkCredentialsService` and falls back to
      // `UnavailableMediaPlaceholder` on error). Invalid lines render a
      // neutral surface tile so we don't fire a doomed network request
      // for in-progress text.
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ok
            ? NetworkThumbnail(url: line, size: 48)
            : Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.link_off,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
