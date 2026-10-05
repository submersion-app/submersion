import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Play or pause the year-by-year growth of the map.
class YearPlayButton extends ConsumerWidget {
  const YearPlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playing = ref.watch(yearPlayProvider) != null;
    final notifier = ref.read(yearPlayProvider.notifier);
    return IconButton(
      key: const ValueKey('year-play-button'),
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      tooltip: playing
          ? l10n.connections_yearPlay_pause
          : l10n.connections_yearPlay_play,
      onPressed: playing ? notifier.pause : notifier.play,
    );
  }
}

/// The play control over the canvas, with the years on screen. Play writes
/// the filter each beat, so the range here follows it with no state of its
/// own. Hidden when the log spans fewer than two years.
class YearPlayPill extends ConsumerWidget {
  const YearPlayPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final span = ref.watch(connectionsYearSpanProvider).value;
    if (span == null || span.first >= span.last) {
      return const SizedBox.shrink();
    }
    final filter = ref.watch(connectionsFilterProvider);
    final (lower: lo, upper: hi) = filteredYears(filter, span);
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('year-play-pill'),
      shape: const StadiumBorder(),
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const YearPlayButton(),
            Text(
              context.l10n.connections_yearRange_label(lo, hi),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
