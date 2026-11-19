import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_card_editor.dart'
    show pickSiteLocationOnMap;
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/coordinate_field_group.dart';
import 'package:submersion/shared/widgets/forms/coordinate_validation_messages.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Picks a place on a map, starting at [initial]: a seam, so a test can
/// answer for the map.
typedef DiveCenterLocationPicker =
    Future<PickedLocation?> Function(BuildContext context, LatLng? initial);

/// The dive centre Map card's editor (issue #4527, phase 3): where the
/// centre is, typed, from the diver's own position, picked on a map, or
/// looked up from its address, as the form's GPS section has it.
///
/// Both coordinates are one value: a pair typed half way, or one that is
/// not a number, changes nothing until it reads as a place, and the
/// coordinates' error says so.
class DiveCenterMapCardEditor extends ConsumerStatefulWidget {
  const DiveCenterMapCardEditor({
    super.key,
    required this.session,
    this.pickLocation = pickSiteLocationOnMap,
  });

  final EditSession<DiveCenter> session;
  final DiveCenterLocationPicker pickLocation;

  @override
  ConsumerState<DiveCenterMapCardEditor> createState() =>
      _DiveCenterMapCardEditorState();
}

class _DiveCenterMapCardEditorState
    extends ConsumerState<DiveCenterMapCardEditor> {
  EditSession<DiveCenter> get _session => widget.session;

  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  bool _busy = false;

  /// Set while this editor writes the text, so its own listener lets it be.
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _showStored();
    _session.addListener(_showStored);
    _latitude.addListener(_onTyped);
    _longitude.addListener(_onTyped);
  }

  @override
  void dispose() {
    _session.removeListener(_showStored);
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  /// What the text reads as: none when both are blank, a place when both
  /// are numbers, and nothing at all otherwise.
  ({bool readable, DiveCenterCoordinates? value}) _typed() {
    final lat = _latitude.text.trim();
    final lon = _longitude.text.trim();
    if (lat.isEmpty && lon.isEmpty) return (readable: true, value: null);
    final la = double.tryParse(lat);
    final lo = double.tryParse(lon);
    if (la == null || lo == null) return (readable: false, value: null);
    return (readable: true, value: (latitude: la, longitude: lo));
  }

  /// Shows the sitting's coordinates unless the text already reads as them.
  void _showStored() {
    if (_session.isDisposed) return;
    final value = _session.valueOf(diveCenterCoordinatesField);
    final typed = _typed();
    if (typed.readable && typed.value == value) return;
    if (!typed.readable && value == null) return;
    _writing = true;
    _latitude.text = value?.latitude.toStringAsFixed(6) ?? '';
    _longitude.text = value?.longitude.toStringAsFixed(6) ?? '';
    _writing = false;
  }

  void _onTyped() {
    if (_writing) return;
    final typed = _typed();
    if (typed.readable) _session.set(diveCenterCoordinatesField, typed.value);
    setState(() {});
  }

  void _setPlace(double latitude, double longitude) {
    if (_session.isDisposed) return;
    _session.set(diveCenterCoordinatesField, (
      latitude: latitude,
      longitude: longitude,
    ));
  }

  Future<void> _useMyLocation() async {
    final location = ref.read(locationServiceProvider);
    final language = ref.read(placeNameLanguageProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final result = await location.getCurrentLocation(
        includeGeocoding: true,
        languageCode: language,
      );
      if (result == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.diveCenters_error_locationUnavailable)),
        );
        return;
      }
      _setPlace(result.latitude, result.longitude);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromMap() async {
    final value = _session.valueOf(diveCenterCoordinatesField);
    final picked = await widget.pickLocation(
      context,
      value == null ? null : LatLng(value.latitude, value.longitude),
    );
    if (picked != null) _setPlace(picked.latitude, picked.longitude);
  }

  Future<void> _lookUp() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final address = diveCenterAddressLine(_session.working);
    if (address.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveCenters_error_noAddressForLookup)),
      );
      return;
    }
    final location = ref.read(locationServiceProvider);
    setState(() => _busy = true);
    try {
      final result = await location.forwardGeocode(address);
      if (result == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.diveCenters_error_geocodeFailed)),
        );
        return;
      }
      _setPlace(result.latitude, result.longitude);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typed = _typed();
    final value = typed.value;
    final error = !typed.readable
        ? l10n.diveCenters_validation_invalidLatitude
        : diveCenterCoordinateError(l10n, value?.latitude, value?.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.diveCenters_hint_gpsDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _useMyLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(l10n.diveCenters_action_useMyLocation),
            ),
            OutlinedButton.icon(
              key: const ValueKey('dive-center-edit-pick-map'),
              onPressed: _busy ? null : _pickFromMap,
              icon: const Icon(Icons.map, size: 18),
              label: Text(l10n.diveCenters_action_pickFromMap),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _lookUp,
              icon: const Icon(Icons.search, size: 18),
              label: Text(l10n.diveCenters_action_lookupFromAddress),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CoordinateFieldGroup(
          latitudeController: _latitude,
          longitudeController: _longitude,
          format: ref.watch(coordinateFormatProvider),
          latitudeLabel: l10n.diveCenters_field_latitude,
          longitudeLabel: l10n.diveCenters_field_longitude,
          errorText: error,
          messages: CoordinateValidationMessages.of(context),
        ),
      ],
    );
  }
}
