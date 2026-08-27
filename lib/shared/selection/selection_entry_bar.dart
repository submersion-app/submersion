import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

/// The Select affordance shown above a table while selection mode is closed.
///
/// Table mode is the one surface shape with no app bar of its own to hang the
/// control on: [TableModeLayout] owns the window chrome and cannot reach the
/// content's [SelectionController], while the content renders only the table.
/// Long-press used to paper over that, so removing it left table mode with no
/// touch route into multi-select at all -- modifier-click covers desktop, but
/// nothing covered touch.
///
/// It deliberately matches [SelectionAppBar]'s pane shell -- same colour, same
/// `kToolbarHeight` -- so entering selection swaps one bar for the other in
/// place rather than shifting the whole table down a row.
class SelectionEntryBar extends StatelessWidget {
  final SelectionController controller;

  const SelectionEntryBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            const Spacer(),
            IconButton(
              key: const ValueKey('enter_selection'),
              icon: const Icon(Icons.checklist),
              tooltip: context.l10n.common_selection_enterTooltip,
              onPressed: controller.enterExplicit,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
