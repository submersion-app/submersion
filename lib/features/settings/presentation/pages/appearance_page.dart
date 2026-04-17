import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _sectionRoutes = [
  'dives',
  'sites',
  'buddies',
  'trips',
  'equipment',
  'dive-centers',
  'certifications',
  'courses',
];

String _sectionDisplayName(BuildContext context, String routeSegment) {
  final l10n = context.l10n;
  return switch (routeSegment) {
    'dives' => l10n.nav_dives,
    'sites' => l10n.nav_sites,
    'buddies' => l10n.nav_buddies,
    'trips' => l10n.nav_trips,
    'equipment' => l10n.nav_equipment,
    'dive-centers' => l10n.nav_diveCenters,
    'certifications' => l10n.nav_certifications,
    'courses' => l10n.nav_courses,
    _ => routeSegment,
  };
}

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_appearance_title),
      ),
      body: ListView(
        children: [
          // -- General --
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_general,
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_themes_current),
            subtitle: Text(_resolveCurrentThemeName(context, ref)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/themes'),
          ),
          const Divider(),
          _buildThemeSelector(context, ref, settings.themeMode),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.settings_appearance_appLanguage),
            subtitle: Text(
              LanguageSettingsPage.getDisplayName(settings.locale),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/language'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(context.l10n.settings_appearance_mapStyle),
            subtitle: Text(_getMapStyleDisplayName(context, settings.mapStyle)),
            trailing: DropdownButton<MapStyle>(
              value: settings.mapStyle,
              underline: const SizedBox.shrink(),
              onChanged: (style) {
                if (style != null) {
                  ref.read(settingsProvider.notifier).setMapStyle(style);
                }
              },
              items: MapStyle.values.map((style) {
                return DropdownMenuItem(
                  value: style,
                  child: Text(_getMapStyleDisplayName(context, style)),
                );
              }).toList(),
            ),
          ),
          const Divider(),

          // -- Sections --
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_sections,
          ),
          for (final route in _sectionRoutes)
            ListTile(
              title: Text(_sectionDisplayName(context, route)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/appearance/$route'),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    return Column(
      children: ThemeMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return Semantics(
          selected: isSelected,
          child: ListTile(
            leading: Icon(_getThemeModeIcon(mode)),
            title: Text(_getThemeModeName(context, mode)),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: context.l10n.settings_language_selected,
                  )
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(mode);
            },
          ),
        );
      }).toList(),
    );
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return context.l10n.settings_appearance_theme_system;
      case ThemeMode.light:
        return context.l10n.settings_appearance_theme_light;
      case ThemeMode.dark:
        return context.l10n.settings_appearance_theme_dark;
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  String _getMapStyleDisplayName(BuildContext context, MapStyle style) {
    return switch (style) {
      MapStyle.openStreetMap =>
        context.l10n.settings_appearance_mapStyle_openStreetMap,
      MapStyle.openTopoMap =>
        context.l10n.settings_appearance_mapStyle_openTopoMap,
      MapStyle.esriSatellite =>
        context.l10n.settings_appearance_mapStyle_esriSatellite,
    };
  }

  String _resolveCurrentThemeName(BuildContext context, WidgetRef ref) {
    final presetId = ref.watch(settingsProvider.select((s) => s.themePresetId));
    final preset = AppThemeRegistry.findById(presetId);
    final l10n = context.l10n;
    switch (preset.nameKey) {
      case 'theme_submersion':
        return l10n.theme_submersion;
      case 'theme_console':
        return l10n.theme_console;
      case 'theme_tropical':
        return l10n.theme_tropical;
      case 'theme_minimalist':
        return l10n.theme_minimalist;
      case 'theme_deep':
        return l10n.theme_deep;
      default:
        return preset.nameKey;
    }
  }
}
