import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Coarse and fine steppers that shift every staged file's capture time and
/// re-run [DivePhotoMatcher] live.
///
/// Fixes the case where a camera clock was set to the wrong timezone or never
/// adjusted after travelling: the error is constant across the whole card, so
/// one correction rescues every file at once (issue #312).
///
/// The bar is rendered whenever files are staged and auto-match is on, not only
/// while something is unmatched. Gating it on the unmatched count would make
/// the control vanish the moment a shift succeeded, leaving the diver no way to
/// undo or fine-tune it.
class CaptureTimeOffsetBar extends ConsumerWidget {
  final FilesTabState state;

  const CaptureTimeOffsetBar({super.key, required this.state});

  /// Whole hours, the size of a timezone or DST error.
  static const coarseStep = Duration(hours: 1);

  /// Quarter hours, which covers the offset timezones (India, Nepal, parts of
  /// Australia) as well as a hand-set clock that simply drifted.
  static const fineStep = Duration(minutes: 15);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.media_photoPicker_files_offsetLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _step(context, ref, -coarseStep, Icons.keyboard_double_arrow_left),
          _step(context, ref, -fineStep, Icons.chevron_left),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              formatSignedOffset(state.captureTimeOffset),
              style: theme.textTheme.titleMedium,
            ),
          ),
          _step(context, ref, fineStep, Icons.chevron_right),
          _step(context, ref, coarseStep, Icons.keyboard_double_arrow_right),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: context.l10n.media_photoPicker_files_offsetResetTooltip,
            onPressed: state.captureTimeOffset == Duration.zero
                ? null
                : () => _apply(ref, (_) => Duration.zero),
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context,
    WidgetRef ref,
    Duration delta,
    IconData icon,
  ) {
    final amount = formatOffsetMagnitude(delta);
    return IconButton(
      icon: Icon(icon),
      tooltip: delta.isNegative
          ? context.l10n.media_photoPicker_files_offsetBackTooltip(amount)
          : context.l10n.media_photoPicker_files_offsetForwardTooltip(amount),
      onPressed: () => _apply(ref, (current) => current + delta),
    );
  }

  /// Re-runs the matcher against the dive windows and publishes the offset and
  /// its result in a single state update.
  ///
  /// Reads [diveBoundsProvider] rather than deriving bounds here so the rule
  /// stays in one place and the picker never has to be reopened to re-match.
  ///
  /// [nextOffset] receives the offset current *after* the bounds resolve, and
  /// the files are re-read at the same moment, because awaiting the provider
  /// opens a window the user can act inside (it reads the database on first
  /// use). Matching against this widget's build-time [state] instead would
  /// mean a file removed during that window reappears, since
  /// [FilesTabNotifier.setCaptureTimeOffset] replaces `match` but not `files`,
  /// and a second stepper tap would recompute from a stale offset and lose a
  /// step.
  Future<void> _apply(
    WidgetRef ref,
    Duration Function(Duration current) nextOffset,
  ) async {
    final bounds = await ref.read(diveBoundsProvider.future);
    final current = ref.read(filesTabNotifierProvider);
    final offset = nextOffset(current.captureTimeOffset);
    final match = const DivePhotoMatcher().match(
      files: current.files,
      dives: bounds,
      offset: offset,
    );
    ref
        .read(filesTabNotifierProvider.notifier)
        .setCaptureTimeOffset(offset, match: match);
  }
}
