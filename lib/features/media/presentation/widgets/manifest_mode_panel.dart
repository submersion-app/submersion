// Manifest mode panel inside the URL tab.
//
// The panel renders one of four bodies based on the [ManifestTabState]
// discriminated union:
//
// - [ManifestTabIdle]            -> hint text "Paste a manifest URL to begin."
// - [ManifestTabFetching]        -> CircularProgressIndicator
// - [ManifestTabError]           -> red error message
// - [ManifestTabShowingPreview]  -> [ManifestPreviewPane] + Subscribe
//                                   checkbox + poll-interval dropdown +
//                                   Import button
// - [ManifestTabCommitting]      -> CircularProgressIndicator
//
// The Import button resolves the entries, opens the import review so each
// one gets a dive or a site, then creates a `MediaSubscription` row and
// inserts the decided entries under it. The schema's unique partial index
// `(subscription_id, entry_key)` requires a non-null subscriptionId, so
// with Subscribe OFF a sentinel `isActive: false` row is created per
// one-shot import (and torn down on Undo); with Subscribe ON the row is
// active and polled. Both paths show a snackbar with an Undo action that
// deletes the inserted [MediaItem] rows AND, for one-shot imports, the
// sentinel subscription.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/services/network_import_targets.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
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

  /// Triggered by the Import button on the preview pane. Resolves the
  /// entries, lets the user give each one a dive or a site in
  /// [MediaImportReviewPage], and only then creates the subscription row
  /// and inserts the decided entries. Drives the notifier through
  /// `ShowingPreview -> Committing -> Idle` around all of that.
  ///
  /// Captures the [ScaffoldMessenger] and [Navigator] before the await so
  /// the snackbar and the pushed review fire correctly across the async
  /// gap, and bails out via `mounted` if the user navigated away.
  Future<void> _commit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    String? committedSubscriptionId;
    List<String>? committedMediaIds;
    bool subscriptionPersisted = false;

    await ref
        .read(manifestTabProvider.notifier)
        .commit(
          onCommit: (preview) async {
            final pipeline = ref.read(networkFetchPipelineProvider);
            final resolved = await pipeline.resolveManifestEntries(
              preview.result.entries,
            );
            if (!mounted) return;
            await navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => MediaImportReviewPage(
                  candidates: candidatesFor(resolved),
                  onConfirm: (targets) async {
                    final subRepo = ref.read(
                      manifestSubscriptionRepositoryProvider,
                    );
                    final format =
                        preview.formatOverride ?? preview.result.format;
                    // Every commit creates a subscription row because the
                    // pipeline keys manifest rows on it (the partial unique
                    // index on `(subscription_id, entry_key)`). Subscribe off
                    // means an inert `isActive: false` row that Undo removes.
                    final created = await subRepo.createSubscription(
                      manifestUrl: preview.url,
                      format: format,
                      pollIntervalSeconds: preview.pollIntervalSeconds,
                      isActive: preview.subscribe,
                    );
                    subscriptionPersisted = preview.subscribe;
                    committedSubscriptionId = created.id;
                    final requests = requestsFromReview(resolved, targets);
                    final ids = await pipeline.insertResolved(
                      requests,
                      subscriptionId: created.id,
                    );
                    committedMediaIds = ids;
                    return ImportReviewResult(
                      linked: ids.length,
                      skipped: resolved.length - requests.length,
                    );
                  },
                ),
              ),
            );
          },
        );

    if (!mounted) return;
    final ids = committedMediaIds;
    final subId = committedSubscriptionId;
    if (ids == null || subId == null) {
      // Cancelled in the review, or the fetch failed (the notifier state
      // machine has already moved to [ManifestTabError] and the panel body
      // renders the message): nothing was created.
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
    await ref
        .read(mediaDeletionCoordinatorProvider)
        .deleteMultipleMedia(mediaIds);
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
