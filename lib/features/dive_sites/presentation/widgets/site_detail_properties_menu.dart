import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

/// The Site Details page's display-options panel, opened from its overflow
/// menu.
///
/// The same menu as Dive Details ([SectionPropertiesMenu]), writing to the
/// diver's site settings instead, so the two pages are configured
/// independently. Every card is offered, including ones with nothing to show
/// for the current site: a site can gain coordinates or hazards later.
class SiteDetailPropertiesMenu extends ConsumerWidget {
  const SiteDetailPropertiesMenu({
    super.key,
    required this.controller,
    required this.child,
  });

  /// See [SectionPropertiesMenu.controller].
  final MenuController controller;

  /// The page's overflow button, which the panel drops down from.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(
      settingsProvider.select((s) => s.siteDetailSections),
    );
    final layout = ref.watch(
      settingsProvider.select((s) => s.siteDetailLayout),
    );

    void write(List<SiteDetailSectionConfig> updated) =>
        ref.read(settingsProvider.notifier).setSiteDetailSections(updated);

    return SectionPropertiesMenu(
      controller: controller,
      layout: layout,
      onLayoutChanged: (option) =>
          ref.read(settingsProvider.notifier).setSiteDetailLayout(option),
      entries: [
        for (final section in sections)
          SectionMenuEntry(
            id: section.id,
            label: section.id.localizedDisplayName(l10n),
            icon: section.id.icon,
            visible: section.visible,
          ),
      ],
      onToggle: (index) {
        final id = sections[index].id;
        write([
          for (final s in sections)
            if (s.id == id) s.copyWith(visible: !s.visible) else s,
        ]);
      },
      onReorder: (oldIndex, newIndex) => write(
        SiteDetailSectionConfig.moveRenderedSection(
          sections,
          [for (final s in sections) s.id],
          oldIndex,
          newIndex,
        ),
      ),
      // Turns every card back on without touching the diver's order.
      onShowAll: () =>
          write([for (final s in sections) s.copyWith(visible: true)]),
      onOpenSettings: () => context.pushNamed('siteDetailSections'),
      child: child,
    );
  }
}
