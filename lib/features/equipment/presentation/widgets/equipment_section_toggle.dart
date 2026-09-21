import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The Equipment / Sets choice, rendered as a segmented control.
///
/// It is driven by the page's [TabController] rather than its own state, so
/// the phone layout keeps the swipe gesture its `TabBarView` provides: a swipe
/// moves the controller, and this control follows.
///
/// [showIcons] is a density choice, not a style one. The merged desktop header
/// puts this control on the same row as the action icons, where the leading
/// glyphs cost width the row does not have; every other placement has room for
/// them. See [EquipmentHeaderBar] for where each case applies.
class EquipmentSectionToggle extends StatelessWidget {
  const EquipmentSectionToggle({
    super.key,
    required this.controller,
    this.showIcons = true,
  });

  final TabController controller;
  final bool showIcons;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final equipment = context.l10n.equipment_tab_equipment;
        final sets = context.l10n.equipment_tab_sets;

        return SegmentedButton<int>(
          key: const ValueKey('equipment_section_toggle'),
          segments: [
            ButtonSegment<int>(
              value: 0,
              icon: showIcons ? const Icon(Icons.backpack, size: 18) : null,
              label: _label(equipment),
              tooltip: equipment,
            ),
            ButtonSegment<int>(
              value: 1,
              icon: showIcons
                  ? const Icon(Icons.folder_special, size: 18)
                  : null,
              label: _label(sets),
              tooltip: sets,
            ),
          ],
          selected: {controller.index},
          onSelectionChanged: (selection) =>
              controller.animateTo(selection.first),
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }

  /// Labels give way rather than push the row wide.
  ///
  /// The header keeps this control on one row with the action icons wherever
  /// it fits, and a long translation must cost width here rather than overflow
  /// the bar. Each segment carries the full text as its tooltip, so nothing is
  /// lost when it does clip.
  static Widget _label(String text) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);
}
