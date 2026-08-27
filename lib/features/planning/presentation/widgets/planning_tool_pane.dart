import 'package:flutter/material.dart';

/// Chrome for a planning tool rendered inside the Planning detail pane.
///
/// [MasterDetailScaffold] renders whatever `detailBuilder` returns with no app
/// bar of its own, so a tool embedded there has nowhere to put the title and
/// actions its full-page form keeps in an [AppBar]. Several planning tools
/// carry real actions (reset, add to planner), and dropping them in the pane
/// would make the split view strictly less capable than the page it replaces.
///
/// The header deliberately matches the compact bar the entity list panes use,
/// so the two halves of a split view read as one surface.
class PlanningToolPane extends StatelessWidget {
  const PlanningToolPane({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // The title is the row's only flexible child. Pairing a
              // Flexible title with a Spacer splits the free space in half
              // and leaves a gap after the last action.
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
