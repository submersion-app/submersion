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

import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/manifest_entry_adoption.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_import_targets.dart';
import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_preview_pane.dart';
import 'package:submersion/features/media/presentation/widgets/poll_interval_options.dart';
import 'package:submersion/features/media/presentation/widgets/synology_password_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Standard poll-interval choices surfaced in the dropdown, shared with the
/// subscription's edit dialog.
const List<PollIntervalOption> _kPollIntervals = kPollIntervalOptions;

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
    final current = ref.read(manifestTabProvider);
    if (current is ManifestTabShowingPreview &&
        SynologyShareLink.tryParseShareLink(Uri.parse(current.url)) != null) {
      return _commitShare();
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    String? committedSubscriptionId;
    List<String>? committedMediaIds;
    var adopted = 0;
    var reused = false;
    bool subscriptionPersisted = false;

    await ref
        .read(manifestTabProvider.notifier)
        .commit(
          onCommit: (preview) async {
            final pipeline = ref.read(networkFetchPipelineProvider);
            final prepared = await _prepareCommit(preview);
            final resolved = await pipeline.resolveManifestEntries(
              prepared.plan.fresh,
            );
            Future<ImportReviewResult> confirm(
              Map<String, MediaAttachTarget> targets,
            ) async {
              final sub = await _subscriptionFor(preview, prepared.existing);
              reused = prepared.existing != null;
              subscriptionPersisted = reused || preview.subscribe;
              committedSubscriptionId = sub.id;
              adopted = await applyManifestAdoption(
                ref.read(mediaRepositoryProvider),
                prepared.plan,
                sub.id,
              );
              final requests = requestsFromReview(resolved, targets);
              final ids = await pipeline.insertResolved(
                requests,
                subscriptionId: sub.id,
              );
              committedMediaIds = ids;
              return ImportReviewResult(
                linked: ids.length,
                skipped: resolved.length - requests.length,
              );
            }

            // Nothing left to review: every entry is already in the
            // subscription or was taken over from a deleted one.
            if (resolved.isEmpty) {
              await confirm(const {});
              return;
            }
            if (!mounted) return;
            await navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => MediaImportReviewPage(
                  candidates: candidatesFor(resolved),
                  onConfirm: confirm,
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
          '${reused ? 'Already subscribed. ' : ''}'
          'Imported ${ids.length} new entr${ids.length == 1 ? 'y' : 'ies'}'
          '${adopted > 0 ? ', took over $adopted already in the library' : ''}',
        ),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          // TODO(media): l10n
          label: 'Undo',
          onPressed: () => _undoCommit(
            mediaIds: ids,
            subscriptionId: subId,
            // Keep the user-created subscription if Subscribe was on; the
            // user explicitly opted in to recurring polling. Only the
            // sentinel one-shot subscription is torn down, and never one
            // that existed before this import.
            deleteSubscription: !subscriptionPersisted,
          ),
        ),
      ),
    );
  }

  /// What an import of [preview] has to do before anything is written: the
  /// subscription that already reads this URL, if any, and how the entries
  /// it does not hold yet split into rows left behind by a deleted
  /// subscription and entries that are new to the library.
  ///
  /// Pasting a feed that is already subscribed must not open a second
  /// subscription: each one keys its rows on its own id, so both would
  /// import every entry and every photo would appear twice.
  Future<({ManifestSubscription? existing, ManifestAdoptionPlan plan})>
  _prepareCommit(ManifestTabShowingPreview preview) async {
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final existing = await ref
        .read(manifestSubscriptionRepositoryProvider)
        .findByManifestUrl(preview.url);
    final pending = existing == null
        ? preview.result.entries
        : await entriesNotYetIn(mediaRepo, existing.id, preview.result.entries);
    final plan = await planManifestAdoption(mediaRepo, pending);
    return (existing: existing, plan: plan);
  }

  /// The subscription an import writes under: the one that already reads
  /// the URL, switched on when this import asked for polling, or a new one.
  ///
  /// Every commit needs a subscription row because the pipeline keys
  /// manifest rows on it (the partial unique index on
  /// `(subscription_id, entry_key)`). Subscribe off means an inert
  /// `isActive: false` row that Undo removes.
  Future<ManifestSubscription> _subscriptionFor(
    ManifestTabShowingPreview preview,
    ManifestSubscription? existing,
  ) async {
    final subRepo = ref.read(manifestSubscriptionRepositoryProvider);
    if (existing != null) {
      if (preview.subscribe && !existing.isActive) {
        await subRepo.setActive(existing.id, true);
      }
      return existing;
    }
    // A shared album is named after the album, so two albums on one NAS
    // can be told apart wherever the app reports on them.
    final title = preview.result.title;
    final isShare =
        SynologyShareLink.tryParseShareLink(Uri.parse(preview.url)) != null;
    return subRepo.createSubscription(
      manifestUrl: preview.url,
      format: preview.formatOverride ?? preview.result.format,
      pollIntervalSeconds: preview.pollIntervalSeconds,
      isActive: preview.subscribe,
      displayName: isShare && title != null && title.isNotEmpty ? title : null,
    );
  }

  /// Imports a Synology Photos share the way its subscription polls it: only
  /// photos with a confident dive match are linked, the rest wait for a
  /// later poll (or a dive that does not exist yet).
  ///
  /// A shared album easily holds hundreds of photos. The review page asks for
  /// one suggestion per row and rebuilds as each arrives, which does not
  /// scale to that, and nobody wants to tick hundreds of rows by hand.
  Future<void> _commitShare() async {
    final messenger = ScaffoldMessenger.of(context);
    String? committedSubscriptionId;
    List<String>? committedMediaIds;
    var skipped = 0;
    var adopted = 0;
    var reused = false;
    var subscribe = false;

    await ref
        .read(manifestTabProvider.notifier)
        .commit(
          onCommit: (preview) async {
            final pipeline = ref.read(networkFetchPipelineProvider);
            final prepared = await _prepareCommit(preview);
            final resolved = await pipeline.resolveManifestEntries(
              prepared.plan.fresh,
            );
            final decided = await requestsForConfidentMatches(
              resolved,
              DiveLinkMatcher(diveRepository: ref.read(diveRepositoryProvider)),
              diverId: ref.read(currentDiverIdProvider),
            );
            final sub = await _subscriptionFor(preview, prepared.existing);
            reused = prepared.existing != null;
            committedSubscriptionId = sub.id;
            subscribe = reused
                ? sub.isActive || preview.subscribe
                : preview.subscribe;
            adopted = await applyManifestAdoption(
              ref.read(mediaRepositoryProvider),
              prepared.plan,
              sub.id,
            );
            committedMediaIds = await pipeline.insertResolved(
              decided.requests,
              subscriptionId: sub.id,
            );
            skipped = decided.skipped;
          },
        );

    if (!mounted) return;
    final ids = committedMediaIds;
    final subId = committedSubscriptionId;
    if (ids == null || subId == null) return;
    messenger.showSnackBar(
      SnackBar(
        // TODO(media): l10n, pluralization
        content: Text(
          '${reused ? 'This album is already subscribed; added what was new. ' : ''}'
          'Linked ${ids.length} new photos to dives'
          '${adopted > 0 ? ', took over $adopted already in the library' : ''}. '
          '$skipped without a matching dive'
          '${subscribe ? ' are checked again on the next poll.' : '.'}',
        ),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(
          // TODO(media): l10n
          label: 'Undo',
          onPressed: () => _undoCommit(
            mediaIds: ids,
            subscriptionId: subId,
            // A subscription that existed before this import is never
            // removed by its Undo.
            deleteSubscription: !reused && !subscribe,
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
      case ManifestTabError(
        :final url,
        :final message,
        :final unauthorized,
        :final detail,
      ):
        final uri = Uri.tryParse(url);
        final share = unauthorized && uri != null
            ? SynologyShareLink.tryParseShareLink(uri)
            : null;
        if (share != null) {
          return _SynologyPasswordForm(url: url, share: share, reason: detail);
        }
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
                          child: Text(option.label(context.l10n)),
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

/// Asks for a Synology Photos share's password when fetching its link was
/// refused, saves it for this share (each share has its own) and fetches
/// again.
class _SynologyPasswordForm extends ConsumerStatefulWidget {
  const _SynologyPasswordForm({
    required this.url,
    required this.share,
    this.reason,
  });

  final String url;
  final SynologyShareLink share;

  /// Why the share refused: no password yet, or a rejected one.
  final String? reason;

  @override
  ConsumerState<_SynologyPasswordForm> createState() =>
      _SynologyPasswordFormState();
}

class _SynologyPasswordFormState extends ConsumerState<_SynologyPasswordForm> {
  final TextEditingController _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.isEmpty || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref
          .read(networkCredentialsServiceProvider)
          .save(
            hostname: NetworkCredentialsService.synologyShareKey(widget.share),
            authType: kSynologyShareAuthType,
            password: password,
            // No display name: the row is named after its album where one
            // reads the share, and a stored label would stay in one language.
          );
      if (!mounted) return;
      // The Saved hosts list reads the store once; show the new row.
      ref.invalidate(savedHostsProvider);
      await ref.read(manifestTabProvider.notifier).fetch(widget.url);
    } catch (e) {
      // A keychain that refuses the write: say so, or the button simply
      // comes back and the share still asks for its password.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_credentials_saveError('$e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.media_sharePassword_needed,
            style: theme.textTheme.bodyMedium,
          ),
          if (widget.reason != null &&
              widget.reason != kSynologyPasswordMissingMessage) ...[
            const SizedBox(height: 4),
            Text(
              localizedPollError(l10n, widget.reason!),
              key: const Key('synologySharePasswordError'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.media_sharePassword_keychainNote,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('synologySharePassword'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.media_sharePassword_title,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('synologySharePasswordSave'),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open),
            label: Text(l10n.media_sharePassword_formSave),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
