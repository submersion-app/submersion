import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/nearby_device_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/nearby_device_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Nearby devices block on the Sync page (issue #3731): the automatic
/// switch, one row per paired device, and the way to pair another.
class NearbyDevicesSection extends ConsumerWidget {
  const NearbyDevicesSection({super.key});

  static const pairRoute = '/settings/cloud-sync/nearby-pair';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final behavior = ref.watch(syncBehaviorProvider);
    final peers = ref.watch(nearbyPeersProvider).value ?? const <NearbyPeer>[];
    final progress =
        ref.watch(nearbyProgressProvider).value ?? const <String, Never>{};
    final canAdvertise = ref.watch(nearbyCanAdvertiseProvider);
    final formatter = UnitFormatter(ref.watch(settingsProvider));
    final status = StatusColors.of(context);
    final now = DateTime.now();

    Color dotColor(NearbyDot dot) => switch (dot) {
      NearbyDot.ok => status.ok.accent,
      NearbyDot.warn => status.warn.accent,
      NearbyDot.idle => theme.colorScheme.onSurfaceVariant,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.settings_nearby_title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          key: const Key('nearby-auto'),
          title: Text(l10n.settings_nearby_auto_title),
          subtitle: Text(
            canAdvertise
                ? l10n.settings_nearby_auto_subtitle
                : '${l10n.settings_nearby_auto_subtitle}\n'
                      '${l10n.settings_nearby_linuxNote}',
          ),
          value: behavior.nearbyAutoEnabled,
          onChanged: (v) =>
              ref.read(syncBehaviorProvider.notifier).setNearbyAutoEnabled(v),
        ),
        for (final peer in peers)
          Builder(
            builder: (context) {
              final line = nearbyDeviceStatus(
                l10n: l10n,
                peer: peer,
                error: nearbyPeerErrorOf(peer),
                progress: progress[peer.peerDeviceId],
                now: now,
                formatDate: formatter.formatDate,
              );
              return ListTile(
                key: Key('nearby-peer-${peer.peerDeviceId}'),
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: dotColor(line.dot),
                ),
                title: Text(peer.displayName),
                subtitle: Text(line.text),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showNearbyDeviceSheet(context, peer),
              );
            },
          ),
        ListTile(
          key: const Key('nearby-pair'),
          leading: Icon(Icons.add, color: theme.colorScheme.primary),
          title: Text(
            l10n.settings_nearby_pair,
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          onTap: () => context.push(pairRoute),
        ),
      ],
    );
  }
}
