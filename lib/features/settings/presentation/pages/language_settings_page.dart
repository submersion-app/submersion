import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  static const supportedLocales = [
    _LocaleOption(
      code: 'system',
      nativeName: 'System Default',
      englishName: '',
    ),
    _LocaleOption(code: 'en', nativeName: 'English', englishName: 'English'),
    _LocaleOption(code: 'es', nativeName: 'Espanol', englishName: 'Spanish'),
    _LocaleOption(code: 'fr', nativeName: 'Francais', englishName: 'French'),
    _LocaleOption(code: 'de', nativeName: 'Deutsch', englishName: 'German'),
    _LocaleOption(code: 'it', nativeName: 'Italiano', englishName: 'Italian'),
    _LocaleOption(code: 'nl', nativeName: 'Nederlands', englishName: 'Dutch'),
    _LocaleOption(
      code: 'pt',
      nativeName: 'Portugues',
      englishName: 'Portuguese',
    ),
    _LocaleOption(code: 'hu', nativeName: 'Magyar', englishName: 'Hungarian'),
    _LocaleOption(
      code: 'ar',
      nativeName: '\u0627\u0644\u0639\u0631\u0628\u064A\u0629',
      englishName: 'Arabic',
    ),
    _LocaleOption(
      code: 'he',
      nativeName: '\u05E2\u05D1\u05E8\u05D9\u05EA',
      englishName: 'Hebrew',
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

  static String getDisplayName(String localeCode) {
    final option = supportedLocales.firstWhere(
      (o) => o.code == localeCode,
      orElse: () => supportedLocales.first,
    );
    if (option.code == 'system') return 'System Default';
    return option.nativeName;
  }
}

class _LocaleOption {
  final String code;
  final String nativeName;
  final String englishName;

  const _LocaleOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}
