import 'package:flutter/material.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Language options offered by the wizard. Codes must stay in sync with
/// AppLocalizations.supportedLocales; names render in their own language.
class _LocaleOption {
  final String code;
  final String nativeName;

  const _LocaleOption(this.code, this.nativeName);
}

const _localeOptions = <_LocaleOption>[
  _LocaleOption('system', ''),
  _LocaleOption('en', 'English'),
  _LocaleOption('es', 'Espanol'),
  _LocaleOption('fr', 'Francais'),
  _LocaleOption('de', 'Deutsch'),
  _LocaleOption('it', 'Italiano'),
  _LocaleOption('nl', 'Nederlands'),
  _LocaleOption('pt', 'Portugues'),
  _LocaleOption('hu', 'Magyar'),
  _LocaleOption('ar', 'العربية'),
  _LocaleOption('he', 'עברית'),
  _LocaleOption('zh', '简体中文'),
];

/// Theme mode, color theme, map style, and language.
class AppearanceStep extends ConsumerWidget {
  final SetupWizardMode mode;

  const AppearanceStep({super.key, required this.mode});

  String _presetName(AppLocalizations l10n, String nameKey) {
    switch (nameKey) {
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
        return nameKey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final draft = ref.watch(setupWizardProvider(mode));
    final notifier = ref.read(setupWizardProvider(mode).notifier);
    final s = draft.settings;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_appearance_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_appearance_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          sectionLabel(l10n.setup_appearance_theme),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.setup_appearance_themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.setup_appearance_themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.setup_appearance_themeDark),
              ),
            ],
            selected: {s.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (sel) =>
                notifier.updateSettings(s.copyWith(themeMode: sel.first)),
          ),
          sectionLabel(l10n.setup_appearance_themePreset),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in AppThemeRegistry.presets)
                ChoiceChip(
                  label: Text(_presetName(l10n, preset.nameKey)),
                  selected: s.themePresetId == preset.id,
                  onSelected: (_) => notifier.updateSettings(
                    s.copyWith(themePresetId: preset.id),
                  ),
                ),
            ],
          ),
          sectionLabel(l10n.setup_appearance_mapStyle),
          SegmentedButton<MapStyle>(
            segments: [
              ButtonSegment(
                value: MapStyle.openStreetMap,
                label: Text(l10n.setup_appearance_mapStyle_openStreetMap),
              ),
              ButtonSegment(
                value: MapStyle.openTopoMap,
                label: Text(l10n.setup_appearance_mapStyle_openTopoMap),
              ),
              ButtonSegment(
                value: MapStyle.esriSatellite,
                label: Text(l10n.setup_appearance_mapStyle_esriSatellite),
              ),
            ],
            selected: {s.mapStyle},
            showSelectedIcon: false,
            onSelectionChanged: (sel) =>
                notifier.updateSettings(s.copyWith(mapStyle: sel.first)),
          ),
          sectionLabel(l10n.setup_appearance_language),
          DropdownButtonFormField<String>(
            key: const ValueKey('setup-language'),
            initialValue: s.locale,
            items: [
              for (final option in _localeOptions)
                DropdownMenuItem(
                  value: option.code,
                  child: Text(
                    option.code == 'system'
                        ? l10n.setup_appearance_themeSystem
                        : option.nativeName,
                  ),
                ),
            ],
            onChanged: (code) {
              if (code == null) return;
              notifier.updateSettings(s.copyWith(locale: code));
              ref.read(previewLocaleProvider.notifier).state = code == 'system'
                  ? null
                  : code;
            },
          ),
        ],
      ),
    );
  }
}
