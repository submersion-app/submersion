import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The shared trips and sites the active profile has hidden from itself,
/// each with Unhide (issue #2594).
class HiddenItemsPage extends ConsumerWidget {
  const HiddenItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(hiddenItemsProvider);
    final divers = ref.watch(allDiversProvider).value ?? const <Diver>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_hiddenItems_title)),
      body: items.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) =>
            Center(child: Text(context.l10n.common_error_tryAgain)),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.settings_hiddenItems_empty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final trips = [
            for (final i in items)
              if (i.kind == SharedItemKind.trip) i,
          ];
          final sites = [
            for (final i in items)
              if (i.kind == SharedItemKind.site) i,
          ];
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (trips.isNotEmpty) ...[
                _Header(context.l10n.settings_hiddenItems_trips),
                for (final item in trips)
                  _HiddenRow(item: item, divers: divers),
              ],
              if (sites.isNotEmpty) ...[
                _Header(context.l10n.settings_hiddenItems_sites),
                for (final item in sites)
                  _HiddenRow(item: item, divers: divers),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _HiddenRow extends ConsumerWidget {
  const _HiddenRow({required this.item, required this.divers});

  final HiddenItem item;
  final List<Diver> divers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = [
      // A trip's dates tell two same-named trips apart.
      if (item.kind == SharedItemKind.trip && item.startDate != null)
        UnitFormatter(
          ref.watch(settingsProvider),
        ).formatDateRange(item.startDate, item.endDate, l10n: context.l10n),
      if (item.location case final location? when location.isNotEmpty) location,
      if (item.isShared)
        context.l10n.sharedItems_sharedBy(
          sharedItemOwnerName(divers, item.ownerId, context.l10n),
        ),
    ];
    return ListTile(
      title: Text(item.name),
      // Unhide sits on its own line under the details rather than in
      // trailing: a ListTile lays trailing out at its natural width first,
      // so a translated label there squeezes the item name (issue #2717).
      isThreeLine: details.isNotEmpty,
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty) Text(details.join(' · ')),
          TileSubtitleAction(
            onPressed: () => switch (item.kind) {
              SharedItemKind.trip =>
                ref.read(tripListNotifierProvider.notifier).unhideTrip(item.id),
              SharedItemKind.site =>
                ref.read(siteListNotifierProvider.notifier).unhideSites([
                  item.id,
                ]),
            },
            label: context.l10n.settings_hiddenItems_unhide,
          ),
        ],
      ),
    );
  }
}
