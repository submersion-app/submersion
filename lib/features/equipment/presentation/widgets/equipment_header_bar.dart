import 'package:flutter/material.dart';

/// Pane width at or above which the section toggle and the action icons share
/// a single row.
///
/// Below it they stack, toggle first. The master pane is user-resizable down
/// to 280px, and the leanest merged row measures 360px (371px in German), so
/// there is no arrangement that keeps them on one row at the minimum.
const double kEquipmentHeaderMergeWidth = 400;

/// Width and height of an action icon's slot in the merged desktop row.
///
/// [IconButton] floors its constraints at [kMinInteractiveDimension], so five
/// icons cost 240px on a 440px pane whatever size the glyphs are drawn at.
/// That floor exists for fingers; the merged row only ever appears in the
/// desktop master pane, so the icons take a pointer-sized slot there and the
/// toggle gets the 80px back.
const double kEquipmentHeaderDenseSlot = 32;

/// Builds the section toggle. [showIcons] is false in the merged row, which
/// has no width for the leading glyphs.
typedef EquipmentHeaderToggleBuilder =
    Widget Function(BuildContext context, {required bool showIcons});

/// Builds the action icons. [dense] is true in the merged row, where the
/// icons take [kEquipmentHeaderDenseSlot] rather than the touch floor.
typedef EquipmentHeaderActionsBuilder =
    List<Widget> Function(BuildContext context, {required bool dense});

/// The bar above the equipment and equipment-set lists.
///
/// It carries two things, and their order is the point: the Equipment / Sets
/// toggle scopes the actions beside it, so it always comes first. It sits on
/// the row above them, or to their left once the pane is wide enough for one
/// row (issue #2256, where the wide pane rendered it after them).
///
/// [toggleBuilder] is null on phone, where the page's own app bar carries both
/// the title and the toggle. This bar then holds the actions alone, with no
/// title of its own to repeat the one directly above it.
class EquipmentHeaderBar extends StatelessWidget {
  const EquipmentHeaderBar({
    super.key,
    this.toggleBuilder,
    required this.actionsBuilder,
  });

  final EquipmentHeaderToggleBuilder? toggleBuilder;
  final EquipmentHeaderActionsBuilder actionsBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final toggle = toggleBuilder;

        if (toggle == null) {
          final actions = actionsBuilder(context, dense: false);
          // Equipment sets have no actions, so on phone this bar would be an
          // empty strip. Drop it rather than reserve a row for nothing.
          if (actions.isEmpty) return const SizedBox.shrink();
          return _shell(context, _actionRow(actions));
        }

        if (constraints.maxWidth >= kEquipmentHeaderMergeWidth) {
          final actions = actionsBuilder(context, dense: true);
          return _shell(
            context,
            Row(
              children: [
                // One flexible child and no Spacer: a Spacer is
                // Expanded(flex: 1), so pairing it with a flexible toggle
                // splits the free space evenly and clips the toggle to half a
                // row it actually fits in. Align holds the toggle at its
                // natural width inside the expanded slot, and the icons keep
                // their floor, so a long translation comes out of the toggle
                // rather than out of the bar.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: toggle(context, showIcons: false),
                  ),
                ),
                ...actions,
              ],
            ),
          );
        }

        final actions = actionsBuilder(context, dense: false);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _shell(
              context,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Flexible(child: toggle(context, showIcons: true))],
              ),
            ),
            if (actions.isNotEmpty) _shell(context, _actionRow(actions)),
          ],
        );
      },
    );
  }

  Widget _actionRow(List<Widget> actions) =>
      Row(children: [const Spacer(), ...actions]);

  Widget _shell(BuildContext context, Widget child) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: child,
    );
  }
}

/// An action [IconButton] for [EquipmentHeaderBar], sized for the row it is in.
///
/// [dense] drops the touch floor to [kEquipmentHeaderDenseSlot] for the merged
/// desktop row. `VisualDensity.compact` is deliberately not used: it trims the
/// slot without releasing the floor, so the result is neither a full touch
/// target nor small enough to buy the row any width.
Widget equipmentHeaderIconButton({
  Key? key,
  required Widget icon,
  required String tooltip,
  required VoidCallback onPressed,
  required bool dense,
}) {
  return IconButton(
    key: key,
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    padding: dense ? EdgeInsets.zero : null,
    constraints: dense
        ? const BoxConstraints.tightFor(
            width: kEquipmentHeaderDenseSlot,
            height: kEquipmentHeaderDenseSlot,
          )
        : null,
    style: dense
        ? const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap)
        : null,
  );
}

/// [PopupMenuButton] sized to match [equipmentHeaderIconButton].
///
/// `PopupMenuButton.constraints` sizes the menu, not the button, so the button
/// is constrained from outside instead.
Widget equipmentHeaderMenuSlot({required Widget child, required bool dense}) {
  if (!dense) return child;
  return SizedBox(
    width: kEquipmentHeaderDenseSlot,
    height: kEquipmentHeaderDenseSlot,
    child: child,
  );
}
