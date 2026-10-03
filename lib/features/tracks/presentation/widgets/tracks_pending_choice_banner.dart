import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "N underwater tracks need your choice": underwater tracks a sweep could only
/// suggest a dive for, which the diver links from each track's detail page
/// (#2394). Hidden when none are waiting.
class TracksPendingChoiceBanner extends ConsumerWidget {
  const TracksPendingChoiceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(navTrackPendingChoiceCountProvider).value ?? 0;
    // About underwater tracks only, so it leaves with them when the list
    // shows GPS tracks alone.
    final gpsOnly = ref.watch(trackKindFilterProvider) == TrackKindFilter.gps;
    if (count == 0 || gpsOnly) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('tracks-pending-choice-banner'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.navTrack_list_pendingTrackChoice(count)),
          ),
        ],
      ),
    );
  }
}
