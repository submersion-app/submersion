import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// The overview map's card for a selected underwater track, the twin of
/// GpsTrackInfoCard.
class NavTrackInfoCard extends ConsumerWidget {
  const NavTrackInfoCard({
    super.key,
    required this.route,
    required this.onDetailsTap,
    required this.onClose,
  });

  final NavTrack route;
  final VoidCallback onDetailsTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    return MapInfoCard(
      title: route.name ?? route.sourceRef ?? route.id,
      subtitle: formatNavTrackDetailLine(context.l10n, units, route),
      leading: CircleAvatar(
        backgroundColor: scheme.tertiaryContainer,
        child: Icon(Icons.route, color: scheme.tertiary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: onClose,
      ),
      onDetailsTap: onDetailsTap,
    );
  }
}
