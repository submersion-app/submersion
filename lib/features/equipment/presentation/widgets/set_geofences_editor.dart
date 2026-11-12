import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/helpers/staged_geofences.dart';
import 'package:submersion/features/equipment/presentation/widgets/geofence_editor_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The set form's Geofences section: the staged [fences], each opening the
/// geofence editor to change it or removed with its close button, and an
/// Add button. Every change is handed to [onChanged]; nothing is saved here,
/// the set's save reconciles the list. [setId] is the set the fences belong
/// to, empty for a set not saved yet.
class SetGeofencesEditor extends ConsumerWidget {
  final List<EquipmentSetGeofence> fences;
  final String setId;
  final ValueChanged<List<EquipmentSetGeofence>> onChanged;

  const SetGeofencesEditor({
    super.key,
    required this.fences,
    required this.setId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.equipment_setEdit_geofencesTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.equipment_setEdit_geofencesSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < fences.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(
              fences[i].label ?? context.l10n.equipment_geofenceEditor_title,
            ),
            subtitle: Text(
              context.l10n.equipment_setEdit_geofenceRadius(
                formatter.formatGeoDistance(fences[i].radiusMeters),
              ),
            ),
            onTap: () => _edit(context, i),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.equipment_setEdit_removeGeofence,
              onPressed: () => onChanged(withoutGeofence(fences, i)),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(context.l10n.equipment_setEdit_addGeofence),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final draft = await showGeofenceEditor(context);
    if (draft == null || !context.mounted) return;
    onChanged(withAddedGeofence(fences, draft, setId: setId));
  }

  /// Opens the editor seeded from the staged fence at [index] and replaces
  /// it in place with the returned draft (see [withEditedGeofence]).
  Future<void> _edit(BuildContext context, int index) async {
    final existing = fences[index];
    final draft = await showGeofenceEditor(
      context,
      initial: GeofenceDraft(
        latitude: existing.latitude,
        longitude: existing.longitude,
        label: existing.label,
        radiusMeters: existing.radiusMeters,
      ),
    );
    if (draft == null || !context.mounted) return;
    onChanged(withEditedGeofence(fences, index, draft));
  }
}
