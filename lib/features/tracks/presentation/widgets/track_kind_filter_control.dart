import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// All / GPS / Underwater, at the top of the Tracks list.
class TrackKindFilterControl extends ConsumerWidget {
  const TrackKindFilterControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ref.watch(trackKindFilterProvider);
    return SegmentedButton<TrackKindFilter>(
      key: const ValueKey('tracks-kind-filter'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: TrackKindFilter.all,
          label: Text(l10n.tracks_kind_all),
        ),
        ButtonSegment(
          value: TrackKindFilter.gps,
          label: Text(l10n.tracks_kind_gps),
        ),
        ButtonSegment(
          value: TrackKindFilter.underwater,
          label: Text(l10n.tracks_kind_underwater),
        ),
      ],
      selected: {kind},
      onSelectionChanged: (selection) =>
          ref.read(trackKindFilterProvider.notifier).state = selection.single,
    );
  }
}
