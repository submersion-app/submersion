import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class ModeSwitch extends ConsumerWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(connectionsViewProvider.select((s) => s.mode));
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ConnectionsMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ConnectionsMode.around,
            label: Text(l10n.connections_mode_around, softWrap: true),
          ),
          ButtonSegment(
            value: ConnectionsMode.map,
            label: Text(l10n.connections_mode_map, softWrap: true),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => ref
            .read(connectionsViewProvider.notifier)
            .update((v) => v.withMode(s.single)),
      ),
    );
  }
}
