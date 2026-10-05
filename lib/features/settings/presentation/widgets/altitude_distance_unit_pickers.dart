import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The altitude and distance unit pickers on Manage > Units (issue #2030),
/// split out of `settings_page.dart` so that file stops growing.

/// The localized name of an altitude unit.
String altitudeUnitLabel(AppLocalizations l10n, AltitudeUnit unit) =>
    switch (unit) {
      AltitudeUnit.meters => l10n.settings_units_altitude_meters,
      AltitudeUnit.feet => l10n.settings_units_altitude_feet,
    };

/// The localized name of a distance unit.
String distanceUnitLabel(AppLocalizations l10n, DistanceUnit unit) =>
    switch (unit) {
      DistanceUnit.kilometers => l10n.settings_units_distance_kilometers,
      DistanceUnit.miles => l10n.settings_units_distance_miles,
    };

/// Opens the altitude unit picker.
void showAltitudeUnitPicker(
  BuildContext context,
  WidgetRef ref,
  AltitudeUnit current,
) {
  final l10n = AppLocalizations.of(context);
  _showUnitPicker<AltitudeUnit>(
    context,
    title: l10n.settings_units_dialog_altitudeUnit,
    values: AltitudeUnit.values,
    selected: current,
    label: (unit) => altitudeUnitLabel(l10n, unit),
    onSelected: (unit) =>
        ref.read(settingsProvider.notifier).setAltitudeUnit(unit),
  );
}

/// Opens the distance unit picker.
void showDistanceUnitPicker(
  BuildContext context,
  WidgetRef ref,
  DistanceUnit current,
) {
  final l10n = AppLocalizations.of(context);
  _showUnitPicker<DistanceUnit>(
    context,
    title: l10n.settings_units_dialog_distanceUnit,
    values: DistanceUnit.values,
    selected: current,
    label: (unit) => distanceUnitLabel(l10n, unit),
    onSelected: (unit) =>
        ref.read(settingsProvider.notifier).setDistanceUnit(unit),
  );
}

/// The single-choice dialog both pickers use: one row per unit, a check on
/// the selected one, and a tap that saves and closes.
void _showUnitPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T) label,
  required void Function(T) onSelected,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            ListTile(
              title: Text(label(value)),
              trailing: value == selected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                onSelected(value);
                Navigator.of(dialogContext).pop();
              },
            ),
        ],
      ),
    ),
  );
}
