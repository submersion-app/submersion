import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the user confirm which CSV column holds which field.
///
/// CSV has no schema, so [guessCsvMapping]'s proposal is shown for
/// confirmation rather than applied silently.
class CsvColumnMappingForm extends StatelessWidget {
  const CsvColumnMappingForm({
    super.key,
    required this.headers,
    required this.mapping,
    required this.onChanged,
  });

  final List<String> headers;
  final CsvColumnMapping mapping;
  final ValueChanged<CsvColumnMapping> onChanged;

  Widget _dropdown({
    required String label,
    required int? value,
    required ValueChanged<int?> onSelected,
    required Key key,
    bool allowNone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        key: key,
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          if (allowNone) const DropdownMenuItem(child: Text('-')),
          for (var i = 0; i < headers.length; i++)
            DropdownMenuItem(value: i, child: Text(headers[i])),
        ],
        onChanged: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gpsTrack_import_csvMapping,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _dropdown(
          key: const ValueKey('csv-map-time'),
          label: l10n.diveLog_tooltip_time,
          value: mapping.timeIndex,
          onSelected: (v) {
            // Required column: _dropdown omits the "-" item unless allowNone,
            // so v is never null here. Ignoring it keeps the last valid
            // choice rather than writing a mapping that cannot be parsed.
            // The optional accuracy column below deliberately does pass null
            // through, so the diver can un-map it.
            if (v == null) return;
            onChanged(
              CsvColumnMapping(
                timeIndex: v,
                latIndex: mapping.latIndex,
                lonIndex: mapping.lonIndex,
                accuracyIndex: mapping.accuracyIndex,
              ),
            );
          },
        ),
        _dropdown(
          key: const ValueKey('csv-map-lat'),
          label: l10n.diveCenters_field_latitude,
          value: mapping.latIndex,
          onSelected: (v) {
            if (v == null) return;
            onChanged(
              CsvColumnMapping(
                timeIndex: mapping.timeIndex,
                latIndex: v,
                lonIndex: mapping.lonIndex,
                accuracyIndex: mapping.accuracyIndex,
              ),
            );
          },
        ),
        _dropdown(
          key: const ValueKey('csv-map-lon'),
          label: l10n.diveCenters_field_longitude,
          value: mapping.lonIndex,
          onSelected: (v) {
            if (v == null) return;
            onChanged(
              CsvColumnMapping(
                timeIndex: mapping.timeIndex,
                latIndex: mapping.latIndex,
                lonIndex: v,
                accuracyIndex: mapping.accuracyIndex,
              ),
            );
          },
        ),
        _dropdown(
          key: const ValueKey('csv-map-accuracy'),
          label: l10n.gpsTrack_inspect_accuracy,
          value: mapping.accuracyIndex,
          allowNone: true,
          onSelected: (v) => onChanged(
            CsvColumnMapping(
              timeIndex: mapping.timeIndex,
              latIndex: mapping.latIndex,
              lonIndex: mapping.lonIndex,
              accuracyIndex: v,
            ),
          ),
        ),
      ],
    );
  }
}
