import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/providers/set_up_library_probe.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What step 2 does with a library when this device has dives of its own.
enum SetUpLibraryChoice { combine, replace }

/// Combine them (the default) or replace this device's dives by the library
/// (spec 6.4, step 2).
class SetUpLibraryChoices extends StatelessWidget {
  const SetUpLibraryChoices({
    super.key,
    required this.choice,
    required this.onChanged,
  });

  final SetUpLibraryChoice choice;
  final ValueChanged<SetUpLibraryChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RadioGroup<SetUpLibraryChoice>(
        groupValue: choice,
        onChanged: (choice) {
          if (choice != null) onChanged(choice);
        },
        child: Column(
          children: [
            RadioListTile<SetUpLibraryChoice>(
              value: SetUpLibraryChoice.combine,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settings_setUpDevice_sync_combine),
              subtitle: Text(l10n.settings_setUpDevice_sync_combineDetail),
            ),
            RadioListTile<SetUpLibraryChoice>(
              value: SetUpLibraryChoice.replace,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settings_setUpDevice_sync_replace),
              subtitle: Text(l10n.settings_setUpDevice_sync_replaceDetail),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Found your library in {account}, last changed {when} on {device}", or
/// without the device and time where the manifest does not say them.
String setUpFoundSentence(
  AppLocalizations l10n,
  String accountLabel,
  LibraryFound found,
) {
  final device = found.deviceName?.trim();
  final at = found.changedAt;
  if (device == null || device.isEmpty || at == null) {
    return l10n.settings_setUpDevice_sync_foundPlain(accountLabel);
  }
  final now = DateTime.now();
  // Mid-sentence, so "just now" is lowercase, as in the Data rows.
  final when = now.difference(at).inMinutes < 1
      ? l10n.settings_data_time_justNow
      : relativeAgo(l10n, at, now);
  return l10n.settings_setUpDevice_sync_found(accountLabel, when, device);
}
