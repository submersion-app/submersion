import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/coordinate_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The GPS coordinate notation picker, split out of `settings_page.dart` so it
/// can be pumped directly in tests and so that file stops growing.
///
/// The notation is purely presentational: coordinates are stored as decimal
/// degrees, so changing it re-renders every site without altering a single
/// stored value.

/// A recognizable reef, so the worked examples read as a real position rather
/// than as test data. Palancar, Cozumel.
const double _sampleLatitude = 20.361944;
const double _sampleLongitude = -87.029722;

/// Opens the coordinate format picker.
void showCoordinateFormatPicker(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.of(context).settings_coordinateFormat_title),
      content: CoordinateFormatList(
        selected: settings.coordinateFormat,
        onSelected: (format) {
          Navigator.of(dialogContext).pop();
          ref.read(settingsProvider.notifier).setCoordinateFormat(format);
        },
      ),
    ),
  );
}

/// The list of formats, each showing the same sample point in its own
/// notation.
///
/// The worked example is what makes the choice legible: a diver who does not
/// know "MGRS" by name still recognizes the shape of the reference they read
/// off their chart.
class CoordinateFormatList extends StatelessWidget {
  const CoordinateFormatList({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CoordinateFormat selected;
  final void Function(CoordinateFormat) onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 360,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final format in CoordinateFormat.values)
            ListTile(
              title: Text(coordinateFormatLabel(l10n, format)),
              subtitle: Text(
                formatCoordinates(_sampleLatitude, _sampleLongitude, format),
              ),
              trailing: format == selected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => onSelected(format),
            ),
        ],
      ),
    );
  }
}

/// The localized name of a coordinate format.
String coordinateFormatLabel(AppLocalizations l10n, CoordinateFormat format) {
  switch (format) {
    case CoordinateFormat.decimalDegrees:
      return l10n.settings_coordinateFormat_decimalDegrees;
    case CoordinateFormat.degreesDecimalMinutes:
      return l10n.settings_coordinateFormat_degreesDecimalMinutes;
    case CoordinateFormat.degreesMinutesSeconds:
      return l10n.settings_coordinateFormat_degreesMinutesSeconds;
    case CoordinateFormat.utm:
      return l10n.settings_coordinateFormat_utm;
    case CoordinateFormat.mgrs:
      return l10n.settings_coordinateFormat_mgrs;
  }
}
