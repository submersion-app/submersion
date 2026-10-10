import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_recorded_tank.dart';
import 'package:submersion/features/dive_log/presentation/providers/computer_mix_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Under a tank's gas fields: whether the mix shown is the one the dive
/// computer recorded, and when it is not, which one was and a Restore that
/// puts it back (issue #3021).
///
/// Shows nothing for a tank the diver added by hand, outside a saved dive,
/// or while the recorded mix is unknown (no raw bytes kept, a parse that
/// failed, or still reading), so it never claims a source it cannot show.
class ComputerMixNote extends ConsumerWidget {
  const ComputerMixNote({
    super.key,
    required this.diveId,
    required this.tank,
    required this.currentMix,
    required this.onRestore,
  });

  /// The saved dive the tank belongs to; null while creating one.
  final String? diveId;
  final DiveTank tank;

  /// The mix the O2/He fields hold now, which may differ from [tank]'s.
  final GasMix currentMix;
  final ValueChanged<GasMix> onRestore;

  /// Percentages a field round-trips through text; anything closer is the
  /// same mix.
  static bool _sameMix(GasMix a, GasMix b) =>
      (a.o2 - b.o2).abs() < 0.05 && (a.he - b.he).abs() < 0.05;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = diveId;
    if (id == null || !isComputerRecordedTank(tank)) {
      return const SizedBox.shrink();
    }
    final recorded = ref
        .watch(recordedComputerMixProvider(computerMixKeyFor(id, tank)))
        .value;
    if (recorded == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final matches = _sameMix(recorded, currentMix);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.watch_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              matches
                  ? l10n.diveLog_tank_computerMix_matches
                  : l10n.diveLog_tank_computerMix_differs(recorded.name),
              style: style,
            ),
          ),
          if (!matches)
            TextButton(
              key: const Key('tank-restore-computer-mix'),
              onPressed: () => onRestore(recorded),
              child: Text(l10n.diveLog_tank_computerMix_restore),
            ),
        ],
      ),
    );
  }
}
