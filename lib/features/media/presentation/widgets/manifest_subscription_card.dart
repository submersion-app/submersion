// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 7. Deviations from the plan code:
//
// - The plan's [ManifestSubscription] is presumed to expose a `copyWith`
//   method (line 2293 explicitly notes the agent should adapt). The real
//   Phase 3b entity is an [Equatable] value type with no `copyWith`. We
//   call the repository's narrowly-scoped methods directly:
//     - `setActive(id, bool)` for the toggle.
//     - `deleteById(id)` for Delete.
//     - `updateUrlAndDisplayName(id, manifestUrl: ..., displayName: ...)`
//       — a Phase 3c seam added alongside this card (mirrors Task 6's
//       `NetworkCredentialsService.updateDisplayName` precedent).
// - The plan's "Poll now" calls `poller.pollNow(subscriptionId)` and
//   surfaces an `added / changed / removed` count in a snackbar. The
//   real [SubscriptionPoller] has no per-subscription entry point; we
//   add `pollNow(subscriptionId, now)` returning `Future<bool>` as a
//   second Phase 3c seam. The card surfaces a single
//   "Poll triggered" / "Poll failed" toast — the per-row state row is
//   what carries the success/failure detail (next poll-time, last error)
//   and the [manifestSubscriptionsProvider] re-renders after invalidation.
// - `subscriptionPollerProvider` lives in `media_resolver_providers.dart`,
//   not `network_sources_providers.dart`. Imported from there.
// - `clock.now()` is used for the test-friendly "now" in poll calls so
//   `package:fake_async` can drive the timing in future integration
//   tests. The current widget tests don't exercise `fakeAsync`; they
//   only check that the call happens.
// - Subtitle composition mirrors Task 6's `_relativeFromMillis` style:
//   short, human-readable, joined with a separator. We surface
//   `lastError` (when set) so the user can see "why isn't this polling?"
//   without drilling further.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// Settings -> Network Sources -> Manifest subscriptions card.
///
/// Lists `media_subscriptions` rows joined with their per-device
/// `media_subscription_state`. Per row:
/// - Display name (or manifest URL if no display name) + format chip
/// - Last poll status / next poll time / last error (subtitle)
/// - `isActive` toggle (trailing switch)
/// - Action menu (Poll now, Edit, Delete)
class ManifestSubscriptionCard extends ConsumerWidget {
  const ManifestSubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubs = ref.watch(manifestSubscriptionsProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                // TODO(media): l10n
                Text(
                  'Manifest subscriptions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
          ),
          asyncSubs.when(
            data: (subs) => subs.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.feed_outlined),
                    // TODO(media): l10n
                    title: Text('No manifest subscriptions'),
                    subtitle: Text(
                      'Subscribe to an Atom/RSS, JSON, or CSV manifest from '
                      'the URL tab to keep your library in sync.',
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < subs.length; i++) ...[
                        _SubscriptionTile(sub: subs[i]),
                        if (i < subs.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
            loading: () => const ListTile(
              // TODO(media): l10n
              title: Text('Loading subscriptions...'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              // TODO(media): l10n
              title: const Text('Could not load subscriptions'),
              subtitle: Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile({required this.sub});
  final ManifestSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.feed_outlined),
      title: Row(
        children: [
          Expanded(
            child: Text(
              sub.displayName ?? sub.manifestUrl,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _FormatChip(format: sub.format),
        ],
      ),
      subtitle: Text(_subtitle()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: sub.isActive,
            onChanged: (v) => _setActive(context, ref, v),
          ),
          PopupMenuButton<_SubAction>(
            // TODO(media): l10n
            tooltip: 'More',
            onSelected: (a) => _handle(context, ref, a),
            itemBuilder: (_) => const [
              // TODO(media): l10n
              PopupMenuItem(value: _SubAction.poll, child: Text('Poll now')),
              // TODO(media): l10n
              PopupMenuItem(value: _SubAction.edit, child: Text('Edit')),
              // TODO(media): l10n
              PopupMenuItem(value: _SubAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (sub.lastError != null && sub.lastError!.isNotEmpty) {
      // TODO(media): l10n
      parts.add('Last error: ${sub.lastError}');
    } else if (sub.lastPolledAt != null) {
      // TODO(media): l10n
      parts.add('Last polled ${_relative(sub.lastPolledAt!)}');
    } else {
      // TODO(media): l10n
      parts.add('Never polled');
    }
    if (sub.nextPollAt != null) {
      // TODO(media): l10n
      parts.add('Next ${_nextRelative(sub.nextPollAt!)}');
    }
    return parts.join('  -  ');
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool v) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(manifestSubscriptionRepositoryProvider);
    try {
      await repo.setActive(sub.id, v);
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Could not update: $e')),
      );
    }
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _SubAction action,
  ) async {
    switch (action) {
      case _SubAction.poll:
        await _pollNow(context, ref);
      case _SubAction.edit:
        await _showEditDialog(context, ref);
      case _SubAction.delete:
        await _confirmAndDelete(context, ref);
    }
  }

  Future<void> _pollNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final poller = ref.read(subscriptionPollerProvider);
    final label = sub.displayName ?? sub.manifestUrl;
    try {
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Polling $label...')),
      );
      final polled = await poller.pollNow(sub.id, clock.now().toUtc());
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
      messenger.showSnackBar(
        SnackBar(
          // TODO(media): l10n
          content: Text(polled ? 'Polled $label' : 'Subscription not found'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Poll failed: $e')),
      );
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // TODO(media): l10n
        title: Text('Delete ${sub.displayName ?? sub.manifestUrl}?'),
        // TODO(media): l10n
        content: const Text(
          'Removes the subscription. Already-imported entries will remain '
          '(you can clean them up via the orphan queue).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            // TODO(media): l10n
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(manifestSubscriptionRepositoryProvider).deleteById(sub.id);
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final urlController = TextEditingController(text: sub.manifestUrl);
    final nameController = TextEditingController(text: sub.displayName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // TODO(media): l10n
        title: const Text('Edit subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                // TODO(media): l10n
                labelText: 'Manifest URL',
              ),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                // TODO(media): l10n
                labelText: 'Display name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            // TODO(media): l10n
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(manifestSubscriptionRepositoryProvider)
          .updateUrlAndDisplayName(
            sub.id,
            manifestUrl: urlController.text,
            displayName: nameController.text.isEmpty
                ? null
                : nameController.text,
          );
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.format});
  final ManifestFormat format;
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(format.name.toUpperCase()),
      visualDensity: VisualDensity.compact,
      labelStyle: Theme.of(context).textTheme.labelSmall,
    );
  }
}

enum _SubAction { poll, edit, delete }

/// Short relative-past formatter ("5m ago", "2h ago"). Matches the format
/// produced by Task 6's `_relativeFromMillis` helper. Uses `clock.now()`
/// so `package:fake_async` can drive the time in tests.
// TODO(media): l10n — relative-time strings need translation + plural rules.
String _relative(DateTime when) {
  final diff = clock.now().toUtc().difference(when.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

/// Short relative-future formatter ("in 5m", "in 2h"). Returns "overdue"
/// when the target is in the past — the scheduler will pick that row up
/// on the next periodic cycle.
// TODO(media): l10n — relative-time strings need translation + plural rules.
String _nextRelative(DateTime when) {
  final diff = when.toUtc().difference(clock.now().toUtc());
  if (diff.isNegative) return 'overdue';
  if (diff.inMinutes < 1) return 'in <1m';
  if (diff.inHours < 1) return 'in ${diff.inMinutes}m';
  if (diff.inDays < 1) return 'in ${diff.inHours}h';
  return 'in ${diff.inDays}d';
}
