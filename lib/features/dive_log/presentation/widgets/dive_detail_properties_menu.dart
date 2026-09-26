import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

/// The dive detail page's display-options panel, opened from its overflow
/// menu.
///
/// Puts the page-shape choices where the page is (which sections show, in
/// what order, and how much room each one gets) instead of only under
/// Settings. All of them write to the same per-diver settings the Settings
/// page edits, so a choice made here is the choice made there.
///
/// The menu itself is the shared [SectionPropertiesMenu]; this wrapper
/// decides which sections a dive offers and where each choice is written.
class DiveDetailPropertiesMenu extends ConsumerWidget {
  const DiveDetailPropertiesMenu({
    super.key,
    required this.isGauge,
    required this.controller,
    required this.child,
  });

  /// Whether the dive is a gauge (bottom-timer) dive.
  ///
  /// Gauge dives never render the gas and decompression sections, so their
  /// toggles are left out rather than shown switched on with nothing behind
  /// them.
  final bool isGauge;

  /// See [SectionPropertiesMenu.controller].
  final MenuController controller;

  /// The page's overflow button, which the panel drops down from.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.diveDetailLayout),
    );
    final offered = [
      for (final section in sections)
        if (!(isGauge && section.id.hiddenInGaugeMode)) section,
    ];

    return SectionPropertiesMenu(
      controller: controller,
      layout: layout,
      onLayoutChanged: (option) =>
          ref.read(settingsProvider.notifier).setDiveDetailLayout(option),
      entries: [
        for (final section in offered)
          SectionMenuEntry(
            id: section.id,
            label: section.id.localizedDisplayName(l10n),
            icon: section.id.icon,
            visible: section.visible,
          ),
      ],
      onToggle: (index) => _toggle(ref, sections, offered[index]),
      onReorder: (oldIndex, newIndex) => ref
          .read(settingsProvider.notifier)
          .setDiveDetailSections(
            DiveDetailSectionConfig.moveRenderedSection(
              sections,
              [for (final section in offered) section.id],
              oldIndex,
              newIndex,
            ),
          ),
      onShowAll: () => _showAll(ref, sections, offered),
      onOpenSettings: () => context.pushNamed('diveDetailSections'),
      child: child,
    );
  }

  void _toggle(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    DiveDetailSectionConfig section,
  ) {
    final updated = [
      for (final s in sections)
        if (s.id == section.id) s.copyWith(visible: !s.visible) else s,
    ];
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }

  /// Turns every offered section back on, leaving the diver's order alone.
  ///
  /// Deliberately not `resetDiveDetailSections`, which would also throw away
  /// a custom order the diver never asked to undo. Only the sections the menu
  /// lists are touched: on a gauge dive the gas and deco sections are not
  /// shown here, so switching them on would be a change the diver could
  /// neither see nor expect, surfacing only on their next non-gauge dive.
  void _showAll(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    List<DiveDetailSectionConfig> offered,
  ) {
    final offeredIds = {for (final s in offered) s.id};
    final updated = [
      for (final s in sections)
        if (offeredIds.contains(s.id)) s.copyWith(visible: true) else s,
    ];
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }
}
