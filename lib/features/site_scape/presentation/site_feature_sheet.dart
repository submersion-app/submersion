import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the sheet hands back to its caller. Null (a dismissed sheet)
/// means "write nothing".
sealed class SiteFeatureSheetResult {
  const SiteFeatureSheetResult();
}

/// The edited draft. Depth is METRIC regardless of the diver's unit.
class SiteFeatureSheetSave extends SiteFeatureSheetResult {
  final String typeName;
  final String name;
  final double? bearingDeg;
  final double? depthMeters;
  final String notes;

  const SiteFeatureSheetSave({
    required this.typeName,
    required this.name,
    required this.bearingDeg,
    required this.depthMeters,
    required this.notes,
  });
}

/// The diver confirmed deletion of the edited feature.
class SiteFeatureSheetDelete extends SiteFeatureSheetResult {
  const SiteFeatureSheetDelete();
}

/// The localized label for a stored type name; an unknown name (a type
/// from a newer app version) shows as-is rather than vanishing.
String siteFeatureTypeLabel(AppLocalizations l10n, String typeName) {
  return switch (SiteFeatureType.values.asNameMap()[typeName]) {
    SiteFeatureType.wreck => l10n.siteFeature_type_wreck,
    SiteFeatureType.mooring => l10n.siteFeature_type_mooring,
    SiteFeatureType.entry => l10n.siteFeature_type_entry,
    SiteFeatureType.exit => l10n.siteFeature_type_exit,
    SiteFeatureType.swimThrough => l10n.siteFeature_type_swimThrough,
    SiteFeatureType.hazard => l10n.siteFeature_type_hazard,
    SiteFeatureType.current => l10n.siteFeature_type_current,
    null => typeName,
  };
}

/// Opens the add/edit sheet. [existing] null is the add flow, where
/// [initialDepthMeters] pre-fills the depth sampled from bathymetry.
Future<SiteFeatureSheetResult?> showSiteFeatureSheet(
  BuildContext context, {
  SiteFeature? existing,
  double? initialDepthMeters,
}) {
  return showModalBottomSheet<SiteFeatureSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The inset padding reads the SHEET's context, not the caller's, so it
    // tracks the keyboard as it opens instead of freezing at the value
    // captured when the sheet was requested.
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SiteFeatureSheet(
            existing: existing,
            initialDepthMeters: initialDepthMeters,
          ),
        ),
      ),
    ),
  );
}

/// Add/edit form for one site feature. Depth is shown and typed in the
/// diver's unit and converted to meters on the way out.
class SiteFeatureSheet extends ConsumerStatefulWidget {
  final SiteFeature? existing;
  final double? initialDepthMeters;

  const SiteFeatureSheet({super.key, this.existing, this.initialDepthMeters});

  @override
  ConsumerState<SiteFeatureSheet> createState() => _SiteFeatureSheetState();
}

class _SiteFeatureSheetState extends ConsumerState<SiteFeatureSheet> {
  late String _typeName =
      widget.existing?.typeName ?? SiteFeatureType.wreck.name;
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _bearing = TextEditingController(
    text: _formatNumber(widget.existing?.bearingDeg),
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes ?? '',
  );
  TextEditingController? _depth;

  /// Seeded with the diver's decimal separator so the sheet can read the value
  /// back; the seed and the parse must share one convention (#1091).
  static String _formatNumber(double? v) =>
      v == null ? '' : formatRoundedForInput(v, 1);

  @override
  void dispose() {
    _name.dispose();
    _bearing.dispose();
    _notes.dispose();
    _depth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;
    final meters = widget.existing?.depthMeters ?? widget.initialDepthMeters;
    _depth ??= TextEditingController(
      text: meters == null ? '' : _formatNumber(meters / unitInMeters),
    );
    final existing = widget.existing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existing == null
                ? l10n.siteFeature_addTitle
                : l10n.siteFeature_editTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('siteFeatureTypeField'),
            initialValue:
                SiteFeatureType.values.asNameMap().containsKey(_typeName)
                ? _typeName
                : null,
            // An unknown stored type has no dropdown entry; show the raw
            // name as the hint so saving without touching it keeps it.
            hint: Text(_typeName),
            items: [
              for (final t in SiteFeatureType.values)
                DropdownMenuItem(
                  value: t.name,
                  child: Text(siteFeatureTypeLabel(l10n, t.name)),
                ),
            ],
            onChanged: (v) => setState(() => _typeName = v ?? _typeName),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('siteFeatureNameField'),
            controller: _name,
            initialValue: null,
            decoration: InputDecoration(labelText: l10n.siteFeature_field_name),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('siteFeatureBearingField'),
                  controller: _bearing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.siteFeature_field_bearing,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('siteFeatureDepthField'),
                  controller: _depth,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${l10n.siteFeature_field_depth} (${depthUnit.symbol})',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('siteFeatureNotesField'),
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.siteFeature_field_notes,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (existing != null)
                TextButton.icon(
                  key: const ValueKey('siteFeatureDeleteButton'),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.siteFeature_deleteAction),
                  onPressed: () => _confirmDelete(context, existing),
                ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('siteFeatureSaveButton'),
                onPressed: () => _save(context, unitInMeters),
                child: Text(l10n.common_action_save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context, double unitInMeters) {
    // Read in the diver's locale, matching _formatNumber. A blanket
    // replaceAll(',', '.') would misread the en_US thousands separator,
    // turning "1,250" into 1.25 (#1091).
    final bearing = parseUserDecimal(_bearing.text);
    final depth = parseUserDecimal(_depth!.text);
    Navigator.of(context).pop(
      SiteFeatureSheetSave(
        typeName: _typeName,
        name: _name.text.trim(),
        // Dart's % is euclidean (always non-negative for a positive
        // divisor), so -10 normalizes to 350, not -10.
        bearingDeg: bearing == null ? null : bearing % 360,
        depthMeters: depth == null ? null : depth * unitInMeters,
        notes: _notes.text.trim(),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SiteFeature existing,
  ) async {
    final l10n = context.l10n;
    final label = existing.name.isNotEmpty
        ? existing.name
        : siteFeatureTypeLabel(l10n, existing.typeName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.siteFeature_deleteConfirm(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('siteFeatureDeleteConfirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.siteFeature_deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop(const SiteFeatureSheetDelete());
  }
}
