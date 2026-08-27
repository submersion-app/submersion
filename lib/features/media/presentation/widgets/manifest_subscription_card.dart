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
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.media_manifest_cardTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          asyncSubs.when(
            data: (subs) => subs.isEmpty
                ? ListTile(
                    leading: const Icon(Icons.feed_outlined),
                    title: Text(context.l10n.media_manifest_emptyTitle),
                    subtitle: Text(context.l10n.media_manifest_emptySubtitle),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < subs.length; i++) ...[
                        _SubscriptionTile(sub: subs[i]),
                        if (i < subs.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
            loading: () =>
                ListTile(title: Text(context.l10n.media_manifest_loading)),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.l10n.media_manifest_loadError),
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
      subtitle: Text(_subtitle(context.l10n)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: sub.isActive,
            onChanged: (v) => _setActive(context, ref, v),
          ),
          PopupMenuButton<_SubAction>(
            tooltip: context.l10n.common_action_more,
            onSelected: (a) => _handle(context, ref, a),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SubAction.poll,
                child: Text(context.l10n.media_manifest_actionPollNow),
              ),
              PopupMenuItem(
                value: _SubAction.edit,
                child: Text(context.l10n.common_action_edit),
              ),
              PopupMenuItem(
                value: _SubAction.delete,
                child: Text(context.l10n.common_action_delete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[];
    if (sub.lastError != null && sub.lastError!.isNotEmpty) {
      parts.add(l10n.media_manifest_lastError('${sub.lastError}'));
    } else if (sub.lastPolledAt != null) {
      parts.add(
        l10n.media_manifest_lastPolled(_relative(l10n, sub.lastPolledAt!)),
      );
    } else {
      parts.add(l10n.media_manifest_neverPolled);
    }
    if (sub.nextPollAt != null) {
      parts.add(
        l10n.media_manifest_nextPoll(_nextRelative(l10n, sub.nextPollAt!)),
      );
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
        SnackBar(content: Text(context.l10n.media_manifest_updateError('$e'))),
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
    final l10n = context.l10n;
    try {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_manifest_polling(label))),
      );
      final polled = await poller.pollNow(sub.id, clock.now().toUtc());
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            polled
                ? l10n.media_manifest_polled(label)
                : l10n.media_manifest_notFound,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_manifest_pollError('$e'))),
      );
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.media_manifest_deleteTitle(
            sub.displayName ?? sub.manifestUrl,
          ),
        ),
        content: Text(dialogContext.l10n.media_manifest_deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.common_action_delete),
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
        SnackBar(content: Text(context.l10n.media_manifest_deleteError('$e'))),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final urlController = TextEditingController(text: sub.manifestUrl);
    final nameController = TextEditingController(text: sub.displayName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.media_manifest_editTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: dialogContext.l10n.media_manifest_urlLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: dialogContext.l10n.common_label_displayName,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.common_action_save),
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
        SnackBar(content: Text(context.l10n.media_manifest_saveError('$e'))),
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
String _relative(AppLocalizations l10n, DateTime when) {
  final diff = clock.now().toUtc().difference(when.toUtc());
  if (diff.inMinutes < 1) return l10n.common_relativeTime_justNow;
  if (diff.inHours < 1) {
    return l10n.common_relativeTime_minutesAgo(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.common_relativeTime_hoursAgo(diff.inHours);
  }
  if (diff.inDays < 30) {
    return l10n.common_relativeTime_daysAgo(diff.inDays);
  }
  return l10n.common_relativeTime_monthsAgo((diff.inDays / 30).floor());
}

/// Short relative-future formatter ("in 5m", "in 2h"). Returns "overdue"
/// when the target is in the past — the scheduler will pick that row up
/// on the next periodic cycle.
String _nextRelative(AppLocalizations l10n, DateTime when) {
  final diff = when.toUtc().difference(clock.now().toUtc());
  if (diff.isNegative) return l10n.common_relativeTime_overdue;
  if (diff.inMinutes < 1) return l10n.common_relativeTime_inLessThanMinute;
  if (diff.inHours < 1) {
    return l10n.common_relativeTime_inMinutes(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.common_relativeTime_inHours(diff.inHours);
  }
  return l10n.common_relativeTime_inDays(diff.inDays);
}
