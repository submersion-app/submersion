import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';

/// Where the subscriptions are managed, and where the banner leads.
const String kNetworkSourcesLocation =
    '/settings/media-sources/network-sources';

/// Shown above the media library while an active manifest subscription's
/// last poll failed, so a feed that stopped updating (a changed format, a
/// lost password, an unreachable server) is noticed where its photos are
/// looked at, not only in its settings card.
///
/// Strings follow the media panels' hard-coded English until the feature
/// is localised.
class MediaSubscriptionErrorBanner extends ConsumerWidget {
  const MediaSubscriptionErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failing =
        ref.watch(failingManifestSubscriptionsProvider).valueOrNull ??
        const <ManifestSubscription>[];
    if (failing.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final first = failing.first;
    final name = first.displayName ?? first.manifestUrl;
    // TODO(media): l10n, pluralization
    final text = failing.length == 1
        ? 'Photo subscription "$name" could not be updated: ${first.lastError}'
        : '${failing.length} photo subscriptions could not be updated, '
              'among them "$name": ${first.lastError}';
    return Padding(
      key: const Key('mediaSubscriptionErrorBanner'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.sync_problem, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.pushSettingsPage(kNetworkSourcesLocation),
                // TODO(media): l10n
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The active subscriptions whose last poll failed. Empty when they cannot
/// be read: the banner is a hint, and the library must render without it.
///
/// Reads the repository itself rather than [manifestSubscriptionsProvider],
/// so a database that cannot be read fails here, quietly, instead of as an
/// error of a provider the library would then be listening to.
final failingManifestSubscriptionsProvider =
    FutureProvider<List<ManifestSubscription>>((ref) async {
      try {
        final repository = ref.watch(manifestSubscriptionRepositoryProvider);
        ref.invalidateSelfWhen(repository.watchSubscriptionsChanges());
        return failingSubscriptions(await repository.listAllActive());
      } catch (_) {
        return const [];
      }
    });

/// The active subscriptions whose last poll recorded an error.
List<ManifestSubscription> failingSubscriptions(
  List<ManifestSubscription> subs,
) => [
  for (final s in subs)
    if (s.isActive && (s.lastError?.isNotEmpty ?? false)) s,
];
