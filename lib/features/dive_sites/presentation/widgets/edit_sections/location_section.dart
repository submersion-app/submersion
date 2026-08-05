import 'package:flutter/material.dart';

import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site group 2: latitude/longitude rows, locate/pick actions, altitude
/// row with the altitude-group indicator.
class LocationSection extends StatelessWidget {
  const LocationSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    this.errorCount = 0,
    required this.latitudeController,
    required this.longitudeController,
    required this.altitudeController,
    required this.latValidator,
    required this.lonValidator,
    required this.altitudeValidator,
    required this.isGettingLocation,
    required this.onUseMyLocation,
    required this.onPickFromMap,
    required this.units,
    this.coordinatesExtras,
    this.altitudeExtras,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final int errorCount;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController altitudeController;
  final String? Function(String?) latValidator;
  final String? Function(String?) lonValidator;
  final String? Function(String?) altitudeValidator;
  final bool isGettingLocation;
  final VoidCallback onUseMyLocation;
  final VoidCallback onPickFromMap;
  final UnitFormatter units;
  final MergeFieldExtras? coordinatesExtras;
  final MergeFieldExtras? altitudeExtras;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_location,
      icon: Icons.place_outlined,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_location,
      errorCount: errorCount,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (coordinatesExtras != null)
              MergeSourceRow(
                sourceLabel: coordinatesExtras!.sourceLabel,
                onCycle: coordinatesExtras!.onCycle,
              ),
            FormRow.text(
              label: l10n.diveSites_edit_gps_latitude_label,
              controller: latitudeController,
              placeholder: l10n.diveSites_edit_gps_latitude_hint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: latValidator,
            ),
            FormRow.text(
              label: l10n.diveSites_edit_gps_longitude_label,
              controller: longitudeController,
              placeholder: l10n.diveSites_edit_gps_longitude_hint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: lonValidator,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: isGettingLocation ? null : onUseMyLocation,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(
                      isGettingLocation
                          ? l10n.diveSites_edit_gps_gettingLocation
                          : l10n.diveSites_edit_gps_useMyLocation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: onPickFromMap,
                    icon: const Icon(Icons.map, size: 16),
                    label: Text(l10n.diveSites_edit_gps_pickFromMap),
                  ),
                ],
              ),
            ),
          ],
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: altitudeController,
          builder: (context, altitude, _) {
            final altitudeInput = double.tryParse(altitude.text);
            final altitudeMeters = altitudeInput != null
                ? units.altitudeToMeters(altitudeInput)
                : null;
            final group = AltitudeGroup.fromAltitude(altitudeMeters);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (altitudeExtras != null)
                  MergeSourceRow(
                    sourceLabel: altitudeExtras!.sourceLabel,
                    onCycle: altitudeExtras!.onCycle,
                  ),
                FormRow.text(
                  label: l10n.diveSites_edit_section_altitude,
                  controller: altitudeController,
                  suffixText: units.altitudeSymbol,
                  placeholder: l10n.diveSites_edit_altitude_hint,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: altitudeValidator,
                ),
                if (group != AltitudeGroup.seaLevel && altitudeMeters != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: _altitudeGroupIndicator(context, group),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Widget _altitudeGroupIndicator(BuildContext context, AltitudeGroup group) {
  final colorScheme = Theme.of(context).colorScheme;

  Color backgroundColor;
  Color foregroundColor;
  IconData icon;

  switch (group.warningLevel) {
    case AltitudeWarningLevel.none:
      backgroundColor = colorScheme.surfaceContainerHighest;
      foregroundColor = colorScheme.onSurface;
      icon = Icons.check_circle_outline;
    case AltitudeWarningLevel.info:
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.onPrimaryContainer;
      icon = Icons.info_outline;
    case AltitudeWarningLevel.caution:
      backgroundColor = colorScheme.tertiaryContainer;
      foregroundColor = colorScheme.onTertiaryContainer;
      icon = Icons.warning_amber;
    case AltitudeWarningLevel.warning:
      backgroundColor = colorScheme.errorContainer;
      foregroundColor = colorScheme.onErrorContainer;
      icon = Icons.warning;
    case AltitudeWarningLevel.severe:
      backgroundColor = colorScheme.error;
      foregroundColor = colorScheme.onError;
      icon = Icons.dangerous;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: foregroundColor),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.displayName,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                group.rangeDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foregroundColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
