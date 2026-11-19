import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_coordinate_rows.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/place_name_replace_dialog.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_text_binding.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/place_lookup_row.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The Location card's editor: the position, with Use my location, Pick
/// from map and Look up from coordinates, and the five place names, each
/// keeping the form's rules (issue #4527, phase 2).
class SiteLocationCardEditor extends ConsumerStatefulWidget {
  const SiteLocationCardEditor({
    super.key,
    required this.session,
    this.pickLocation = pickSiteLocationOnMap,
    this.isPhone,
  });

  final EditSession<DiveSite> session;

  /// Whether the device is a phone, whose location settings the diver can
  /// be sent to; null asks the platform. A test says which.
  final bool? isPhone;

  /// Asks the diver for a point on the map, starting at [initial]; null when
  /// they backed out. A test hands in its own answer.
  final Future<PickedLocation?> Function(BuildContext context, LatLng? initial)
  pickLocation;

  @override
  ConsumerState<SiteLocationCardEditor> createState() =>
      _SiteLocationCardEditorState();
}

class _SiteLocationCardEditorState
    extends ConsumerState<SiteLocationCardEditor> {
  final Map<String, FieldTextBinding<DiveSite, String?>> _bindings = {};
  bool _busy = false;

  /// The place-name suggestions, kept until the sites, the country or the
  /// region change: the rows rebuild on every keystroke and caret move.
  ({
    List<DiveSite> sites,
    String country,
    String region,
    _PlaceSuggestions lists,
  })?
  _suggested;

  _PlaceSuggestions _suggestionsFor(
    List<DiveSite> sites,
    String country,
    String region,
  ) {
    final kept = _suggested;
    if (kept != null &&
        identical(kept.sites, sites) &&
        kept.country == country &&
        kept.region == region) {
      return kept.lists;
    }
    final lists = (
      countries: suggestedCountries(sites),
      regions: suggestedRegions(sites, country),
      cities: suggestedCities(sites, country, region),
      islands: suggestedIslands(sites, country),
      waters: suggestedBodiesOfWater(sites, country),
    );
    _suggested = (sites: sites, country: country, region: region, lists: lists);
    return lists;
  }

  EditSession<DiveSite> get _session => widget.session;

  /// A place name row's text; blank is no value. A typed country brings the
  /// code its name reads as, or none, so a hand edit never leaves another
  /// country's flag beside it.
  FieldTextBinding<DiveSite, String?> _bind(EditField<DiveSite, String?> f) =>
      _bindings[f.id] ??= siteWordsBinding(
        _session,
        f,
        apply: f == siteCountryField
            ? (country) {
                _session.set(siteCountryField, country);
                _session.set(siteCountryCodeField, countryCodeFor(country));
              }
            : null,
      );

  void _disposeBindings() {
    for (final binding in _bindings.values) {
      binding.dispose();
    }
    _bindings.clear();
  }

  @override
  void didUpdateWidget(SiteLocationCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _disposeBindings();
  }

  @override
  void dispose() {
    _disposeBindings();
    super.dispose();
  }

  Future<double?> _elevation(GeoPoint point) => fetchSiteElevation(
    ProviderScope.containerOf(context, listen: false),
    point,
  );

  /// The diver moved the site: an empty altitude follows a second later.
  void _moved(GeoPoint point) =>
      scheduleAltitudeAfterMove(_session, _elevation);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _useMyLocation() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final service = ref.read(locationServiceProvider);
      final result = await service.getCurrentLocation(
        includeGeocoding: true,
        languageCode: ref.read(placeNameLanguageProvider),
      );
      if (!mounted || _session.isDisposed) return;
      if (result == null) {
        final isMobile =
            widget.isPhone ??
            (!kIsWeb && (HostPlatform.isIOS || HostPlatform.isAndroid));
        if (!isMobile) {
          return _snack(
            l10n.diveSites_edit_snackbar_locationUnavailableDesktop,
          );
        }
        // As the form: on a phone, the way to the app's location settings.
        final service = ref.read(locationServiceProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.diveSites_edit_snackbar_locationUnavailableMobile,
            ),
            persist: false,
            action: SnackBarAction(
              label: l10n.diveSites_edit_snackbar_locationSettings,
              onPressed: () => service.openAppSettings(),
            ),
          ),
        );
        return;
      }
      final point = GeoPoint(result.latitude, result.longitude);
      moveSiteTo(_session, point, place: result.place);
      scheduleAltitudeAfterMove(_session, _elevation);
      _snack(
        result.place.networkFailed
            ? l10n.diveSites_edit_snackbar_lookupFailed
            : result.accuracy != null
            ? l10n.diveSites_edit_snackbar_locationCapturedWithAccuracy(
                result.accuracy!.toStringAsFixed(0),
              )
            : l10n.diveSites_edit_snackbar_locationCaptured,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromMap() async {
    final l10n = context.l10n;
    final current = _session.valueOf(siteLocationField);
    final result = await widget.pickLocation(
      context,
      current == null ? null : LatLng(current.latitude, current.longitude),
    );
    if (result == null || !mounted || _session.isDisposed) return;
    moveSiteTo(
      _session,
      GeoPoint(result.latitude, result.longitude),
      place: result.place,
    );
    scheduleAltitudeAfterMove(_session, _elevation);
    _snack(
      result.place.networkFailed
          ? l10n.diveSites_edit_snackbar_lookupFailed
          : l10n.diveSites_edit_snackbar_locationSelectedFromMap,
    );
  }

  /// Fills the empty place names from the position, then asks before
  /// replacing the ones that differ. An answer for a position the site has
  /// left meanwhile is dropped.
  Future<void> _lookUp() async {
    final l10n = context.l10n;
    final point = _session.valueOf(siteLocationField);
    if (point == null) return;
    setState(() => _busy = true);
    try {
      final lookup = await ref
          .read(locationServiceProvider)
          .reverseGeocode(
            point.latitude,
            point.longitude,
            languageCode: ref.read(placeNameLanguageProvider),
          );
      if (!mounted || _session.isDisposed) return;
      if (_session.valueOf(siteLocationField) != point) return;
      setState(() => _busy = false);
      if (lookup.networkFailed) {
        return _snack(l10n.diveSites_edit_snackbar_lookupFailed);
      }
      if (lookup.isEmpty) {
        return _snack(l10n.diveSites_edit_snackbar_lookupNothingFound);
      }
      final filled = applyPlaceLookup(_session, lookup, overwrite: false);
      final differing = differingPlaceValues(
        sittingPlaceNames(_session),
        lookup,
        l10n,
      );
      if (differing.isEmpty) {
        if (!filled) _snack(l10n.diveSites_edit_snackbar_lookupNoChanges);
        return;
      }
      final replace = await confirmPlaceNameReplace(context, differing);
      if (!replace || !mounted) return;
      if (_session.isDisposed || _session.valueOf(siteLocationField) != point) {
        return;
      }
      applyPlaceLookup(_session, lookup, overwrite: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allSites = ref.watch(sitesProvider).value ?? const <DiveSite>[];
    // Only what depends on other values is rebuilt as they change: the
    // suggestion lists follow the country and region rows, and the lookup
    // follows the position.
    return ListenableBuilder(
      listenable: Listenable.merge([
        _bind(siteCountryField).controller,
        _bind(siteRegionField).controller,
      ]),
      builder: (context, _) {
        final country = _session.valueOf(siteCountryField) ?? '';
        final region = _session.valueOf(siteRegionField) ?? '';
        final suggested = _suggestionsFor(allSites, country, region);
        Widget place(
          EditField<DiveSite, String?> field,
          String label,
          List<String> suggestions,
        ) => SuggestionFormRow(
          label: label,
          controller: _bind(field).controller,
          suggestions: suggestions,
          textCapitalization: TextCapitalization.words,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SiteCoordinateRows(
              session: _session,
              format: ref.watch(coordinateFormatProvider),
              onMoved: _moved,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _useMyLocation,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(l10n.diveSites_edit_gps_useMyLocation),
                  ),
                  TextButton.icon(
                    // Not while a position is on its way: it would land on
                    // top of the point picked.
                    onPressed: _busy ? null : _pickFromMap,
                    icon: const Icon(Icons.map, size: 16),
                    label: Text(l10n.diveSites_edit_gps_pickFromMap),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: _session,
              builder: (context, _) => PlaceLookupRow(
                isBusy: _busy,
                onLookup: _session.valueOf(siteLocationField) == null
                    ? null
                    : _lookUp,
              ),
            ),
            place(
              siteCountryField,
              l10n.diveSites_edit_field_country_label,
              suggested.countries,
            ),
            place(
              siteRegionField,
              l10n.diveSites_edit_field_region_label,
              suggested.regions,
            ),
            place(
              siteCityField,
              l10n.diveSites_edit_field_city_label,
              suggested.cities,
            ),
            place(
              siteIslandField,
              l10n.diveSites_edit_field_island_label,
              suggested.islands,
            ),
            place(
              siteBodyOfWaterField,
              l10n.diveSites_edit_field_bodyOfWater_label,
              suggested.waters,
            ),
          ],
        );
      },
    );
  }
}

/// The map picker the site form opens, pushed over the page.
Future<PickedLocation?> pickSiteLocationOnMap(
  BuildContext context,
  LatLng? initial,
) => Navigator.of(context).push<PickedLocation>(
  MaterialPageRoute(
    builder: (context) => LocationPickerMap(initialLocation: initial),
  ),
);

/// The place-name suggestions the Location card offers.
typedef _PlaceSuggestions = ({
  List<String> countries,
  List<String> regions,
  List<String> cities,
  List<String> islands,
  List<String> waters,
});
