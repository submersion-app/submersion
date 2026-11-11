import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';

/// The "Dive Details" group of Settings > Appearance > Dives: how a dive's
/// page is laid out, its diver figure, its gear arrangement and the tissue
/// loading colours.
class DiveDetailsAppearanceTiles extends ConsumerWidget {
  const DiveDetailsAppearanceTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.reorder),
          title: Text(
            l10n.settings_appearance_diveDetails_sectionOrderVisibility,
          ),
          subtitle: Text(
            l10n.settings_appearance_diveDetails_sectionOrderVisibility_subtitle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/dive-detail-sections'),
        ),
        // The diver figure in the equipment card (issue #2326), off by
        // default so the dive page is unchanged until the diver opts in.
        SwitchListTile(
          secondary: const Icon(Icons.accessibility_new),
          title: Text(l10n.settings_appearance_showDiveFigure),
          subtitle: Text(l10n.settings_appearance_showDiveFigure_subtitle),
          value: ref.watch(settingsProvider.select((s) => s.showDiveFigure)),
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).setShowDiveFigure(value),
        ),
        // Mirrors the arrange sheet reachable from every gear list, so the
        // choice is also findable among a dive's display settings rather than
        // only where the order annoyed the diver (#1486, #1576). It lived in
        // the general Appearance list until #3750 moved it here.
        ListTile(
          leading: const Icon(Icons.sort),
          title: Text(l10n.settings_appearance_gearArrangement),
          subtitle: Text(l10n.settings_appearance_gearArrangementSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showEquipmentArrangeSheet(context),
        ),
        // The tissue heat maps' colour scale. It was a palette button on the
        // Tissue Loading card until #4437; it is a standing preference that
        // also colours Dive Lab and the 3D view, so it belongs here.
        ListTile(
          // Not palette_outlined: the Metric colors tile in this section
          // already uses it.
          leading: const Icon(Icons.gradient),
          title: LabelWithControl(
            label: Text(l10n.settings_appearance_tissueColorScheme),
            control: DropdownButton<TissueColorScheme>(
              value: ref.watch(
                settingsProvider.select((s) => s.tissueColorScheme),
              ),
              underline: const SizedBox(),
              onChanged: (scheme) {
                if (scheme != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setTissueColorScheme(scheme);
                }
              },
              items: [
                for (final scheme in TissueColorScheme.values)
                  DropdownMenuItem(
                    value: scheme,
                    child: Text(switch (scheme) {
                      TissueColorScheme.classic =>
                        l10n.enum_tissueColorScheme_classic,
                      TissueColorScheme.thermal =>
                        l10n.enum_tissueColorScheme_thermal,
                    }),
                  ),
              ],
            ),
          ),
          subtitle: Text(l10n.settings_appearance_tissueColorScheme_subtitle),
        ),
      ],
    );
  }
}
