import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/first_day_of_week_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_value_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Units page row for the first day of the week (issue #4232).
///
/// Automatic names the day it currently resolves to, read from the Material
/// localizations every week in the app is laid out with, so the row always
/// shows the week the diver actually sees.
class FirstDayOfWeekTile extends ConsumerWidget {
  const FirstDayOfWeekTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingsProvider.select((s) => s.firstDayOfWeek));
    final l10n = context.l10n;
    return SettingsValueTile(
      title: l10n.settings_units_firstDayOfWeek,
      value: firstDayOfWeekSummary(l10n, setting, _shownWeekday(context)),
      onTap: () => showFirstDayOfWeekPicker(context, ref, setting),
    );
  }
}

/// The first day of the week the app currently lays weeks out with.
int _shownWeekday(BuildContext context) => weekdayFromMaterialIndex(
  MaterialLocalizations.of(context).firstDayOfWeekIndex,
);

/// Opens the first-day-of-week picker.
void showFirstDayOfWeekPicker(
  BuildContext context,
  WidgetRef ref,
  FirstDayOfWeek current,
) {
  final l10n = context.l10n;
  unawaited(
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_units_dialog_firstDayOfWeek),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in FirstDayOfWeek.values)
              ListTile(
                title: Text(firstDayOfWeekLabel(l10n, option)),
                subtitle: option == FirstDayOfWeek.auto
                    ? Text(l10n.settings_units_firstDayOfWeek_auto_subtitle)
                    : null,
                trailing: option == current
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(
                    ref
                        .read(settingsProvider.notifier)
                        .setFirstDayOfWeek(option),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}
