import 'package:flutter/material.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_logo_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_picker.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The agencies a centre can be affiliated with, as the form offers them.
const List<String> diveCenterAffiliationChoices = [
  'PADI',
  'SSI',
  'NAUI',
  'SDI/TDI',
  'GUE',
  'RAID',
  'BSAC',
  'CMAS',
  'FFESSM',
  'IANTD',
  'PSAI',
];

/// The dive centre header block's editor (issue #4527, phase 3): the logo,
/// the name, which is required, the rating, the address, the affiliations
/// and whether it has closed.
///
/// When every address field has lost focus, the centre has no coordinates
/// in the sitting and the address is not blank, it looks them up from the
/// address, as the form does. The lookup is tracked, so a Save waits for
/// it; a lookup that fails or finds nothing sets nothing and says nothing.
class DiveCenterHeaderCardEditor extends ConsumerStatefulWidget {
  const DiveCenterHeaderCardEditor({super.key, required this.session});

  final EditSession<DiveCenter> session;

  @override
  ConsumerState<DiveCenterHeaderCardEditor> createState() =>
      _DiveCenterHeaderCardEditorState();
}

class _DiveCenterHeaderCardEditorState
    extends ConsumerState<DiveCenterHeaderCardEditor> {
  EditSession<DiveCenter> get _session => widget.session;

  late final _name = FieldTextBinding<DiveCenter, String>(
    session: _session,
    field: diveCenterNameField,
    format: (v) => v,
    parse: FieldValue<String>.new,
  );
  late final _street = _bind(diveCenterStreetField);
  late final _city = _bind(diveCenterCityField);
  late final _state = _bind(diveCenterStateProvinceField);
  late final _postal = _bind(diveCenterPostalCodeField);
  late final _country = _bind(diveCenterCountryField);

  final _addressFocus = List.generate(5, (_) => FocusNode());

  FieldTextBinding<DiveCenter, String?> _bind(
    EditField<DiveCenter, String?> field,
  ) => FieldTextBinding<DiveCenter, String?>(
    session: _session,
    field: field,
    format: (v) => v ?? '',
    parse: FieldValue<String?>.new,
  );

  @override
  void initState() {
    super.initState();
    for (final node in _addressFocus) {
      node.addListener(_onAddressFocus);
    }
  }

  @override
  void dispose() {
    for (final node in _addressFocus) {
      node.dispose();
    }
    for (final binding in [_street, _city, _state, _postal, _country]) {
      binding.dispose();
    }
    _name.dispose();
    super.dispose();
  }

  /// Once the address has lost focus, looks up a centre with no coordinates.
  void _onAddressFocus() {
    // Focus also leaves as the card closes or the page goes: no lookup then.
    if (!mounted) return;
    if (_addressFocus.any((node) => node.hasFocus)) return;
    final session = _session;
    if (session.isDisposed || session.isFrozen) return;
    if (session.valueOf(diveCenterCoordinatesField) != null) return;
    final address = diveCenterAddressLine(session.working);
    if (address.isEmpty) return;
    final location = ref.read(locationServiceProvider);
    session.track(() async {
      try {
        final result = await location.forwardGeocode(address);
        if (result == null || session.isDisposed || session.isFrozen) return;
        // The address changed meanwhile: its own lookup answers for it.
        if (diveCenterAddressLine(session.working) != address) return;
        // Coordinates set meanwhile, by the diver or another lookup, stand.
        if (session.valueOf(diveCenterCoordinatesField) != null) return;
        session.set(diveCenterCoordinatesField, (
          latitude: result.latitude,
          longitude: result.longitude,
        ));
      } catch (_) {
        // The automatic lookup says nothing; the Map card looks up on ask.
      }
    }());
  }

  Future<void> _pickLogo() async {
    final result = await pickProfilePhoto(
      context: context,
      hasPhoto: _session.valueOf(diveCenterLogoField) != null,
      // A shop is not in the address book.
      allowContacts: false,
      sheetTitle: context.l10n.diveCenters_field_logo,
    );
    if (result == null || _session.isDisposed) return;
    _session.set(diveCenterLogoField, result.removed ? null : result.bytes);
  }

  Widget _rating(BuildContext context) {
    final rating = _session.valueOf(diveCenterRatingField);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.diveCenters_field_rating),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < 5; index++)
              IconButton(
                key: ValueKey('dive-center-edit-rating-${index + 1}'),
                tooltip: l10n.diveSites_edit_rating_starTooltip(index + 1),
                onPressed: () => _session.set(
                  diveCenterRatingField,
                  rating == index + 1 ? null : (index + 1).toDouble(),
                ),
                icon: Icon(
                  rating != null && index < rating
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
              ),
            if (rating != null)
              TextButton(
                onPressed: () => _session.set(diveCenterRatingField, null),
                child: Text(l10n.diveCenters_action_clearRating),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outline = Theme.of(context).colorScheme.outline;
    InputDecoration field(String label, String hint) =>
        InputDecoration(labelText: label, hintText: hint);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final affiliations = _session.valueOf(diveCenterAffiliationsField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DiveCenterLogoField(
              logo: _session.valueOf(diveCenterLogoField),
              onTap: _pickLogo,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('dive-center-edit-name'),
              controller: _name.controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_field_nameRequired,
                hintText: l10n.diveCenters_hint_name,
                errorText: _session.valueOf(diveCenterNameField).trim().isEmpty
                    ? l10n.diveCenters_validation_nameRequired
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _rating(context),
            const SizedBox(height: 16),
            Text(
              l10n.diveCenters_hint_addressDescription,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: outline),
            ),
            TextField(
              key: const ValueKey('dive-center-edit-street'),
              controller: _street.controller,
              focusNode: _addressFocus[0],
              decoration: field(
                l10n.diveCenters_field_street,
                l10n.diveCenters_hint_street,
              ),
            ),
            TextField(
              key: const ValueKey('dive-center-edit-city'),
              controller: _city.controller,
              focusNode: _addressFocus[1],
              decoration: field(
                l10n.diveCenters_field_city,
                l10n.diveCenters_hint_city,
              ),
            ),
            TextField(
              controller: _state.controller,
              focusNode: _addressFocus[2],
              decoration: field(
                l10n.diveCenters_field_stateProvince,
                l10n.diveCenters_hint_stateProvince,
              ),
            ),
            TextField(
              controller: _postal.controller,
              focusNode: _addressFocus[3],
              decoration: field(
                l10n.diveCenters_field_postalCode,
                l10n.diveCenters_hint_postalCode,
              ),
            ),
            TextField(
              key: const ValueKey('dive-center-edit-country'),
              controller: _country.controller,
              focusNode: _addressFocus[4],
              decoration: field(
                l10n.diveCenters_field_country,
                l10n.diveCenters_hint_country,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.diveCenters_hint_affiliationsDescription,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: outline),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final affiliation in diveCenterAffiliationChoices)
                  FilterChip(
                    label: Text(affiliation),
                    selected: affiliations.contains(affiliation),
                    onSelected: (selected) =>
                        _session.set(diveCenterAffiliationsField, [
                          for (final a in affiliations)
                            if (a != affiliation) a,
                          if (selected) affiliation,
                        ]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('dive-center-edit-closed'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.diveCenters_label_permanentlyClosed),
              subtitle: Text(l10n.diveCenters_hint_permanentlyClosed),
              value: _session.valueOf(diveCenterClosedField),
              onChanged: (value) => _session.set(diveCenterClosedField, value),
            ),
          ],
        );
      },
    );
  }
}
