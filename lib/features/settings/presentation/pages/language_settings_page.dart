import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class LanguageSettingsPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_language_appBar_title)),
      body: ListView.builder(
        itemCount: supportedLocales.length,
        itemBuilder: (context, index) {
          final option = supportedLocales[index];
          final isSelected = option.code == currentLocale;

          return Semantics(
            selected: isSelected,
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
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: theme.colorScheme.primary,
                      semanticLabel: context.l10n.settings_language_selected,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLocale(option.code);
              },
            ),
          );
        },
      ),
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
