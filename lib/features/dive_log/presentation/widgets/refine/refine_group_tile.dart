import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One collapsible group of the Refine panel (#2773): its title, a summary
/// of how many of its axes are set, and its controls. Opens on its own when
/// something in it is set, so a diver sees what is active.
class RefineGroupTile extends StatelessWidget {
  const RefineGroupTile({
    super.key,
    required this.title,
    required this.activeCount,
    required this.child,
  });

  final String title;
  final int activeCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpansionTile(
      title: Text(title),
      subtitle: Text(
        activeCount == 0
            ? l10n.diveLog_refine_summaryAny
            : l10n.diveLog_refine_summaryCount(activeCount),
      ),
      initiallyExpanded: activeCount > 0,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [child],
    );
  }
}

/// A sub-heading inside a Refine group, above one axis's controls.
class RefineSubLabel extends StatelessWidget {
  const RefineSubLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
