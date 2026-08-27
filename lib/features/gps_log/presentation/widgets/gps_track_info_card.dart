import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// The card floated over the overview map for the selected track.
///
/// Same title and figures as the list row it was picked from, by the same
/// formatters, so the card never contradicts the row.
class GpsTrackInfoCard extends ConsumerWidget {
  const GpsTrackInfoCard({
    super.key,
    required this.track,
    required this.onDetailsTap,
    required this.onClose,
  });

  final GpsTrack track;
  final VoidCallback onDetailsTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    return MapInfoCard(
      title: formatTrackTitle(units, track),
      subtitle: formatTrackDetailLine(l10n, units, track),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.route, color: scheme.primary),
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
