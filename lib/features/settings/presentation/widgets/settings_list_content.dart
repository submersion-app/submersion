import 'package:flutter/material.dart';

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
    id: 'manage',
    icon: Icons.folder_shared,
    title: 'Manage',
    subtitle: 'Trips, buddies, certifications',
  ),
  SettingsSection(
    id: 'api',
    icon: Icons.cloud,
    title: 'API Integrations',
    subtitle: 'Weather & tide services',
  ),
  SettingsSection(
    id: 'data',
    icon: Icons.storage,
    title: 'Data',
    subtitle: 'Import, export, backup',
  ),
  SettingsSection(
    id: 'computer',
    icon: Icons.bluetooth,
    title: 'Dive Computer',
    subtitle: 'Connected devices',
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
          ? AppBar(title: const Text('Settings'))
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
                          'Settings',
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

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            section.icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          section.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
        subtitle: Text(
          section.subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
