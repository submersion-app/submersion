import 'package:flutter/material.dart';

import 'package:submersion/core/constants/place_name_language.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The place name language picker (issue #1187), split out of
/// `settings_page.dart` so it can be pumped directly in tests.
///
/// The options are the app's own languages minus "System Default": the value
/// must resolve to the same code on every one of the diver's devices, which
/// a device-dependent choice cannot promise.

/// Opens the place name language picker.
void showPlaceNameLanguagePicker(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        AppLocalizations.of(context).settings_placeNameLanguage_title,
      ),
      content: PlaceNameLanguageList(
        selected: settings.placeNameLanguage,
        onSelected: (code) {
          Navigator.of(dialogContext).pop();
          ref.read(settingsProvider.notifier).setPlaceNameLanguage(code);
        },
      ),
    ),
  );
}

/// The supported languages, each by its native name.
class PlaceNameLanguageList extends StatelessWidget {
  const PlaceNameLanguageList({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final void Function(String code) onSelected;

  @override
  Widget build(BuildContext context) {
    // A Column rather than a lazy ListView: eleven rows are cheap, and every
    // option then exists in the tree, which keeps the picker testable.
    return SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in PlaceNameLanguage.supportedCodes)
              ListTile(
                title: Text(placeNameLanguageLabel(code)),
                trailing: code == selected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => onSelected(code),
              ),
          ],
        ),
      ),
    );
  }
}

/// The native name of a language code, from the app language list, so there
/// is no second hand-maintained list of names.
String placeNameLanguageLabel(String code) {
  for (final option in LanguageSettingsPage.supportedLocales) {
    if (option.code == code) return option.nativeName;
  }
  return code;
}
