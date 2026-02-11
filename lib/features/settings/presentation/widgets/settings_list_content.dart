import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings section data model.
class SettingsSection {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  const SettingsSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
  });
}

/// List of all settings sections.
const settingsSections = [
  SettingsSection(
    id: 'profile',
    icon: Icons.person,
    title: 'Diver Profile',
    subtitle: 'Active diver & profiles',
  ),
  SettingsSection(
    id: 'units',
    icon: Icons.straighten,
    title: 'Units',
    subtitle: 'Measurement preferences',
  ),
  SettingsSection(
    id: 'decompression',
    icon: Icons.timeline,
    title: 'Decompression',
    subtitle: 'Gradient factors',
  ),
  SettingsSection(
    id: 'appearance',
    icon: Icons.palette,
    title: 'Appearance',
    subtitle: 'Theme & display',
  ),
  SettingsSection(
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Service reminders',
    icon: Icons.notifications_outlined,
    color: Colors.orange,
  ),
  SettingsSection(
    id: 'manage',
    icon: Icons.folder_shared,
    title: 'Manage',
    subtitle: 'Dive types & tank presets',
  ),
  SettingsSection(
    id: 'data',
    icon: Icons.storage,
    title: 'Data',
    subtitle: 'Backup, restore & storage',
  ),
  SettingsSection(
    id: 'about',
    icon: Icons.info_outline,
    title: 'About',
    subtitle: 'App info & licenses',
  ),
];

/// Content widget for the settings section list, used in master-detail layout.
class SettingsListContent extends StatelessWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;

  const SettingsListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(title: Text(context.l10n.settings_appBar_title))
          : PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.settings_appBar_title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: settingsSections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = settingsSections[index];
          final isSelected = selectedId == section.id;

          return _SettingsSectionTile(
            section: section,
            isSelected: isSelected,
            onTap: () {
              if (onItemSelected != null) {
                onItemSelected!(section.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _SettingsSectionTile extends StatelessWidget {
  final SettingsSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsSectionTile({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = section.color ?? colorScheme.primary;
    final localizedTitle = _getLocalizedTitle(context, section.id);
    final localizedSubtitle = _getLocalizedSubtitle(context, section.id);

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: ListTile(
        leading: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: color, size: 24),
          ),
        ),
        title: Text(
          localizedTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          localizedSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: ExcludeSemantics(
          child: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  String _getLocalizedTitle(BuildContext context, String id) {
    switch (id) {
      case 'profile':
        return context.l10n.settings_section_diverProfile_title;
      case 'units':
        return context.l10n.settings_section_units_title;
      case 'decompression':
        return context.l10n.settings_section_decompression_title;
      case 'appearance':
        return context.l10n.settings_section_appearance_title;
      case 'notifications':
        return context.l10n.settings_section_notifications_title;
      case 'manage':
        return context.l10n.settings_section_manage_title;
      case 'data':
        return context.l10n.settings_section_data_title;
      case 'about':
        return context.l10n.settings_section_about_title;
      default:
        return section.title;
    }
  }

  String _getLocalizedSubtitle(BuildContext context, String id) {
    switch (id) {
      case 'profile':
        return context.l10n.settings_section_diverProfile_subtitle;
      case 'units':
        return context.l10n.settings_section_units_subtitle;
      case 'decompression':
        return context.l10n.settings_section_decompression_subtitle;
      case 'appearance':
        return context.l10n.settings_section_appearance_subtitle;
      case 'notifications':
        return context.l10n.settings_section_notifications_subtitle;
      case 'manage':
        return context.l10n.settings_section_manage_subtitle;
      case 'data':
        return context.l10n.settings_section_data_subtitle;
      case 'about':
        return context.l10n.settings_section_about_subtitle;
      default:
        return section.subtitle;
    }
  }
}
