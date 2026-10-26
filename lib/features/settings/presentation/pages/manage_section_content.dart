import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/settings/presentation/widgets/equipment_default_view_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage: the reusable lists and rules offered throughout the
/// app, grouped by where each one is used (issue #3505).
class ManageSectionContent extends StatelessWidget {
  const ManageSectionContent({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManageGroup(
            title: l10n.settings_manage_header_equipment,
            tiles: [
              _ManageTile(
                icon: MdiIcons.divingScubaTank,
                title: l10n.settings_manage_tankPresets,
                subtitle: l10n.settings_manage_tankPresets_subtitle,
                route: '/tank-presets',
              ),
              _ManageTile(
                icon: Icons.sensors,
                title: l10n.settings_manage_transmitters,
                subtitle: l10n.settings_manage_transmitters_subtitle,
                route: '/transmitters',
              ),
              _ManageTile(
                icon: Icons.fitness_center,
                title: l10n.settings_manage_weightPresets,
                subtitle: l10n.settings_manage_weightPresets_subtitle,
                route: '/weight-presets',
              ),
              _ManageTile(
                icon: Icons.build_circle_outlined,
                title: l10n.settings_manage_serviceTypes,
                subtitle: l10n.settings_manage_serviceTypes_subtitle,
                route: '/equipment/service-types',
              ),
              _ManageTile(
                key: const ValueKey('settings_manage_locations'),
                icon: Icons.place_outlined,
                title: l10n.settings_manage_locations,
                subtitle: l10n.settings_manage_locations_subtitle,
                route: '/equipment/locations',
              ),
              const EquipmentDefaultViewTile(),
            ],
          ),
          _ManageGroup(
            title: l10n.settings_manage_header_dives,
            tiles: [
              _ManageTile(
                icon: Icons.label,
                title: l10n.settings_manage_diveTypes,
                subtitle: l10n.settings_manage_diveTypes_subtitle,
                route: '/dive-types',
              ),
              _ManageTile(
                icon: Icons.category,
                title: l10n.settings_manage_siteTypes,
                subtitle: l10n.settings_manage_siteTypes_subtitle,
                route: '/site-types',
              ),
              _ManageTile(
                icon: Icons.groups,
                title: l10n.settings_manage_diveRoles,
                subtitle: l10n.settings_manage_diveRoles_subtitle,
                route: '/dive-roles',
              ),
              _ManageTile(
                icon: MdiIcons.fish,
                title: l10n.settings_manage_species,
                subtitle: l10n.settings_manage_species_subtitle,
                route: '/species/manage',
              ),
            ],
          ),
          _ManageGroup(
            title: l10n.settings_manage_header_planning,
            tiles: [
              _ManageTile(
                icon: Icons.gas_meter,
                title: l10n.settings_section_trimixMixer_title,
                subtitle: l10n.settings_section_trimixMixer_subtitle,
                route: kTrimixMixerSettingsRoute,
              ),
            ],
          ),
          _ManageGroup(
            title: l10n.settings_manage_header_training,
            tiles: [
              _ManageTile(
                icon: Icons.workspace_premium_outlined,
                title: l10n.settings_manage_certificationAgencies,
                subtitle: l10n.settings_manage_certificationAgencies_subtitle,
                route: '/certification-agencies',
              ),
              // Refresher and renewal rules (issue #2267)
              _ManageTile(
                icon: Icons.event_repeat_outlined,
                title: l10n.settings_manage_currencyRules,
                subtitle: l10n.settings_manage_currencyRules_subtitle,
                route: '/currency-rules',
              ),
            ],
          ),
          _ManageGroup(
            title: l10n.settings_manage_header_checklists,
            tiles: [
              _ManageTile(
                icon: Icons.checklist,
                title: l10n.settings_manage_checklistTemplates,
                subtitle: l10n.settings_manage_checklistTemplates_subtitle,
                route: '/checklist-templates',
              ),
              _ManageTile(
                icon: Icons.fact_check,
                title: l10n.settings_manage_preDiveChecklists,
                subtitle: l10n.settings_manage_preDiveChecklists_subtitle,
                route: '/pre-dive-checklists',
              ),
            ],
          ),
          _ManageGroup(
            title: l10n.settings_manage_header_organization,
            tiles: [
              _ManageTile(
                icon: Icons.bookmarks_outlined,
                title: l10n.settings_manage_savedQueries,
                subtitle: l10n.settings_manage_savedQueries_subtitle,
                route: '/saved-queries',
              ),
              _ManageTile(
                icon: Icons.rule,
                title: l10n.settings_manage_rules,
                subtitle: l10n.settings_manage_rules_subtitle,
                route: '/rules',
              ),
              _ManageTile(
                icon: Icons.sell,
                title: l10n.settings_manage_tags,
                subtitle: l10n.settings_manage_tags_subtitle,
                route: '/tags',
              ),
            ],
          ),
          _ManageGroup(
            title: l10n.settings_manage_header_setup,
            isLast: true,
            tiles: [
              _ManageTile(
                icon: Icons.auto_fix_high,
                title: l10n.settings_manage_setupAssistant,
                subtitle: l10n.settings_manage_setupAssistant_subtitle,
                route: '/settings/setup-assistant',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A section header over one card of tiles, with a divider between each
/// tile, so moving a tile between groups never means re-placing dividers.
class _ManageGroup extends StatelessWidget {
  const _ManageGroup({
    required this.title,
    required this.tiles,
    this.isLast = false,
  });

  final String title;
  final List<Widget> tiles;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(context, title),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  tiles[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One navigation row in a Manage group.
class _ManageTile extends StatelessWidget {
  const _ManageTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
