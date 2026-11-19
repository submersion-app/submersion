part of 'site_merge_page.dart';

/// The merge page's location actions: Use my location, Pick from map, Look
/// up from the coordinates, and the altitude filled from the coordinates.
mixin _SiteMergeLocation on _SiteMergeFields {
  Timer? _altitudeLookupDebounce;

  /// Debounce typed coordinate edits; the locate action and map picker set both
  /// controller texts at once and land here through the same listeners.
  void _scheduleAltitudeLookup() {
    _altitudeLookupDebounce?.cancel();
    _altitudeLookupDebounce = Timer(const Duration(seconds: 1), () {
      if (mounted) _maybeFetchAltitude();
    });
  }

  /// Fill an empty altitude field from the site's coordinates so altitude
  /// diving is flagged without manual entry. Never overwrites a value.
  Future<void> _maybeFetchAltitude() async {
    if (_altitudeController.text.isNotEmpty) return;
    final point = _parsedCoordinates();
    if (point == null) return;

    final meters = await ref
        .read(elevationServiceProvider)
        .fetchElevation(latitude: point.latitude, longitude: point.longitude);
    if (!mounted || meters == null) return;
    if (_altitudeController.text.isNotEmpty) return;
    // An answer for a position the fields have since left (another site's
    // coordinates cycled in) fills nothing; that position asks for itself.
    if (_parsedCoordinates() != point) return;

    final units = ref.read(unitFormatterProvider);
    setState(() {
      // A fill the page makes itself is not the diver's change: a merge left
      // untouched closes without asking to discard it.
      final wasApplying = _isApplyingInitialValues;
      _isApplyingInitialValues = true;
      _altitudeController.text = _altitudeForInput(
        units.convertAltitude(meters),
      );
      _isApplyingInitialValues = wasApplying;
    });
  }

  /// Writes [lookup] into the country, region, city and body of water
  /// fields. With [overwrite] false only empty fields change; with it true a
  /// found value replaces a differing one. The rule lives in
  /// [mergeLocationDetails]. Returns whether any field changed. Callers
  /// decide whether that counts as the diver's change.
  bool _applyPlaceLookup(PlaceLookup lookup, {required bool overwrite}) {
    final currentCode =
        _knownCountryCode.country?.trim() == _countryController.text.trim()
        ? _knownCountryCode.code
        : null;
    final merged = mergeLocationDetails(
      current: SiteLocationDetails(
        country: _countryController.text,
        countryCode: currentCode,
        region: _regionController.text,
        city: _cityController.text,
        bodyOfWater: _bodyOfWaterController.text,
      ),
      found: lookup,
      overwrite: overwrite,
    );
    if (merged == null) return false;

    var changed = false;
    void set(TextEditingController controller, String? value) {
      if (value == null || controller.text == value) return;
      controller.text = value;
      changed = true;
    }

    set(_countryController, merged.country);
    // A written country keeps its code even when the merge reports the code
    // as unchanged (null), so save does not re-read a name the table cannot.
    if (merged.country != null || merged.countryCode != null) {
      _knownCountryCode = (
        country: _countryController.text,
        code: merged.clearCountryCode
            ? null
            : merged.countryCode ?? currentCode,
      );
    }
    set(_regionController, merged.region);
    set(_cityController, merged.city);
    set(_bodyOfWaterController, merged.bodyOfWater);
    return changed;
  }

  bool _isGettingLocation = false;

  late final Listenable _coordinateChanges = Listenable.merge([
    _latitudeController,
    _longitudeController,
  ]);

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final locationService = ref.read(locationServiceProvider);
      final result = await locationService.getCurrentLocation(
        includeGeocoding: true,
        languageCode: ref.read(placeNameLanguageProvider),
      );

      if (result == null) {
        if (mounted) {
          final isMobile =
              !kIsWeb && (HostPlatform.isIOS || HostPlatform.isAndroid);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMobile
                    ? context
                          .l10n
                          .diveSites_edit_snackbar_locationUnavailableMobile
                    : context
                          .l10n
                          .diveSites_edit_snackbar_locationUnavailableDesktop,
              ),
              persist: false,
              action: isMobile
                  ? SnackBarAction(
                      label:
                          context.l10n.diveSites_edit_snackbar_locationSettings,
                      onPressed: () => locationService.openAppSettings(),
                    )
                  : null,
            ),
          );
        }
        return;
      }

      // The diver may have left while the position was being found.
      if (!mounted) return;
      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);
        _hasChanges = true;
        _applyPlaceLookup(result.place, overwrite: false);
      });

      if (mounted) {
        // The position landed in the fields either way; say so, but when the
        // geocoder was unreachable explain why the place fields stayed empty.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.place.networkFailed
                  ? context.l10n.diveSites_edit_snackbar_lookupFailed
                  : result.accuracy != null
                  ? context.l10n
                        .diveSites_edit_snackbar_locationCapturedWithAccuracy(
                          result.accuracy!.toStringAsFixed(0),
                        )
                  : context.l10n.diveSites_edit_snackbar_locationCaptured,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _pickFromMap() async {
    final point = _parsedCoordinates();
    final initialLocation = point == null
        ? null
        : LatLng(point.latitude, point.longitude);

    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (context) =>
            LocationPickerMap(initialLocation: initialLocation),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);
        _hasChanges = true;
        _applyPlaceLookup(result.place, overwrite: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.place.networkFailed
                ? context.l10n.diveSites_edit_snackbar_lookupFailed
                : context.l10n.diveSites_edit_snackbar_locationSelectedFromMap,
          ),
        ),
      );
    }
  }

  /// The typed coordinates, or null while either field does not parse.
  GeoPoint? _parsedCoordinates() {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GeoPoint(lat, lng);
  }

  /// Explicit lookup for the typed coordinates (issue #1187). One press fills
  /// the empty fields and offers to replace any that differ, so a site with
  /// both needs no second press (issue #4084). Never runs on save.
  Future<void> _lookupFromCoordinates() async {
    final point = _parsedCoordinates();
    if (point == null) return;
    setState(() => _isGettingLocation = true);
    try {
      final lookup = await ref
          .read(locationServiceProvider)
          .reverseGeocode(
            point.latitude,
            point.longitude,
            languageCode: ref.read(placeNameLanguageProvider),
          );
      if (!mounted) return;
      // The answer describes where the site was when the button was pressed.
      if (_parsedCoordinates() != point) return;
      // The busy indicator must stop before any dialog waits for input.
      setState(() => _isGettingLocation = false);

      if (lookup.networkFailed) {
        _showLookupSnackBar(context.l10n.diveSites_edit_snackbar_lookupFailed);
        return;
      }
      if (lookup.isEmpty) {
        _showLookupSnackBar(
          context.l10n.diveSites_edit_snackbar_lookupNothingFound,
        );
        return;
      }

      var filled = false;
      setState(() {
        filled = _applyPlaceLookup(lookup, overwrite: false);
        if (filled) _hasChanges = true;
      });

      final differing = differingPlaceValues(
        SiteLocationDetails(
          country: _countryController.text,
          region: _regionController.text,
          city: _cityController.text,
          bodyOfWater: _bodyOfWaterController.text,
        ),
        lookup,
        context.l10n,
      );
      if (differing.isEmpty) {
        if (!filled) {
          _showLookupSnackBar(
            context.l10n.diveSites_edit_snackbar_lookupNoChanges,
          );
        }
        return;
      }
      final replace = await confirmPlaceNameReplace(context, differing);
      if (!mounted || !replace) return;
      setState(() {
        if (_applyPlaceLookup(lookup, overwrite: true)) _hasChanges = true;
      });
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showLookupSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
