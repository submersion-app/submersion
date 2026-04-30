// Manifest mode panel inside the URL tab (Phase 3b, Tasks 13-14).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Tasks 13 & 14. The panel renders one of four bodies based on the
// [ManifestTabState] discriminated union:
//
// - [ManifestTabIdle]            -> hint text "Paste a manifest URL to begin."
// - [ManifestTabFetching]        -> CircularProgressIndicator
// - [ManifestTabError]           -> red error message
// - [ManifestTabShowingPreview]  -> [ManifestPreviewPane] + Subscribe
//                                   checkbox + poll-interval dropdown +
//                                   Import button
// - [ManifestTabCommitting]      -> CircularProgressIndicator
//
// Task 14 wires the Import button to a `commit()` flow that:
//   - If Subscribe is OFF: calls
//     [NetworkFetchPipeline.ingestManifestEntries] with an ephemeral
//     subscription row created with `isActive: false`. The schema's
//     unique partial index `(subscription_id, entry_key)` requires a
//     non-null subscriptionId, so a sentinel sub row is created per
//     one-shot import (and torn down on Undo).
//   - If Subscribe is ON: creates a `MediaSubscription` row via
//     [ManifestSubscriptionRepository.createSubscription] (active = true),
//     then ingests the entries with the persisted subscriptionId.
// Both paths show a snackbar with an Undo action that deletes the
// inserted [MediaItem] rows AND the subscription created in this commit.
//
// Plan deviations:
//
// - The plan (lines 3920-3964) routes ingest through
//   `MediaRepository.createMedia` per entry plus a non-existent
//   `pipeline.enqueueManifestEntries(items)`. The actual codebase API is
//   `pipeline.ingestManifestEntries(List<ManifestEntry>, String
//   subscriptionId)`, which already inserts media rows itself. The plan
//   code predates Task 10's API choice; we follow the API.
// - Because the pipeline requires a non-null `subscriptionId`, every
//   commit creates a `MediaSubscriptions` row (see comment above). For
//   one-shot imports the row is `isActive: false` and is deleted by
//   Undo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_preview_pane.dart';

/// Standard poll-interval choices surfaced in the dropdown. The plan's
/// 24-hour default sits at the middle of the list.
const List<_PollIntervalOption> _kPollIntervals = [
  _PollIntervalOption(seconds: 3600, label: '1 hour'),
  _PollIntervalOption(seconds: 21600, label: '6 hours'),
  _PollIntervalOption(seconds: 86400, label: '24 hours'),
  _PollIntervalOption(seconds: 604800, label: '7 days'),
];

class ManifestModePanel extends ConsumerStatefulWidget {
  const ManifestModePanel({super.key});

  @override
  ConsumerState<ManifestModePanel> createState() => _ManifestModePanelState();
}

class _ManifestModePanelState extends ConsumerState<ManifestModePanel> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final notifier = ref.read(manifestTabProvider.notifier);
    await notifier.fetch(_urlController.text);
  }

  /// Triggered by the Import button on the preview pane. Drives the
  /// notifier through `ShowingPreview -> Committing -> Idle` while
  /// (optionally) creating a `MediaSubscription` row and ingesting the
  /// manifest entries via [NetworkFetchPipeline.ingestManifestEntries].
  ///
  /// Captures the [ScaffoldMessenger] before the await so the snackbar
  /// fires correctly across the async gap, and bails out via
  /// `context.mounted` if the user navigated away mid-import.
  Future<void> _commit() async {
    final messenger = ScaffoldMessenger.of(context);
    String? committedSubscriptionId;
    List<String>? committedMediaIds;
    bool subscriptionPersisted = false;

    await ref
        .read(manifestTabProvider.notifier)
        .commit(
          onCommit: (preview) async {
            final subRepo = ref.read(manifestSubscriptionRepositoryProvider);
            final pipeline = ref.read(networkFetchPipelineProvider);
            final format = preview.formatOverride ?? preview.result.format;
            // Every commit creates a subscription row because the pipeline
            // requires a non-null subscriptionId (the partial unique index
            // on `(subscription_id, entry_key)` is keyed off it). When the
            // user did NOT subscribe, the row is created `isActive: false`
            // so no future poll cycle will pick it up, and Undo deletes
            // the row entirely.
            final created = await subRepo.createSubscription(
              manifestUrl: preview.url,
              format: format,
              pollIntervalSeconds: preview.pollIntervalSeconds,
              isActive: preview.subscribe,
            );
            subscriptionPersisted = preview.subscribe;
            committedSubscriptionId = created.id;
            final ids = await pipeline.ingestManifestEntries(
              preview.result.entries,
              created.id,
            );
            committedMediaIds = ids;
          },
        );

    if (!mounted) return;
    if (!context.mounted) return;
    final ids = committedMediaIds;
    final subId = committedSubscriptionId;
    if (ids == null || subId == null) {
      // Commit failed — the notifier state machine has already moved to
      // [ManifestTabError]; the panel body renders the message. Nothing
      // else to do.
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        // TODO(media): l10n, pluralization
        content: Text(
          'Imported ${ids.length} entr${ids.length == 1 ? 'y' : 'ies'}',
        ),
        action: SnackBarAction(
          // TODO(media): l10n
          label: 'Undo',
          onPressed: () => _undoCommit(
            mediaIds: ids,
            subscriptionId: subId,
            // Keep the user-created subscription if Subscribe was on; the
            // user explicitly opted in to recurring polling. Only the
            // sentinel one-shot subscription is torn down.
            deleteSubscription: !subscriptionPersisted,
          ),
        ),
      ),
    );
  }

  /// Reverses a prior [_commit]: deletes each inserted [MediaItem] row,
  /// and (for one-shot imports only) deletes the sentinel subscription
  /// row. When the user opted into a real subscription (`Subscribe` ON),
  /// the subscription stays — only the imported entries are removed.
  Future<void> _undoCommit({
    required List<String> mediaIds,
    required String subscriptionId,
    required bool deleteSubscription,
  }) async {
    final mediaRepo = ref.read(mediaRepositoryProvider);
    for (final id in mediaIds) {
      await mediaRepo.deleteMedia(id);
    }
    if (deleteSubscription) {
      await ref
          .read(manifestSubscriptionRepositoryProvider)
          .deleteById(subscriptionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manifestTabProvider);
    final isFetching = state is ManifestTabFetching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isFetching ? null : _fetch(),
          decoration: const InputDecoration(
            // TODO(media): l10n
            labelText: 'Manifest URL',
            // TODO(media): l10n
            hintText: 'https://example.com/manifest.json',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.cloud_download),
            // TODO(media): l10n
            label: const Text('Fetch'),
            onPressed: isFetching ? null : _fetch,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _Body(state: state, onImport: _commit),
        ),
      ],
    );
  }
}

