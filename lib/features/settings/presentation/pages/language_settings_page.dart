import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/constants/place_name_language.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/place_name_language_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  static const supportedLocales = [
    LocaleOption(code: 'system', nativeName: 'System Default', englishName: ''),
    LocaleOption(code: 'en', nativeName: 'English', englishName: 'English'),
    LocaleOption(code: 'es', nativeName: 'Español', englishName: 'Spanish'),
    LocaleOption(code: 'fr', nativeName: 'Français', englishName: 'French'),
    LocaleOption(code: 'de', nativeName: 'Deutsch', englishName: 'German'),
    LocaleOption(code: 'it', nativeName: 'Italiano', englishName: 'Italian'),
    LocaleOption(code: 'nl', nativeName: 'Nederlands', englishName: 'Dutch'),
    LocaleOption(
      code: 'pt',
      nativeName: 'Português',
      englishName: 'Portuguese',
    ),
    LocaleOption(code: 'hu', nativeName: 'Magyar', englishName: 'Hungarian'),
    LocaleOption(
      code: 'ar',
      nativeName: '\u0627\u0644\u0639\u0631\u0628\u064A\u0629',
      englishName: 'Arabic',
    ),
    LocaleOption(
      code: 'he',
      nativeName: '\u05E2\u05D1\u05E8\u05D9\u05EA',
      englishName: 'Hebrew',
    ),
    LocaleOption(
      code: 'zh',
      nativeName: '简体中文',
      englishName: 'Chinese (Simplified)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_language_appBar_title)),
      body: ListView(children: const [LanguageOptionTiles()]),
    );
  }

  static String getDisplayName(AppLocalizations l10n, String localeCode) {
    final option = supportedLocales.firstWhere(
      (o) => o.code == localeCode,
      orElse: () => supportedLocales.first,
    );
    if (option.code == 'system') return l10n.settings_language_systemDefault;
    return option.nativeName;
  }
}

/// The language choices, one row per [LanguageSettingsPage.supportedLocales]
/// entry. Shared by [LanguageSettingsPage], pushed on a phone, and the inline
/// language list of the tablet and desktop settings pane, so the two cannot
/// drift apart (#3095).
class LanguageOptionTiles extends ConsumerStatefulWidget {
  const LanguageOptionTiles({super.key});

  @override
  ConsumerState<LanguageOptionTiles> createState() =>
      _LanguageOptionTilesState();
}

class _LanguageOptionTilesState extends ConsumerState<LanguageOptionTiles> {
  /// True while a selection saves and its place name offer is open. A tap on
  /// another row before the offer appears would start a second flow, whose
  /// answer could leave place names in a language the app no longer uses.
  bool _selecting = false;

  Future<void> _onSelect(String code) async {
    if (_selecting) return;
    _selecting = true;
    try {
      await _selectLanguage(context, ref, code);
    } finally {
      _selecting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final option in LanguageSettingsPage.supportedLocales)
          Semantics(
            selected: option.code == currentLocale,
            child: ListTile(
              leading: option.code == 'system'
                  ? const Icon(Icons.phone_android)
                  : null,
              title: Text(
                option.code == 'system'
                    ? context.l10n.settings_language_systemDefault
                    : option.nativeName,
              ),
              subtitle: option.englishName.isNotEmpty
                  ? Text(option.englishName)
                  : null,
              // No semanticLabel: Semantics(selected) above already
              // announces the row as selected.
              trailing: option.code == currentLocale
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () => unawaited(_onSelect(option.code)),
            ),
          ),
      ],
    );
  }
}

/// Saves [code] as the app language and, when place names are stored in a
/// different language, offers to switch them too.
///
/// Without the offer a diver who changes the app language keeps getting
/// countries and regions in the old one (issue #3111). Switching also offers
/// to look the stored sites up again, as the place name setting itself does,
/// so the logbook is not split across two spellings (issue #1187).
Future<void> _selectLanguage(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  final notifier = ref.read(settingsProvider.notifier);
  final previous = ref.read(localeProvider);
  await notifier.setLocale(code);
  if (code == previous || !context.mounted) return;

  final current = ref.read(placeNameLanguageProvider);
  final target = PlaceNameLanguage.forAppLocale(
    code,
    WidgetsBinding.instance.platformDispatcher.locales.map(
      (locale) => locale.languageCode,
    ),
  );
  if (target == current) return;

  final currentLabel = placeNameLanguageLabel(current);
  final targetLabel = placeNameLanguageLabel(target);
  final switchLanguage = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return AlertDialog(
        title: Text(l10n.settings_language_placeNameOffer_title(targetLabel)),
        content: Text(
          l10n.settings_language_placeNameOffer_body(currentLabel, targetLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.settings_language_placeNameOffer_keep(currentLabel),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_language_placeNameOffer_switch),
          ),
        ],
      );
    },
  );
  if (switchLanguage != true || !context.mounted) return;

  await notifier.setPlaceNameLanguage(target);
  if (!context.mounted) return;
  await showSiteLocationBackfillFlow(
    context,
    ref,
    mode: SiteLocationLookupMode.refreshAll,
  );
}

class LocaleOption {
  final String code;
  final String nativeName;
  final String englishName;

  const LocaleOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}
