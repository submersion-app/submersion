part of 'site_merge_page.dart';

/// Seeds a depth field at the single decimal place it has always shown, and
/// an altitude field at the whole units it has always shown, both in the
/// active locale's decimal separator so the save can read them back (#1091).
String _depthForInput(double value) => formatRoundedForInput(value, 1);

String _altitudeForInput(double value) => formatRoundedForInput(value, 0);

/// The merge page's fields: a controller per text field, the chosen value of
/// each of the others, their validators and the sections' summaries.
mixin _SiteMergeFields on ConsumerState<SiteMergePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _cityController = TextEditingController();
  final _islandController = TextEditingController();
  final _bodyOfWaterController = TextEditingController();
  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _notesController = TextEditingController();
  final _hazardsController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _mooringNumberController = TextEditingController();
  final _parkingInfoController = TextEditingController();
  final _altitudeController = TextEditingController();

  /// The country code known for a country text: the chosen site's stored
  /// one, the geocoder's after a lookup fills the country (issue #4426).
  /// Save keeps it while the country text is unchanged, and re-reads an
  /// edited text.
  KnownCountryCode _knownCountryCode = (country: null, code: null);

  double _rating = 0;
  SiteDifficulty? _difficulty;
  WaterType? _waterType;
  List<EntryMethod> _entryMethods = const [];
  List<EntryMethod> _exitMethods = const [];
  List<Species> _expectedSpecies = [];

  /// The survivor, the first site, once loaded: the merge keeps its id, its
  /// owner and its sharing (issue #2151).
  DiveSite? _survivor;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;

  /// Set while the page writes a field itself (the merge's first values, a
  /// lookup's fill), so the write does not count as the diver's change.
  bool _isApplyingInitialValues = false;

  /// Listens to every text field for the diver's first change, and to the
  /// coordinates with [onCoordinatesChanged].
  void _listenToFields({required VoidCallback onCoordinatesChanged}) {
    for (final controller in _textControllers) {
      controller.addListener(_onFieldChanged);
    }
    _latitudeController.addListener(onCoordinatesChanged);
    _longitudeController.addListener(onCoordinatesChanged);
  }

  void _disposeFields() {
    for (final controller in _textControllers) {
      controller.dispose();
    }
  }

  List<TextEditingController> get _textControllers => [
    _nameController,
    _descriptionController,
    _countryController,
    _regionController,
    _cityController,
    _islandController,
    _bodyOfWaterController,
    _minDepthController,
    _maxDepthController,
    _latitudeController,
    _longitudeController,
    _notesController,
    _hazardsController,
    _accessNotesController,
    _mooringNumberController,
    _parkingInfoController,
    _altitudeController,
  ];

  void _onFieldChanged() {
    if (_isApplyingInitialValues) return;
    if (!_hasChanges && _isInitialized) {
      setState(() => _hasChanges = true);
    }
  }

  String? _nameValidatorFn(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.diveSites_edit_field_siteName_validation;
    }
    return null;
  }

  String? _latValidatorFn(String? value) {
    if (value != null && value.isNotEmpty) {
      final lat = double.tryParse(value);
      if (lat == null || lat < -90 || lat > 90) {
        return context.l10n.diveSites_edit_gps_latitude_validation;
      }
    }
    return null;
  }

  String? _lonValidatorFn(String? value) {
    if (value != null && value.isNotEmpty) {
      final lng = double.tryParse(value);
      if (lng == null || lng < -180 || lng > 180) {
        return context.l10n.diveSites_edit_gps_longitude_validation;
      }
    }
    return null;
  }

  String? _altitudeValidatorFn(String? value) => numberValidator(
    context,
    check: (altitude) =>
        altitude < 0 ? context.l10n.diveSites_edit_altitude_validation : null,
  )(value);

  int _identityErrorCount() =>
      _nameValidatorFn(_nameController.text) == null ? 0 : 1;

  int _locationErrorCount() {
    var count = 0;
    if (_latValidatorFn(_latitudeController.text) != null) count++;
    if (_lonValidatorFn(_longitudeController.text) != null) count++;
    return count;
  }

  String _locationSummary(UnitFormatter units) => [
    if (_latitudeController.text.isNotEmpty &&
        _longitudeController.text.isNotEmpty)
      '${_latitudeController.text}, ${_longitudeController.text}',
    if (_altitudeController.text.isNotEmpty)
      '${_altitudeController.text} ${units.altitudeSymbol}',
  ].join(' · ');

  bool _locationIsEmpty() =>
      _latitudeController.text.isEmpty &&
      _longitudeController.text.isEmpty &&
      _altitudeController.text.isEmpty;

  String _diveInfoSummary() => [
    if (_minDepthController.text.isNotEmpty ||
        _maxDepthController.text.isNotEmpty)
      '${_minDepthController.text.isEmpty ? '?' : _minDepthController.text}'
          '-${_maxDepthController.text.isEmpty ? '?' : _maxDepthController.text}',
    if (_difficulty != null) _difficulty!.localizedName(context.l10n),
    if (_waterType != null) _waterType!.localizedName(context.l10n),
    if (_rating > 0) '★' * _rating.round(),
  ].join(' · ');

  String _methodNames(List<EntryMethod> methods) =>
      joinEntryMethodNames(methods, (m) => m.localizedName(context.l10n));

  String _accessSummary() => [
    if (_accessNotesController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_accessNotes_label,
    if (_entryMethods.isNotEmpty) _methodNames(_entryMethods),
    // Only when it differs, so the common mirrored case does not read
    // "Boat · Boat".
    if (exitDiffersFromEntry(_entryMethods, _exitMethods))
      _methodNames(_exitMethods),
    if (_mooringNumberController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_mooringNumber_label,
    if (_parkingInfoController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_parkingInfo_label,
    if (_hazardsController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_section_hazards,
  ].join(' · ');

  String _lifeNotesSummary() => [
    if (_expectedSpecies.isNotEmpty)
      context.l10n.diveLog_edit_summary_species(_expectedSpecies.length),
    if (_notesController.text.trim().isNotEmpty)
      context.l10n.diveLog_edit_summary_notes,
    if (_survivor?.isShared ?? false)
      context.l10n.diveSites_edit_summary_shared,
  ].join(' · ');

  /// [controller]'s number, null when blank; validate() has already stopped
  /// unreadable text.
  static double? _validatedNumber(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() => null,
        NumberInvalid() => null,
      };
}
