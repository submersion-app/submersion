import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/around_controls.dart';
import 'package:submersion/features/connections/presentation/panel/highlight_mode_control.dart';
import 'package:submersion/features/connections/presentation/panel/map_editor.dart';
import 'package:submersion/features/connections/presentation/panel/mode_switch.dart';
import 'package:submersion/features/connections/presentation/panel/preset_grid.dart';
import 'package:submersion/features/connections/presentation/panel/summary_block.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';

class ViewTab extends ConsumerWidget {
  const ViewTab({super.key, required this.graph, this.groupCount = 0});

  final ConnectionGraph graph;

  /// Groups label propagation found in [graph], for the highlight key.
  final int groupCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(connectionsViewProvider);
    final around = view.mode == ConnectionsMode.around;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ModeSwitch(),
        const SizedBox(height: 12),
        HighlightModeControl(groupCount: groupCount),
        const SizedBox(height: 12),
        if (around)
          AroundControls(graph: graph)
        else ...const [PresetGrid(), SizedBox(height: 8), MapEditor()],
        if (!view.isAroundWithoutFocus && !graph.isEmpty) ...[
          const Divider(height: 24),
          SummaryBlock(graph: graph, focus: around ? view.focus : null),
        ],
      ],
    );
  }
}
