import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/display_zoom_settings_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/nav_customization_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

// The tiles of Settings > Appearance, shared by the two surfaces that render
// it: AppearancePage, pushed on a phone, and the inline Appearance pane of
// SettingsPage on a tablet or desktop. Built separately, the two drifted apart
// (one label renamed, Gear arrangement and Display size on the phone only,
// #3095). Each surface keeps its own chrome, a flat list or cards, and its own
// navigation, and passes both in.

/// Section keys of the Appearance "Sections" list, in display order.
const appearanceSectionKeys = [
  'home',
  'dives',
  'sites',
  'buddies',
  'trips',
  'equipment',
  'diveCenters',
  'certifications',
  'courses',
];

/// Localized name of an [appearanceSectionKeys] entry.
String appearanceSectionDisplayName(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'home' => l10n.nav_home,
    'dives' => l10n.nav_dives,
    'sites' => l10n.nav_sites,
    'buddies' => l10n.nav_buddies,
    'trips' => l10n.nav_trips,
    'equipment' => l10n.nav_equipment,
    'diveCenters' => l10n.nav_diveCenters,
    'certifications' => l10n.nav_certifications,
    'courses' => l10n.nav_courses,
    _ => key,
  };
}

/// Places [separator] between [children]; with no separator, returns them
/// unchanged.
List<Widget> _separated(List<Widget> children, Widget? separator) {
  if (separator == null) return children;
  return [
    for (final (index, child) in children.indexed) ...[
      if (index > 0) separator,
      child,
    ],
  ];
}

/// The "General" group: theme, light/dark mode, display size, language, map
/// style and navigation layout.
class AppearanceGeneralTiles extends ConsumerWidget {
  const AppearanceGeneralTiles({
    required this.onLanguageTap,
    this.separator,
    super.key,
  });

  /// Opens the language list: a pushed page on a phone, an inline sub-page in
  /// the settings pane.
  final VoidCallback onLanguageTap;

  /// Drawn between tiles; null for none.
  final Widget? separator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = context.l10n;

    return Column(
      children: _separated([
        ListTile(
          leading: const FeatureAccentIcon(
            Icons.palette_outlined,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_themes_current),
          subtitle: Text(_currentThemeName(context, settings.themePresetId)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/themes'),
        ),
        Column(
          children: [
            for (final mode in ThemeMode.values)
              _ThemeModeTile(mode: mode, selected: mode == settings.themeMode),
          ],
        ),
        const DisplayZoomSettingsTile(),
        ListTile(
          leading: const FeatureAccentIcon(
            Icons.language,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_header_language),
          subtitle: Text(
            LanguageSettingsPage.getDisplayName(l10n, settings.locale),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onLanguageTap,
        ),
        ListTile(
          leading: const FeatureAccentIcon(
            Icons.map_outlined,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_mapStyle),
          subtitle: Text(_mapStyleName(context, settings.mapStyle)),
          trailing: DropdownButton<MapStyle>(
            value: settings.mapStyle,
            underline: const SizedBox.shrink(),
            onChanged: (style) {
              if (style != null) {
                ref.read(settingsProvider.notifier).setMapStyle(style);
              }
            },
            items: [
              for (final style in MapStyle.values)
                DropdownMenuItem(
                  value: style,
                  child: Text(_mapStyleName(context, style)),
                ),
            ],
          ),
        ),
        const NavCustomizationTile(),
      ], separator),
    );
  }
}

/// The "Color accents" group: the three accent switches and the gear
/// arrangement entry.
class AppearanceAccentTiles extends ConsumerWidget {
  const AppearanceAccentTiles({this.separator, super.key});

  /// Drawn between tiles; null for none.
  final Widget? separator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;

    return Column(
      children: _separated([
        SwitchListTile(
          secondary: const FeatureAccentIcon(
            Icons.format_paint_outlined,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_accentNavIcons),
          subtitle: Text(l10n.settings_appearance_accentNavIcons_subtitle),
          value: settings.accentNavIcons,
          onChanged: notifier.setAccentNavIcons,
        ),
        SwitchListTile(
          secondary: const FeatureAccentIcon(
            Icons.title_outlined,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_accentSectionHeaders),
          subtitle: Text(
            l10n.settings_appearance_accentSectionHeaders_subtitle,
          ),
          value: settings.accentSectionHeaders,
          onChanged: notifier.setAccentSectionHeaders,
        ),
        SwitchListTile(
          secondary: const FeatureAccentIcon(
            Icons.list_alt_outlined,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_accentListIcons),
          subtitle: Text(l10n.settings_appearance_accentListIcons_subtitle),
          value: settings.accentListIcons,
          onChanged: notifier.setAccentListIcons,
        ),
        // Mirrors the arrange sheet reachable from every gear list, so the
        // choice is also findable where a diver looks for display settings
        // rather than only where the order annoyed them (#1486, #1576).
        ListTile(
          leading: const FeatureAccentIcon(
            Icons.sort,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_gearArrangement),
          subtitle: Text(l10n.settings_appearance_gearArrangementSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showEquipmentArrangeSheet(context),
        ),
      ], separator),
    );
  }
}

/// The "Sections" group: one entry per [appearanceSectionKeys] key.
class AppearanceSectionTiles extends StatelessWidget {
  const AppearanceSectionTiles({
    required this.onSectionTap,
    this.separator,
    super.key,
  });

  /// Opens a section's appearance settings, given its key.
  final ValueChanged<String> onSectionTap;

  /// Drawn between tiles; null for none.
  final Widget? separator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _separated([
        for (final key in appearanceSectionKeys)
          ListTile(
            title: Text(appearanceSectionDisplayName(context, key)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSectionTap(key),
          ),
      ], separator),
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile({required this.mode, required this.selected});

  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (icon, name) = switch (mode) {
      ThemeMode.system => (
        Icons.brightness_auto,
        l10n.settings_appearance_theme_system,
      ),
      ThemeMode.light => (
        Icons.light_mode,
        l10n.settings_appearance_theme_light,
      ),
      ThemeMode.dark => (Icons.dark_mode, l10n.settings_appearance_theme_dark),
    };

    return Semantics(
      selected: selected,
      child: ListTile(
        leading: Icon(icon),
        title: Text(name),
        trailing: selected
            ? Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: l10n.settings_language_selected,
              )
            : null,
        onTap: () => ref.read(settingsProvider.notifier).setThemeMode(mode),
      ),
    );
  }
}

String _currentThemeName(BuildContext context, String presetId) {
  final l10n = context.l10n;
  final nameKey = AppThemeRegistry.findById(presetId).nameKey;
  return switch (nameKey) {
    'theme_submersion' => l10n.theme_submersion,
    'theme_console' => l10n.theme_console,
    'theme_tropical' => l10n.theme_tropical,
    'theme_minimalist' => l10n.theme_minimalist,
    'theme_deep' => l10n.theme_deep,
    _ => nameKey,
  };
}

String _mapStyleName(BuildContext context, MapStyle style) {
  final l10n = context.l10n;
  return switch (style) {
    MapStyle.openStreetMap => l10n.settings_appearance_mapStyle_openStreetMap,
    MapStyle.openTopoMap => l10n.settings_appearance_mapStyle_openTopoMap,
    MapStyle.esriSatellite => l10n.settings_appearance_mapStyle_esriSatellite,
  };
}
