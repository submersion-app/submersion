import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// How far each level of the assembly view indents a row (issue #5071).
const double kAssemblyIndentStep = 20;

/// The width of the fold chevron's gutter: its 48 dp hit box.
const double kAssemblyChevronWidth = 48;

/// The deepest level that still indents further: deeper rigs stay at this
/// indent so a row keeps its width on a phone.
const int kAssemblyMaxIndentLevels = 4;

/// An Equipment list row in the assembly view (issue #5071): [child] (the
/// item's tile) indented by its [depth], with a fold chevron before it when
/// the row is an assembly whose parts are listed under it.
///
/// [isExpanded] is null for a row with nothing to fold, which then draws no
/// chevron and no gap for one.
class AssemblyRowFrame extends StatelessWidget {
  const AssemblyRowFrame({
    super.key,
    required this.depth,
    this.isExpanded,
    this.onToggle,
    this.reserveChevron = false,
    required this.child,
  });

  final int depth;

  /// Keeps the chevron's width free on a row with nothing to fold, so its
  /// card lines up with an assembly's beside it.
  final bool reserveChevron;
  final bool? isExpanded;
  final VoidCallback? onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final indent =
        math.min(depth, kAssemblyMaxIndentLevels) * kAssemblyIndentStep;
    final expanded = isExpanded;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: Row(
        children: [
          if (expanded == null && reserveChevron)
            const SizedBox(width: kAssemblyChevronWidth),
          if (expanded != null)
            SizedBox(
              width: kAssemblyChevronWidth,
              child: Semantics(
                expanded: expanded,
                child: IconButton(
                  icon: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                  ),
                  tooltip: expanded
                      ? context.l10n.equipment_list_hideParts
                      : context.l10n.equipment_list_showParts,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: onToggle,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
