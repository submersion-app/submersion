import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Result of the geofence editor: a center + radius (+ optional label).
class GeofenceDraft {
  final double latitude;
  final double longitude;
  final String? label;
  final double radiusMeters;

  const GeofenceDraft({
    required this.latitude,
    required this.longitude,
    this.label,
    required this.radiusMeters,
  });
}

/// Opens the geofence editor and returns the draft, or null if cancelled.
Future<GeofenceDraft?> showGeofenceEditor(
  BuildContext context, {
  GeofenceDraft? initial,
}) {
  return showModalBottomSheet<GeofenceDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _GeofenceEditorSheet(initial: initial),
  );
}

class _GeofenceEditorSheet extends ConsumerStatefulWidget {
  final GeofenceDraft? initial;
  const _GeofenceEditorSheet({this.initial});

  @override
  ConsumerState<_GeofenceEditorSheet> createState() =>
      _GeofenceEditorSheetState();
}

class _GeofenceEditorSheetState extends ConsumerState<_GeofenceEditorSheet> {
  double? _latitude;
  double? _longitude;
  double _radiusMeters = 15000;
  String? _selectedSiteId;
  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _latitude = widget.initial?.latitude;
    _longitude = widget.initial?.longitude;
    _radiusMeters = widget.initial?.radiusMeters ?? 15000;
    _labelController.text = widget.initial?.label ?? '';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _dropPin() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerMap(
          initialLocation: _latitude != null && _longitude != null
              ? LatLng(_latitude!, _longitude!)
              : null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedSiteId = null;
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (_labelController.text.isEmpty) {
          _labelController.text = result.locality ?? result.region ?? '';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final formatter = UnitFormatter(settings);
    final sitesAsync = ref.watch(sitesProvider);
    final hasCenter = _latitude != null && _longitude != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.equipment_geofenceEditor_title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          sitesAsync.maybeWhen(
            data: (sites) {
              final withCoords = sites.where((s) => s.hasCoordinates).toList();
              if (withCoords.isEmpty) return const SizedBox.shrink();
              return DropdownButtonFormField<String>(
                initialValue: _selectedSiteId,
                decoration: InputDecoration(
                  labelText: context.l10n.equipment_geofenceEditor_fromSite,
                ),
                items: [
                  for (final s in withCoords)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final site = withCoords.firstWhere((s) => s.id == id);
                  setState(() {
                    _selectedSiteId = id;
                    _latitude = site.location!.latitude;
                    _longitude = site.location!.longitude;
                    if (_labelController.text.isEmpty) {
                      _labelController.text = site.name;
                    }
                  });
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _dropPin,
            icon: const Icon(Icons.map_outlined),
            label: Text(context.l10n.equipment_geofenceEditor_dropPin),
          ),
          const SizedBox(height: 8),
          Text(
            hasCenter
                ? '${_latitude!.toStringAsFixed(5)}, '
                      '${_longitude!.toStringAsFixed(5)}'
                : context.l10n.equipment_geofenceEditor_noCenter,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_geofenceEditor_labelLabel,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.equipment_setEdit_geofenceRadius(
              formatter.formatGeoDistance(_radiusMeters),
            ),
          ),
          Slider(
            min: 500,
            max: 100000,
            value: _radiusMeters,
            onChanged: (v) => setState(() => _radiusMeters = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: hasCenter
                  ? () => Navigator.of(context).pop(
                      GeofenceDraft(
                        latitude: _latitude!,
                        longitude: _longitude!,
                        label: _labelController.text.trim().isEmpty
                            ? null
                            : _labelController.text.trim(),
                        radiusMeters: _radiusMeters,
                      ),
                    )
                  : null,
              child: Text(context.l10n.equipment_geofenceEditor_save),
            ),
          ),
        ],
      ),
    );
  }
}
