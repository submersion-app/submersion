import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Entered water", or "Surfaced" while a dive is open on this device
/// (issue #637), on the GPS log's recording card and strip. Surfaced acts on
/// that dive whoever's it is; Entered water needs a current diver.
class DiveMarkButtons extends ConsumerWidget {
  const DiveMarkButtons({super.key, this.compact = false, this.foreground});

  /// The strip's small text button rather than the card's full-width one.
  final bool compact;

  /// The compact button's colour, to sit on the strip's background.
  final Color? foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverId = ref.watch(currentDiverIdProvider);
    final open = ref.watch(markingDraftProvider).value;
    if (diverId == null && open == null) return const SizedBox.shrink();
    final l10n = context.l10n;

    Future<void> mark() async {
      final marks = ref.read(diveMarkServiceProvider);
      if (open == null) {
        await marks.enteredWater(diverId: diverId!);
      } else {
        await marks.surfaced();
      }
      ref.invalidate(markingDraftProvider);
    }

    final label = Text(
      open == null ? l10n.gpsLogger_enteredWater : l10n.gpsLogger_surfaced,
    );
    final icon = Icon(
      open == null ? Icons.scuba_diving : Icons.arrow_upward,
      size: compact ? 18 : null,
    );
    if (compact) {
      return TextButton.icon(
        onPressed: mark,
        icon: icon,
        label: label,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return FilledButton.icon(onPressed: mark, icon: icon, label: label);
  }
}