/// State-driven body of the panel — separated out so the `switch` over the
/// sealed [ManifestTabState] reads top-to-bottom in one place.
class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.onImport});

  final ManifestTabState state;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    switch (state) {
      case ManifestTabIdle():
        // TODO(media): l10n
        return const Align(
          alignment: Alignment.topLeft,
          child: Text('Paste a manifest URL to begin.'),
        );
      case ManifestTabFetching():
        return const Center(child: CircularProgressIndicator());
      case ManifestTabError(:final message):
        return Align(
          alignment: Alignment.topLeft,
          // TODO(media): l10n
          child: Text(
            'Fetch failed: $message',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        );
      case ManifestTabShowingPreview(
        :final result,
        :final formatOverride,
        :final subscribe,
        :final pollIntervalSeconds,
      ):
        final entryCount = result.entries.length;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ManifestPreviewPane(
                result: result,
                formatOverride: formatOverride,
                onFormatOverrideChanged: (format) {
                  ref
                      .read(manifestTabProvider.notifier)
                      .changeFormatOverride(format);
                },
              ),
              const SizedBox(height: 16),
              _SubscribeRow(
                subscribe: subscribe,
                pollIntervalSeconds: pollIntervalSeconds,
                onSubscribeChanged: (value) {
                  ref.read(manifestTabProvider.notifier).setSubscribe(value);
                },
                onPollIntervalChanged: (seconds) {
                  ref
                      .read(manifestTabProvider.notifier)
                      .setPollInterval(seconds);
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  icon: const Icon(Icons.cloud_upload),
                  // TODO(media): l10n, pluralization
                  label: Text(
                    'Import $entryCount entr${entryCount == 1 ? 'y' : 'ies'}',
                  ),
                  onPressed: entryCount == 0 ? null : onImport,
                ),
              ),
            ],
          ),
        );
      case ManifestTabCommitting():
        return const Center(child: CircularProgressIndicator());
    }
  }
}

/// Subscribe checkbox + (conditionally rendered) poll-interval dropdown.
///
/// Task 13: these inputs are UI placeholders that toggle state on the
/// notifier; Task 14 wires actual subscription persistence on Import.
class _SubscribeRow extends StatelessWidget {
  const _SubscribeRow({
    required this.subscribe,
    required this.pollIntervalSeconds,
    required this.onSubscribeChanged,
    required this.onPollIntervalChanged,
  });

  final bool subscribe;
  final int pollIntervalSeconds;
  final ValueChanged<bool> onSubscribeChanged;
  final ValueChanged<int> onPollIntervalChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: subscribe,
              onChanged: (value) => onSubscribeChanged(value ?? false),
            ),
            // TODO(media): l10n
            const Expanded(child: Text('Subscribe to updates')),
          ],
        ),
        if (subscribe) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                // TODO(media): l10n
                Text(
                  'Poll every:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _resolvedSelection(pollIntervalSeconds),
                  onChanged: (value) {
                    if (value != null) onPollIntervalChanged(value);
                  },
                  items: _kPollIntervals
                      .map(
                        (option) => DropdownMenuItem<int>(
                          value: option.seconds,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Map the persisted seconds value to the closest dropdown option so
  /// arbitrary stored values still pick a sensible item. Defaults to
  /// the 24-hour middle option when nothing matches.
  int _resolvedSelection(int seconds) {
    for (final option in _kPollIntervals) {
      if (option.seconds == seconds) return option.seconds;
    }
    return 86400;
  }
}

class _PollIntervalOption {
  const _PollIntervalOption({required this.seconds, required this.label});

  final int seconds;
  final String label;
}
