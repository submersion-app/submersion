import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart' hide Visibility;
import 'package:go_router/go_router.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/equipment/presentation/utils/usable_set_items.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/gear_passports/presentation/utils/scan_owned_item.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_editing.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';
import 'package:submersion/features/dive_log/domain/services/detected_gas_switch_edits.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/helpers/linked_dive_times.dart';
import 'package:submersion/features/dive_log/presentation/helpers/open_profile_editor.dart';
import 'package:submersion/features/dive_log/presentation/helpers/seeded_dive_times.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_set_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/save_gear_as_set_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_input.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/apply_last_dive_confirm_dialog.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/helpers/new_trip_from_selection.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_date_stretch_message.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/cylinder_breath_starts_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/detected_gas_switches_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/profile_time_domain.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mirror_dive_dialog.dart';
import 'package:submersion/features/dive_log/presentation/providers/outlier_suggestion_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/custom_field_input_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/buddies_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/experience_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_editing.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/annotation_time_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/rare_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_row.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/services/dive_tank_config_adapter.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_confirm_dialog.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_menu.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/statistics_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/suggested_text_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/trip_section.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/name_prompt_dialog.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/weight_preset_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/utils/entry_exit_autofill.dart';
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_type_autofill.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/scr_settings_panel.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/add_section_row.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/forms/enum_picker_row.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_caption.dart';
import 'package:submersion/shared/widgets/forms/form_empty_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';
import 'package:submersion/features/dive_log/presentation/widgets/flight_window_warning_banner.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_weight_entry_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gear_lead_note.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/cylinder_configs/domain/services/main_supply.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_form_plan.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/dive_log/presentation/widgets/set_weights_choice_dialog.dart';

part 'dive_edit_page_annotations.dart';
part 'dive_edit_page_gas_switches.dart';
part 'dive_edit_page_linked_times.dart';
part 'dive_edit_page_set_bundle.dart';

const _createNewDiveCenterSentinel = '__create_new_dive_center__';
const _createNewTripSentinel = '__create_new_trip__';

/// [value] rendered with exactly [fractionDigits] decimals in the diver's
/// locale, for seeding an editable field.
///
/// Every field seeded here is read back with [readNumber], and the two
/// halves must share one convention. `toStringAsFixed` always emits a dot, and
/// under de/es/it that dot is the GROUPING separator, so a diver who opened a
/// dive and saved it untouched would store ten times the depth (#1091).
///
/// This page keeps trailing zeros (a depth seeds as "12.0"), so it uses
/// [formatFixedForInput] rather than the trailing-zero-dropping
/// [formatRoundedForInput] the other forms use.
String _seedDecimal(double value, int fractionDigits) =>
    formatFixedForInput(value, fractionDigits);

/// A weight already converted to the diver's display unit, rendered for
/// seeding an editable field.
///
/// Weight has no pinned display precision the way depth and temperature do: a
/// diver trims with 0.25 kg (or fractional-lb) increments, so seeding at one
/// decimal snapped a stored 0.65 kg to "0.7", and opening a dive and saving it
/// untouched then persisted the rounded value (#1609). Three decimals in the
/// display unit covers the increments a diver actually trims with (0.25 kg,
/// fractional lb) while still hiding the float tail a kg-to-lb conversion
/// leaves; trailing zeros are dropped so a clean 2 kg still seeds as "2".
String _seedWeight(double displayValue) =>
    formatRoundedForInput(displayValue, 3);

/// [value] rendered for seeding a whole-number field, read back with
/// [readNumber]. Grouping is off, so this is digit-only text.
String _seedInt(int value) => _seedDecimal(value.toDouble(), 0);

extension on double? {
  /// This value through [convert], or null when there is none.
  double? map(double Function(double) convert) {
    final value = this;
    return value == null ? null : convert(value);
  }
}

/// [controller]'s number for saving. Blank means "not recorded" for every
/// numeric field on this page; unreadable text never reaches here, because
/// each field's validator has already stopped the save (#1900).
double? _savedNumber(
  TextEditingController controller, {
  bool integer = false,
}) => switch (readNumber(controller.text, integer: integer)) {
  NumberValue(:final value) => value,
  NumberBlank() => null,
  NumberInvalid() => null, // unreachable: validate() blocked the save
};

class DiveEditPage extends ConsumerStatefulWidget {
  final String? diveId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when save completes (used in embedded mode).
  final void Function(String savedId)? onSaved;

  /// Callback when user cancels editing (used in embedded mode).
  final VoidCallback? onCancel;

  /// Initial values for create mode (e.g. from the OCR scan flow).
  /// Ignored when editing an existing dive or in bulk mode.
  final DivePrefill? prefill;

  /// Create mode only: the trip to put the new dive on (the board's Log
  /// dive shortcut). Ignored when editing.
  final String? tripId;

  /// Create mode only, with [tripId]: the slot the first tank breathes
  /// from. Without it, the first tank gets the usual suggestion.
  final String? tripCylinderId;

  const DiveEditPage({
    super.key,
    this.diveId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.prefill,
    this.tripId,
    this.tripCylinderId,
  });

  bool get isEditing => diveId != null;

  @override
  ConsumerState<DiveEditPage> createState() => _DiveEditPageState();
}

class _DiveEditPageState extends ConsumerState<DiveEditPage> {
  static final _log = LoggerService.forClass(DiveEditPage);

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Form controllers - Entry/Exit times
  late DateTime _entryDate;
  late TimeOfDay _entryTime;
  DateTime? _exitDate;
  TimeOfDay? _exitTime;

  /// What the time inputs were filled with and the exact values they round;
  /// null for a new dive until an entry or runtime edit moves its exit. The
  /// save reads it so an unrelated edit does not write whole minutes over
  /// stored seconds (issue #3901), and a linked edit re-seeds it so the exit
  /// it moves keeps its seconds (issue #241).
  SeededDiveTimes? _seededTimes;

  /// The times as they last settled (seeded, or after an entry or exit
  /// edit), with the runtime shown then. Each runtime keystroke links
  /// from here, so a digit passed on the way to a value, or left by
  /// backspacing, never moves the exit for good, and a blank, zero or
  /// unchanged runtime puts the exact times back (issues #241, #3901).
  ({
    DateTime? exit,
    DateTime? exitDate,
    TimeOfDay? exitTime,
    SeededDiveTimes? seeded,
    bool settled,
    int? runtimeMinutes,
  })?
  _runtimeEditBase;

  // The one setState seam for the linked time edits in
  // dive_edit_page_linked_times.dart.
  void _updateTimes(VoidCallback mutate) => setState(mutate);
  final _diveNumberController = TextEditingController();
  final _durationController = TextEditingController();
  final _runtimeController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _avgDepthController = TextEditingController();
  final _waterTempController = TextEditingController();
  final _airTempController = TextEditingController();
  final _notesController = TextEditingController();
  final _nameController = TextEditingController();

  List<String> _selectedDiveTypeIds = const ['recreational'];

  /// The dive's types and roles as loaded, offered by the pickers even when
  /// hidden (issue #401) so a change to one can be undone in place.
  List<String> _loadedDiveTypeIds = const [];
  Set<String> _loadedRoleIds = const {};

  /// The dive types the assigned site added (issue #2037) and the diver has
  /// not touched since: what the next site assignment may take back.
  Set<String> _siteAddedDiveTypeIds = const {};

  /// The site-to-dive-type snap still in flight, which a save waits for so
  /// the types it adds are not lost to a quick tap on Save.
  Future<void>? _pendingDiveTypeSnap;

  /// The dive's visibility as loaded (issue #3226), saved back untouched
  /// until the diver types a number or taps a chip.
  StoredVisibility _originalVisibility = StoredVisibility.none;
  late VisibilityInputMode _visibilityMode = ref.read(
    visibilityInputModeProvider,
  );
  VisibilityBand? _visibilityBand;

  /// Whether the diver has edited each visibility mode (typed a number,
  /// tapped a chip). Tracked per mode so a detour through the other mode
  /// never discards or rounds the stored value.
  bool _preciseTouched = false;
  bool _rangeTouched = false;

  bool get _activeVisibilityTouched => switch (_visibilityMode) {
    VisibilityInputMode.precise => _preciseTouched,
    VisibilityInputMode.range => _rangeTouched,
  };
  int _rating = 0;
  // Statistics exclusion (#526 / #1272). Kept independent: unticking the
  // master flag must restore the diver's own gas-only choice rather than
  // having silently overwritten it.
  bool _excludedFromStats = false;
  bool _excludedFromGasStats = false;
  DiveSite? _selectedSite;
  Trip? _selectedTrip;
  DiveCenter? _selectedDiveCenter;
  // The dive's training courses (#2515).
  List<String> _selectedCourseIds = const [];
  List<Sighting> _sightings = [];
  Set<String> _originalSightingIds =
      {}; // Track original IDs to detect deletions
  List<EquipmentItem> _selectedEquipment = [];

  /// Where each selected item came from: the assembly it was attached
  /// through and the set applied (issue #1487). Read through [_gearRows].
  List<GearProvenance> _gearProvenance = [];
  List<BuddyWithRole> _selectedBuddies = [];

  /// The dive's staged underwater route links, applied on Save. Null until
  /// an existing dive's current links have loaded, so the row stays inert
  /// and a Save can never read "not loaded" as "every route removed".
  DiveRouteLinkDraft? _routeDraft;

  /// The dive's current links could not be read, so the route row says so
  /// and stays inert instead of claiming the dive has none.
  bool _routeLinksFailed = false;
  Set<String> _originalBuddyIds = {};

  /// The active diver's own roles on the dive (#547, several since #1221).
  List<String> _diverRoleIds = const [];

  EquipmentSet? _geofenceSuggestion;
  final Set<String> _dismissedSuggestionSetIds = {};

  // Conditions fields
  CurrentDirection? _currentDirection;
  CurrentStrength? _currentStrength;
  EntryMethod? _entryMethod;
  EntryMethod? _exitMethod;
  // Exit mirrors entry until the user edits the exit picker directly.
  // Single-dive form only; the bulk layout's dropdowns share these value
  // fields but must never trigger mirroring.
  bool _exitMethodLinked = true;
  WaterType? _waterType;

  /// True while [_waterType] is the loaded site's water type standing in for
  /// a dive that has none of its own (issue #3196). A site change then starts
  /// from no water type, so the old site's value is never saved as the dive's.
  bool _waterTypeFromSite = false;
  final _swellHeightController = TextEditingController();

  /// Precise visibility, entered in the diver's depth unit and converted to
  /// meters on save. The Range mode's pick lives in [_visibilityBand].
  final _visibilityController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _surfacePressureController = TextEditingController();

  // Weather fields
  CurrentDirection? _windDirection;
  CloudCover? _cloudCover;
  Precipitation? _precipitation;
  WeatherSource? _weatherSource;
  DateTime? _weatherFetchedAt;
  final _windSpeedController = TextEditingController();
  final _humidityController = TextEditingController();
  final _weatherDescriptionController = TextEditingController();
  final _diveOperatorController = TextEditingController();
  final _boatNameController = TextEditingController();
  final _boatCaptainController = TextEditingController();
  final _surfaceConditionsController = TextEditingController();
  bool _isFetchingWeather = false;

  // Weight fields - multiple weight entries per dive
  List<DiveWeight> _weights = [];

  // Post-dive weighting feedback (v104): trains the weight predictor.
  WeightingFeedback? _weightingFeedback;
  final _weightingFeedbackAmountController = TextEditingController();

  // Tank data - list of tanks with multi-tank support
  List<DiveTank> _tanks = [];

  // The gas switch list (issue #32); the handlers live in
  // dive_edit_page_gas_switches.dart, which reaches setState through
  // [_updateGasSwitches].
  List<GasSwitch> _gasSwitches = const [];
  Set<String> _loadedGasSwitchIds = const {};
  // The earliest loaded switch, when it lies before the dive start
  // (#4335): what the dive already holds never fails validation.
  int _loadedGasSwitchFloor = 0;
  Set<String> _depthTouchedSwitchIds = const {};
  int _removedSwitchNotice = 0;
  bool _gasSwitchesDirty = false;

  void _updateGasSwitches(VoidCallback mutate) => setState(mutate);

  /// The setState seam for dive_edit_page_set_bundle.dart.
  void _applyBundleChange(VoidCallback change) => setState(change);
  final _uuid = const Uuid();
  TankPresetEntity? _defaultPreset;
  bool _tanksDirty = false;

  /// Whether a prefill (a scanned log page, a cylinder tag) wrote the first
  /// tank. [_tanksDirty] cannot say so: a prefill that only gives a mix or
  /// pressures leaves it clear so the default preset can still load. A set's
  /// cylinders must not replace that tank as if it were the untouched
  /// starter (issue #4525).
  bool _firstTankPrefilled = false;

  /// Part of every tank row's key, bumped when a configuration rewrites
  /// cylinders in place. A tank editor reads its text fields once, so an
  /// editor left open would keep the old size and write it back on the next
  /// keystroke; a new key gives it fresh fields (issue #2563).
  int _tankRowGeneration = 0;

  /// Tanks the dive had when it was loaded, or that a prefill (a scan, a
  /// cylinder tag) filled: never suggested a slot, since a suggestion would
  /// replace their values with the slot's, and None would not restore them.
  Set<String> _loadedTankIds = const {};

  /// Tanks whose slot link is a suggestion the diver has not confirmed.
  Set<String> _suggestedTankIds = const {};

  /// Tanks the diver set to None after a suggestion: never re-suggested.
  Set<String> _declinedTankIds = const {};

  // Tags
  List<Tag> _selectedTags = [];

  // Custom fields
  List<DiveCustomField> _customFields = [];

  // Dive mode and rebreather settings
  DiveMode _diveMode = DiveMode.oc;
  // CCR settings
  double? _setpointLow;
  double? _setpointHigh;
  double? _setpointDeco;
  GasMix? _diluentGas;
  String? _scrubberType;
  int? _scrubberDurationMinutes;

  int? _scrubberRemainingMinutes;
  double? _loopVolume;

  /// Bumped when setpoints are seeded from Settings after the CCR panel may
  /// already have built, so the panel rebuilds from the seeded state.
  int _ccrSeedGeneration = 0;

  // SCR settings
  ScrType? _scrType;
  double? _scrInjectionRate;
  double? _scrAdditionRatio;
  String? _scrOrificeSize;
  GasMix? _scrSupplyGas;
  double? _assumedVo2;
  double? _loopO2Min;
  double? _loopO2Max;
  double? _loopO2Avg;

  // Existing dive for editing
  Dive? _existingDive;

  /// Annotations linked in the notes since the page opened, written on save
  /// (#4109).
  List<PendingAnnotation> _pendingAnnotations = const [];

  /// Planned dive, awaiting its dive computer data (issue #2002). A planned
  /// dive holds no number; turning the switch off on an existing planned
  /// dive promotes it on save.
  bool _isPlanned = false;

  /// A draft (issue #637) holds no number until a download fills it or the
  /// diver marks it complete, and is never switched to a plan here.
  bool get _isDraft => _existingDive?.isDraft ?? false;

  /// A dive holding downloaded data cannot be marked planned, so the switch
  /// is hidden once a primary data source exists.
  bool _hasPrimarySource = false;

  // Current device location (for new dives - to suggest nearby sites)
  LocationResult? _currentLocation;
  bool _isCapturingLocation = false;

  // GPS suggestion from photos

  /// Smart-collapse expansion state, keyed by group. Defaults are computed
  /// at the call sites (new dive vs editing); user toggles override them
  /// for the lifetime of the page.
  final Map<String, bool> _expanded = {};

  bool _isExpanded(String key, {required bool defaultValue}) =>
      _expanded[key] ?? defaultValue;

  void _toggleSection(String key, {required bool defaultValue}) {
    setState(
      () => _expanded[key] = !_isExpanded(key, defaultValue: defaultValue),
    );
  }

  bool get _showCourseSection =>
      _selectedCourseIds.isNotEmpty || _expanded['course'] == true;

  bool get _showCustomFieldsSection =>
      _customFields.isNotEmpty || _expanded['customFields'] == true;

  /// Unsaved-changes guard state. The page never had one before the form
  /// redesign; EditFormScaffold's PopScope consumes this.
  bool _hasUnsavedChanges = false;

  /// Suppressed while loading/populating so programmatic writes do not
  /// trip the discard guard.
  bool _suppressDirty = true;

  /// The form's entry date and time as an instant, the wall clock stamped
  /// UTC as every dive time is. The shared gear note, the route sheet and the
  /// trip cylinders' state at the dive all read it here. Stored seconds hold
  /// until the diver moves the entry.
  DateTime _currentEntryTime() {
    final input = _entryInput();
    return _seededTimes?.entryFor(input) ?? input;
  }

  /// The entry inputs to the minute, the wall clock stamped UTC.
  DateTime _entryInput() => DateTime.utc(
    _entryDate.year,
    _entryDate.month,
    _entryDate.day,
    _entryTime.hour,
    _entryTime.minute,
  );

  /// The exit inputs to the minute, the wall clock stamped UTC, or null until
  /// both are set.
  DateTime? _exitInput() {
    if (_exitDate == null || _exitTime == null) return null;
    return DateTime.utc(
      _exitDate!.year,
      _exitDate!.month,
      _exitDate!.day,
      _exitTime!.hour,
      _exitTime!.minute,
    );
  }

  /// The time inputs as the save reads them.
  DiveTimeInputs _timeInputs() => DiveTimeInputs(
    entry: _entryInput(),
    exit: _exitInput(),
    bottomTimeMinutes: _savedNumber(
      _durationController,
      integer: true,
    )?.toInt(),
    runtimeMinutes: _savedNumber(_runtimeController, integer: true)?.toInt(),
  );

  /// In-edit dive end time, wall-clock-as-UTC, as the save will leave it: the
  /// exit, otherwise entry + runtime. An exit estimated from the bottom time
  /// has no runtime behind it, so it ends at entry + bottom time, which
  /// follows the entry as the estimate on the form does not. Null when none
  /// of these is derivable. Feeds the flight-window warning banner.
  DateTime? _currentDiveEndTime() =>
      resolveDiveTimes(_timeInputs(), seeded: _seededTimes).end ??
      (_exitInput() == null ? null : _entryPlusBottomTime());

  /// The form's dive, with its unsaved times, for the shared gear note
  /// (issue #2853): a new dive has no id yet, and the note follows time
  /// edits before the save.
  SharedGearOverlapQuery _sharedGearQuery(String? activeDiverId) => (
    diveId: widget.diveId,
    // A new dive is saved under the active profile; an existing dive keeps
    // its own, and one without a profile is paired with nobody, as the
    // scan would.
    diverId: widget.diveId == null ? activeDiverId : _existingDive?.diverId,
    entry: _currentEntryTime(),
    exit: _currentDiveEndTime() ?? _entryPlusBottomTime(),
  );

  /// Entry plus the bottom time field, the scan's last resort for a dive
  /// with no exit or runtime (`sharedGearExit`); null while it is blank.
  DateTime? _entryPlusBottomTime() {
    final minutes = switch (readNumber(
      _durationController.text,
      integer: true,
    )) {
      NumberValue(:final value) => value.toInt(),
      NumberBlank() || NumberInvalid() => null,
    };
    if (minutes == null || minutes <= 0) return null;
    return _currentEntryTime().add(Duration(minutes: minutes));
  }

  /// "Also on Anna's dive, 10:02" for gear on another profile's overlapping
  /// dive, or null. The time is the other dive's UTC wall clock, formatted
  /// in the diver's 12h/24h preference.
  String? Function(String equipmentId) _sharedGearNotes(
    Map<String, SharedGearNote> notes,
  ) {
    final units = UnitFormatter(ref.read(settingsProvider));
    final l10n = context.l10n;
    return (equipmentId) {
      final note = notes[equipmentId];
      if (note == null) return null;
      return l10n.diveLog_gear_alsoOnDive(
        note.diverName,
        units.formatTime(note.entry),
      );
    };
  }

  void _markDirty() {
    if (_suppressDirty || _hasUnsavedChanges) return;
    _hasUnsavedChanges = true;
    // Deferred: this is called from listeners, Form.onChanged and inside
    // other setState callbacks; PopScope reads the flag on next build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _silently(VoidCallback fn) {
    final previous = _suppressDirty;
    _suppressDirty = true;
    fn();
    _suppressDirty = previous;
  }

  @override
  void initState() {
    super.initState();
    _entryDate = DateTime.now();
    _entryTime = TimeOfDay.now();

    // Eagerly resolve built-in presets (sync), async for custom
    logFailure(_loadDefaultPreset(), _DiveEditPageState, 'load default preset');

    // New single dive: auto-apply the diver's default/geofenced equipment set
    // once the form is up, only when no gear is present.
    if (!widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyEquipmentDefaultsOnEmpty();
      });
    }

    final settings = ref.read(settingsProvider);
    _tanks = [
      DiveTank(
        id: _uuid.v4(),
        volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
        workingPressure: _defaultPreset?.workingPressureBar,
        startPressure: settings.defaultStartPressure,
        endPressure: 50.0,
        gasMix: const GasMix(),
        role: TankRole.backGas,
        material: _defaultPreset?.material,
        order: 0,
        presetName: _defaultPreset?.name,
      ),
    ];

    if (widget.isEditing) {
      logFailure(_loadExistingDive(), _DiveEditPageState, 'load existing dive');
    } else {
      // A new dive has no links yet, so its draft is ready immediately.
      _routeDraft = DiveRouteLinkDraft.initial(const []);
      // For new dives, capture GPS in the background to suggest nearby sites
      _captureLocationForNearby();
      _isPlanned = widget.prefill?.isPlanned ?? false;
      if (widget.prefill?.diveNumber == null && !_isPlanned) {
        // The async suggestion would overwrite a prefilled number, and a
        // planned dive takes none.
        _suggestNextDiveNumber();
      }
      _applyPrefill();
      if (widget.tripId case final tripId?) {
        logFailure(
          _applyTripLink(tripId, widget.tripCylinderId),
          _DiveEditPageState,
          'apply trip link',
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _suppressDirty = false;
      });
    }

    for (final controller in [
      _diveNumberController,
      _durationController,
      _runtimeController,
      _maxDepthController,
      _avgDepthController,
      _waterTempController,
      _airTempController,
      _notesController,
      _nameController,
      _swellHeightController,
      _visibilityController,
      _altitudeController,
      _surfacePressureController,
      _windSpeedController,
      _humidityController,
      _weatherDescriptionController,
      _diveOperatorController,
      _boatNameController,
      _boatCaptainController,
      _surfaceConditionsController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  Future<void> _loadDefaultPreset() async {
    final settings = ref.read(settingsProvider);
    final presetName = settings.defaultTankPreset;

    // Built-in presets resolve synchronously so the first tank starts with
    // them; the lookup below still runs, as the diver's own preset of the
    // same name shadows the built-in, the way imports resolve it.
    final builtIn = presetName != null ? TankPresets.byName(presetName) : null;
    if (builtIn != null) {
      _defaultPreset = TankPresetEntity.fromBuiltIn(builtIn);
    }

    // Async lookup for custom presets
    if (presetName != null) {
      final repository = ref.read(tankPresetRepositoryProvider);
      final resolver = DefaultTankPresetResolver(repository: repository);
      final preset = await resolver.resolve(
        presetName,
        diverId: await ref.read(validatedCurrentDiverIdProvider.future),
      );
      // Nothing shadows the built-in already applied.
      if (builtIn != null && (preset == null || preset.isBuiltIn)) return;
      if (mounted) {
        setState(() {
          _defaultPreset = preset;
          // Apply preset to initial tank if the user hasn't edited tanks yet
          // and this is a new dive (not editing an existing one)
          if (!_tanksDirty &&
              !widget.isEditing &&
              preset != null &&
              _tanks.length == 1) {
            final existing = _tanks[0];
            _tanks = [
              DiveTank(
                id: existing.id,
                volume: preset.volumeLiters,
                workingPressure: preset.workingPressureBar,
                startPressure: existing.startPressure,
                endPressure: existing.endPressure,
                gasMix: existing.gasMix,
                role: existing.role,
                material: preset.material,
                order: existing.order,
                presetName: preset.name,
                // A tag that described nothing still named the cylinder
                // (issue #2650).
                passportId: existing.passportId,
                twinPassportId: existing.twinPassportId,
              ),
            ];
          }
        });
      }
    }
  }

  void _applyPrefill() {
    final p = widget.prefill;
    if (p == null) return;
    final units = UnitFormatter(ref.read(settingsProvider));
    if (p.diveNumber != null) {
      _diveNumberController.text = _seedInt(p.diveNumber!);
    }
    if (p.dateTime != null) {
      _entryDate = p.dateTime!;
      if (p.hasTimeOfDay) {
        _entryTime = TimeOfDay.fromDateTime(p.dateTime!);
      }
    }
    if (p.durationMinutes != null) {
      _durationController.text = _seedInt(p.durationMinutes!);
    }
    if (p.maxDepthMeters != null) {
      _maxDepthController.text = _seedDecimal(
        units.convertDepth(p.maxDepthMeters!),
        1,
      );
    }
    if (p.waterTempCelsius != null) {
      _waterTempController.text = _seedDecimal(
        units.convertTemperature(p.waterTempCelsius!),
        0,
      );
    }
    if (p.airTempCelsius != null) {
      _airTempController.text = _seedDecimal(
        units.convertTemperature(p.airTempCelsius!),
        0,
      );
    }
    if (p.notes != null) _notesController.text = p.notes!;
    if (p.rating != null) _rating = p.rating!;
    if (p.site != null) _assignSite(p.site);
    if (p.weightKg != null) {
      // Paper logs record a total; the carry type is unknown.
      _weights = [
        DiveWeight(
          id: _uuid.v4(),
          diveId: widget.diveId ?? '',
          weightType: WeightType.mixed,
          amountKg: p.weightKg!,
        ),
      ];
    }
    // Expand sections that received prefilled content so the user can
    // review what the scan extracted without hunting for it.
    if (p.notes != null || p.rating != null) {
      _expanded['experience'] = true;
    }
    if (p.waterTempCelsius != null || p.airTempCelsius != null) {
      _expanded['conditions'] = true;
    }
    if (p.tank case final t?) {
      final base = _tanks.isNotEmpty ? _tanks.first : null;
      // A tag that gives a volume describes the cylinder itself: its spec is
      // taken whole, never mixed with the default tank's. A tag with no
      // volume keeps the default cylinder, preset and all.
      final describesCylinder = t.volume != null;
      _tanks = [
        DiveTank(
          id: base?.id ?? _uuid.v4(),
          name: t.name,
          volume: describesCylinder ? t.volume : base?.volume,
          workingPressure: describesCylinder
              ? t.workingPressure
              : t.workingPressure ?? base?.workingPressure,
          startPressure: t.startPressure ?? base?.startPressure,
          endPressure: t.endPressure ?? base?.endPressure,
          gasMix: t.gasMix,
          role: t.role,
          material: describesCylinder
              ? t.material
              : t.material ?? base?.material,
          order: 0,
          presetName: describesCylinder ? t.presetName : base?.presetName,
          passportId: t.passportId,
          twinPassportId: t.twinPassportId,
        ),
        ..._tanks.skip(1),
      ];
      // A custom default preset loads asynchronously and replaces an
      // untouched first tank. A cylinder described by its tag must survive
      // that; a tag that describes nothing leaves the default free to load.
      if (t.name != null ||
          t.volume != null ||
          t.workingPressure != null ||
          t.material != null) {
        _tanksDirty = true;
      }
      _firstTankPrefilled = true;
      _loadedTankIds = {..._loadedTankIds, _tanks.first.id};
    } else if (p.startPressureBar != null ||
        p.endPressureBar != null ||
        p.o2Percent != null ||
        p.cylinderVolumeLiters != null) {
      final base = _tanks.isNotEmpty ? _tanks.first : null;
      _tanks = [
        DiveTank(
          id: base?.id ?? _uuid.v4(),
          volume: p.cylinderVolumeLiters ?? base?.volume,
          workingPressure: base?.workingPressure,
          startPressure: p.startPressureBar ?? base?.startPressure,
          endPressure: p.endPressureBar ?? base?.endPressure,
          gasMix: p.o2Percent != null
              ? GasMix(o2: p.o2Percent!)
              : (base?.gasMix ?? const GasMix()),
          role: base?.role ?? TankRole.backGas,
          material: base?.material,
          order: 0,
          presetName: base?.presetName,
        ),
        ..._tanks.skip(1),
      ];
      _firstTankPrefilled = true;
      _loadedTankIds = {..._loadedTankIds, _tanks.first.id};
    }
  }

  Future<void> _suggestNextDiveNumber() async {
    try {
      final repository = ref.read(diveRepositoryProvider);
      // The diver the dive will be saved under (see the save path), so the
      // number continues that diver's own log rather than the highest number
      // across every diver (#2508).
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final nextNumber = await repository.getNextDiveNumber(diverId: diverId);
      if (mounted && _diveNumberController.text.isEmpty) {
        _silently(() {
          setState(() {
            _diveNumberController.text = _seedInt(nextNumber);
          });
        });
      }
    } catch (_) {
      // Non-critical — field remains blank, auto-assigned on save
    }
  }

  /// Seeds the fields a dive takes from its primary data source: entry and
  /// exit, bottom time, runtime and water temperature. Call inside setState.
  void _seedSourceFields(Dive dive, UnitFormatter units) {
    // A refresh reseeds a form that already holds the previous primary's
    // values, so every input is written, blank where the dive has no value.
    final seeded = SeededDiveTimes.of(dive);
    final shown = seeded.shown;
    _seededTimes = seeded;
    _entryDate = shown.entry;
    _entryTime = TimeOfDay.fromDateTime(shown.entry);
    _exitDate = shown.exit;
    _exitTime = shown.exit == null ? null : TimeOfDay.fromDateTime(shown.exit!);
    _durationController.text = shown.bottomTimeMinutes == null
        ? ''
        : _seedInt(shown.bottomTimeMinutes!);
    _runtimeController.text = shown.runtimeMinutes == null
        ? ''
        : _seedInt(shown.runtimeMinutes!);
    _waterTempController.text = dive.waterTemp != null
        ? _seedDecimal(units.convertTemperature(dive.waterTemp!), 0)
        : '';
    _settleTimes();
  }

  /// Seeds the depth fields, which a saved profile edit recomputes. Call
  /// inside setState.
  void _seedDepthFields(Dive dive, UnitFormatter units) {
    // Convert stored metric values to user's preferred units
    _maxDepthController.text = dive.maxDepth != null
        ? _seedDecimal(units.convertDepth(dive.maxDepth!), 1)
        : '';
    _avgDepthController.text = dive.avgDepth != null
        ? _seedDecimal(units.convertDepth(dive.avgDepth!), 1)
        : '';
  }

  Future<void> _loadExistingDive() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(diveRepositoryProvider);
      final dive = await repository.getDiveById(widget.diveId!);
      if (dive != null && mounted) {
        // Get unit formatter to convert from stored metric to user's preferred units
        final settings = ref.read(settingsProvider);
        final units = UnitFormatter(settings);

        // Independent reads, so they run together.
        final (hasPrimarySource, loadedSwitches) = await (
          repository.hasPrimaryDataSource(dive.id),
          _loadGasSwitches(dive),
        ).wait;
        if (!mounted) return;
        setState(() {
          _existingDive = dive;
          _gasSwitches = loadedSwitches;
          _loadedGasSwitchIds = {for (final s in loadedSwitches) s.id};
          _loadedGasSwitchFloor = loadedSwitches.fold(
            0,
            (floor, s) => s.timestamp < floor ? s.timestamp : floor,
          );
          _isPlanned = dive.isPlanned;
          _hasPrimarySource = hasPrimarySource;
          _diverRoleIds = dive.diverRoleIds;
          _loadedRoleIds = {..._loadedRoleIds, ...dive.diverRoleIds};
          _diveNumberController.text = dive.diveNumber != null
              ? _seedInt(dive.diveNumber!)
              : '';
          _seedSourceFields(dive, units);
          _seedDepthFields(dive, units);
          _airTempController.text = dive.airTemp != null
              ? _seedDecimal(units.convertTemperature(dive.airTemp!), 0)
              : '';
          _notesController.text = dive.notes;
          _nameController.text = dive.name ?? '';
          _selectedDiveTypeIds = List.from(dive.diveTypeIds);
          _loadedDiveTypeIds = List.unmodifiable(dive.diveTypeIds);
          _originalVisibility = StoredVisibility.of(dive);
          _visibilityMode = _originalVisibility.naturalMode ?? _visibilityMode;
          _visibilityController.text = dive.visibilityMeters != null
              ? _seedDecimal(units.convertDepth(dive.visibilityMeters!), 0)
              : '';
          _rating = dive.rating ?? 0;
          _excludedFromStats = dive.excludedFromStats;
          _excludedFromGasStats = dive.excludedFromGasStats;
          _selectedSite = dive.site;
          _selectedTrip = dive.trip;
          _selectedDiveCenter = dive.diveCenter;
          _selectedCourseIds = List.of(dive.courseIds);

          // Load all tanks from the dive
          _loadedTankIds = {for (final t in dive.tanks) t.id};
          if (dive.tanks.isNotEmpty) {
            _tanks = List.from(dive.tanks);
            _markDirty();
            _tanksDirty = true;
          }

          // Load equipment with its provenance
          _selectedEquipment = List.from(dive.equipment);
          _gearProvenance = dive.gearProvenance;

          // Load conditions fields
          _currentDirection = dive.currentDirection;
          _currentStrength = dive.currentStrength;
          _entryMethod = dive.entryMethod;
          _exitMethod = dive.exitMethod;
          _exitMethodLinked =
              _exitMethod == null || _exitMethod == _entryMethod;
          // A dive with no water type of its own shows its site's, as the
          // detail page does; saving then stores it (issue #3196).
          _waterType = dive.effectiveWaterType;
          _waterTypeFromSite = dive.waterType == null && _waterType != null;
          _swellHeightController.text = dive.swellHeight != null
              ? _seedDecimal(units.convertDepth(dive.swellHeight!), 1)
              : '';
          _altitudeController.text = dive.altitude != null
              ? _seedDecimal(units.convertAltitude(dive.altitude!), 0)
              : '';
          _surfacePressureController.text = dive.surfacePressure != null
              // Convert bar to mbar
              ? _seedDecimal(dive.surfacePressure! * 1000, 0)
              : '';

          // Load weather fields
          _windDirection = dive.windDirection;
          _cloudCover = dive.cloudCover;
          _precipitation = dive.precipitation;
          _weatherSource = dive.weatherSource;
          _weatherFetchedAt = dive.weatherFetchedAt;
          _windSpeedController.text = dive.windSpeed != null
              ? _seedDecimal(units.convertWindSpeed(dive.windSpeed!), 1)
              : '';
          _humidityController.text = dive.humidity != null
              ? _seedDecimal(dive.humidity!, 0)
              : '';
          _weatherDescriptionController.text = dive.weatherDescription ?? '';
          _diveOperatorController.text = dive.diveOperator ?? '';
          _boatNameController.text = dive.boatName ?? '';
          _boatCaptainController.text = dive.boatCaptain ?? '';
          _surfaceConditionsController.text = dive.surfaceConditions ?? '';

          // Load weight entries (weights already stored in kg, conversion happens in display)
          // Migrate legacy single weight to weights list if needed
          _weights =
              dive.weights.isEmpty &&
                  dive.weightAmount != null &&
                  dive.weightAmount! > 0
              ? [
                  DiveWeight(
                    id: _uuid.v4(),
                    diveId: dive.id,
                    weightType: dive.weightType ?? WeightType.belt,
                    amountKg: dive.weightAmount!,
                  ),
                ]
              : List.of(dive.weights);

          // Load weighting feedback
          _weightingFeedback = dive.weightingFeedback;
          _weightingFeedbackAmountController.text =
              dive.weightingFeedbackKg != null
              ? _seedWeight(units.convertWeight(dive.weightingFeedbackKg!))
              : '';

          // Load tags
          _selectedTags = List.from(dive.tags);

          // Load custom fields
          _customFields = List.from(dive.customFields);

          // Load CCR/SCR rebreather settings
          _diveMode = dive.diveMode;
          _setpointLow = dive.setpointLow;
          _setpointHigh = dive.setpointHigh;
          _setpointDeco = dive.setpointDeco;
          _diluentGas = dive.diluentGas;
          _scrubberType = dive.scrubber?.type;
          _scrubberDurationMinutes = dive.scrubber?.ratedMinutes;
          _scrubberRemainingMinutes = dive.scrubber?.remainingMinutes;
          _loopVolume = dive.loopVolume;
          _scrType = dive.scrType;
          _scrInjectionRate = dive.scrInjectionRate;
          _scrAdditionRatio = dive.scrAdditionRatio;
          _scrOrificeSize = dive.scrOrificeSize;
          _scrSupplyGas =
              dive.diluentGas; // SCR uses diluent field for supply gas
          _assumedVo2 = dive.assumedVo2;
          _loopO2Min = dive.loopO2Min;
          _loopO2Max = dive.loopO2Max;
          _loopO2Avg = dive.loopO2Avg;
        });
        // Load existing sightings and buddies
        await Future.wait([
          _loadSightings(),
          _loadBuddies(),
          _loadRouteLinks(),
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _suppressDirty = false;
        unawaited(_maybeAutoFillAltitude());
      }
    }
  }

  /// Capture device GPS in background for suggesting nearby sites
  Future<void> _captureLocationForNearby() async {
    setState(() => _isCapturingLocation = true);
    try {
      final location = await LocationService.instance.getCurrentLocation(
        includeGeocoding:
            false, // We just need coordinates for distance calculation
        timeout: const Duration(seconds: 10),
      );
      if (mounted && location != null) {
        setState(() => _currentLocation = location);
      }
    } catch (e) {
      // Silently fail - GPS is optional for nearby suggestions
    } finally {
      if (mounted) {
        setState(() => _isCapturingLocation = false);
      }
    }
  }

  Future<void> _loadSightings() async {
    if (widget.diveId == null) return;
    final repository = ref.read(speciesRepositoryProvider);
    final sightings = await repository.getSightingsForDive(widget.diveId!);
    if (mounted) {
      setState(() {
        _sightings = sightings;
        _originalSightingIds = sightings.map((s) => s.id).toSet();
      });
    }
  }

  Future<void> _loadBuddies() async {
    if (widget.diveId == null) return;
    final repository = ref.read(buddyRepositoryProvider);
    final buddies = await repository.getBuddiesForDive(widget.diveId!);
    if (mounted) {
      setState(() {
        _selectedBuddies = buddies;
        _originalBuddyIds = buddies.map((b) => b.buddy.id).toSet();
        _loadedRoleIds = {
          ..._loadedRoleIds,
          for (final b in buddies) ...b.roleIds,
        };
      });
    }
  }

  Future<void> _loadRouteLinks() async {
    final diveId = widget.diveId;
    if (diveId == null) return;
    try {
      final linked = await ref.read(navTracksForDiveProvider(diveId).future);
      if (mounted) {
        setState(() => _routeDraft = DiveRouteLinkDraft.initial(linked));
      }
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load route links for dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _routeLinksFailed = true);
    }
  }

  Future<void> _openRouteSheet() async {
    final draft = _routeDraft;
    if (draft == null) return;
    await showRouteLinkSheet(
      context,
      draft: draft,
      entryTime: _currentEntryTime(),
      onChanged: (next) {
        setState(() => _routeDraft = next);
        _markDirty();
      },
    );
  }

  @override
  void dispose() {
    _diveNumberController.dispose();
    _durationController.dispose();
    _runtimeController.dispose();
    _maxDepthController.dispose();
    _avgDepthController.dispose();
    _waterTempController.dispose();
    _airTempController.dispose();
    _notesController.dispose();
    _nameController.dispose();
    _swellHeightController.dispose();
    _visibilityController.dispose();
    _altitudeController.dispose();
    _surfacePressureController.dispose();
    _windSpeedController.dispose();
    _humidityController.dispose();
    _weatherDescriptionController.dispose();
    _diveOperatorController.dispose();
    _boatNameController.dispose();
    _boatCaptainController.dispose();
    _surfaceConditionsController.dispose();
    _weightingFeedbackAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);

    if (_isLoading) {
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? context.l10n.diveLog_edit_appBarEdit
                : context.l10n.diveLog_edit_appBarNew,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final formBody = Form(
      key: _formKey,
      onChanged: _markDirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pinned above the scrolling form so the warning stays visible.
          FlightWindowWarningBanner(
            tripId: _selectedTrip?.id,
            diveEndTime: _currentDiveEndTime(),
          ),
          // Split after Gas & Gear so the two always-relevant groups lead
          // the left column and the contextual ones fill the right on wide
          // windows. ResponsiveFormColumns owns the scroll view, so it
          // needs the bounded height Expanded provides.
          if (!_hasPrimarySource && !_isDraft)
            SwitchListTile(
              key: const Key('dive_edit_planned_switch'),
              value: _isPlanned,
              title: Text(context.l10n.diveLog_edit_planned_switch),
              subtitle: Text(context.l10n.diveLog_edit_planned_switchSubtitle),
              secondary: const Icon(Icons.event_available_outlined),
              onChanged: (value) {
                setState(() {
                  _isPlanned = value;
                  if (value) _diveNumberController.clear();
                });
                _markDirty();
                if (!value && _diveNumberController.text.isEmpty) {
                  _suggestNextDiveNumber();
                }
              },
            ),
          Expanded(
            child: ResponsiveFormColumns(
              splitIndex: 2,
              children: [
                _buildTheDiveSection(units),
                _buildGasGearSection(units),
                _buildConditionsSection(units),
                _buildTripGroupSection(units),
                _buildBuddiesSection(),
                _buildExperienceSection(),
                if (_showCourseSection) _buildCourseGroupSection(),
                if (_showCustomFieldsSection) _buildCustomFieldsGroupSection(),
                _buildStatisticsSection(),
                AddSectionRow(
                  entries: [
                    if (!_showCourseSection)
                      AddSectionEntry(
                        label:
                            context.l10n.diveLog_edit_section_trainingCourses,
                        onTap: () => setState(() => _expanded['course'] = true),
                      ),
                    if (!_showCustomFieldsSection)
                      AddSectionEntry(
                        label: context.l10n.diveLog_edit_section_customFields,
                        onTap: () =>
                            setState(() => _expanded['customFields'] = true),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return EditFormScaffold(
      title: widget.isEditing
          ? context.l10n.diveLog_edit_appBarEdit
          : context.l10n.diveLog_edit_appBarNew,
      embedded: widget.embedded,
      isSaving: _isSaving,
      hasUnsavedChanges: _hasUnsavedChanges,
      onSave: () => _saveDive(units),
      onCancel: widget.onCancel,
      headerIcon: widget.isEditing ? Icons.edit : Icons.add_circle_outline,
      child: formBody,
    );
  }

  // === Bulk edit mode ===
  // Filled in across Phases 2-5. Shell + stubs here so bulk mode compiles.

  // Bulk-mode state.
  // Tanks "Update" mode (#797): a template cylinder plus the mask of which of
  // its attributes to write onto the tanks each dive already has.
  // Bulk tri-state membership state for each reference collection: the members
  // shown across the selected dives (existing + picker-added), their per-item
  // dive counts, and the resulting add/remove delta.
  // The dives' training courses (#2515).
  Widget _customFieldsChild() {
    final currentDiverId = ref.watch(currentDiverIdProvider);
    final suggestions = currentDiverId != null
        ? ref
                  .watch(customFieldKeySuggestionsProvider(currentDiverId))
                  .valueOrNull ??
              []
        : <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_customFields.isNotEmpty) const Divider(),
          if (_customFields.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _customFields.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _customFields.removeAt(oldIndex);
                  _customFields.insert(newIndex, item);
                  for (var i = 0; i < _customFields.length; i++) {
                    _customFields[i] = _customFields[i].copyWith(sortOrder: i);
                  }
                });
              },
              itemBuilder: (context, index) {
                final field = _customFields[index];
                return CustomFieldInputRow(
                  key: ValueKey(field.id),
                  index: index,
                  field: field,
                  keySuggestions: suggestions,
                  onChanged: (updated) {
                    setState(() {
                      _markDirty();
                      _customFields[index] = updated;
                    });
                  },
                  onDelete: () {
                    setState(() {
                      _markDirty();
                      _customFields.removeAt(index);
                    });
                  },
                );
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _markDirty();
                _customFields.add(
                  DiveCustomField(
                    id: _uuid.v4(),
                    key: '',
                    value: '',
                    sortOrder: _customFields.length,
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.diveLog_edit_addCustomField),
          ),
        ],
      ),
    );
  }

  Widget _buildTheDiveSection(UnitFormatter units) {
    final hasProfile = _existingDive?.profile.isNotEmpty == true;
    return TheDiveSection(
      depthSymbol: units.depthSymbol,
      nameController: _nameController,
      maxDepthController: _maxDepthController,
      avgDepthController: _avgDepthController,
      bottomTimeController: _durationController,
      runtimeController: _runtimeController,
      onRuntimeChanged: (_) => _followRuntime(),
      diveNumberController: _diveNumberController,
      showDiveNumber: !_isPlanned && !_isDraft,
      entryText: _formatEntryText(units),
      onEditEntry: _editEntry,
      exitText: _formatExitText(units),
      onEditExit: _editExit,
      siteName: _selectedSite?.name,
      onPickSite: _showSitePicker,
      onClearSite: () {
        _markDirty();
        setState(() => _assignSite(null));
      },
      // A planned dive has no recording to link (spec 2026-10-02, section 1).
      routeRow: _isPlanned
          ? null
          : RouteRow(
              draft: _routeDraft,
              loadFailed: _routeLinksFailed,
              onTap: _openRouteSheet,
            ),
      maxDepthSuggestion: hasProfile
          ? _depthSuggestion(
              units,
              _existingDive!.calculateMaxDepthFromProfile(),
              () => _calculateMaxDepthFromProfile(units),
            )
          : null,
      avgDepthSuggestion: hasProfile
          ? _depthSuggestion(
              units,
              _existingDive!.calculateAvgDepthFromProfile(),
              () => _calculateAvgDepthFromProfile(units),
            )
          : null,
      bottomTimeSuggestion: hasProfile
          ? _minutesSuggestion(
              _existingDive!.calculateBottomTimeFromProfile(),
              _calculateBottomTimeFromProfile,
            )
          : null,
      runtimeSuggestion: hasProfile
          ? _minutesSuggestion(
              _existingDive!.calculateRuntimeFromProfile(),
              _calculateRuntimeFromProfile,
            )
          : null,
      surfaceIntervalRow: _surfaceIntervalRow(),
      siteExtras: _siteExtras(),
      diveTypesRow: _diveTypesRow(),
      profileChild: _profileChild(),
    );
  }

  /// The dive type picker, shown in the always-open "The Dive" group. It used
  /// to sit in the collapsed Conditions group, where divers could not find it
  /// to correct an imported dive's type (issue #2596).
  Widget _diveTypesRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: DiveTypeMultiSelectField(
        selectedTypeIds: _selectedDiveTypeIds,
        keepTypeIds: _loadedDiveTypeIds,
        onChanged: (ids) {
          setState(() {
            _selectedDiveTypeIds = ids;
            _siteAddedDiveTypeIds = siteAddedAfterManualEdit(
              siteAddedIds: _siteAddedDiveTypeIds,
              selectedTypeIds: ids,
            );
          });
          // The picker is a bottom sheet, not a FormField, so Form.onChanged
          // never sees it; without this, leaving drops the new type unasked.
          _markDirty();
        },
      ),
    );
  }

  ProfileSuggestion? _depthSuggestion(
    UnitFormatter units,
    double? meters,
    VoidCallback onUse,
  ) {
    if (meters == null) return null;
    return ProfileSuggestion(
      value: _seedDecimal(units.convertDepth(meters), 1),
      onUse: onUse,
      tooltip: context.l10n.diveLog_edit_tooltip_calculateFromProfile,
    );
  }

  ProfileSuggestion? _minutesSuggestion(
    Duration? duration,
    VoidCallback onUse,
  ) {
    if (duration == null) return null;
    return ProfileSuggestion(
      value: _seedInt(duration.inMinutes),
      onUse: onUse,
      tooltip: context.l10n.diveLog_edit_tooltip_calculateFromProfile,
    );
  }

  String _formatEntryText(UnitFormatter units) =>
      '${units.formatDate(_entryDate)}, ${_entryTime.format(context)}';

  String? _formatExitText(UnitFormatter units) {
    if (_exitDate == null || _exitTime == null) return null;
    return '${units.formatDate(_exitDate!)}, ${_exitTime!.format(context)}';
  }

  Widget? _surfaceIntervalRow() {
    if (!widget.isEditing || widget.diveId == null) return null;
    final interval = ref
        .watch(surfaceIntervalProvider(widget.diveId!))
        .valueOrNull;
    if (interval == null) return null;
    return FormRow.display(
      label: context.l10n.diveLog_edit_row_surfaceInterval,
      value: formatElapsed(context.l10n, interval),
    );
  }

  Widget? _siteExtras() {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (_isCapturingLocation) {
      children.add(
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.diveLog_edit_gettingLocation,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      );
    } else if (_currentLocation != null && !widget.isEditing) {
      children.add(
        Row(
          children: [
            Icon(Icons.my_location, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              context.l10n.diveLog_edit_nearbySitesFirst,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      );
    }
    if (_selectedSite != null && _selectedSite!.locationString.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _selectedSite!.locationString,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (widget.diveId != null) {
      children.add(
        SiteSuggestionCard(
          diveId: widget.diveId!,
          currentSite: _selectedSite,
          onSiteChanged: (site) => setState(() => _assignSite(site)),
        ),
      );
    }
    if (children.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// Assigns [site] to the dive and snaps the water type and the entry/exit
  /// methods from it (manual overrides survive; see the rules on
  /// [entryExitAfterSiteAssign]). Use for user-initiated assignments and
  /// new-dive prefill — NOT the load path, which restores the dive's own
  /// saved values.
  void _assignSite(DiveSite? site) {
    _selectedSite = site;
    _waterType = waterTypeAfterSiteAssign(
      _waterTypeFromSite ? null : _waterType,
      site,
    );
    _waterTypeFromSite = false;
    final entryExit = entryExitAfterSiteAssign(
      currentEntry: _entryMethod,
      currentExit: _exitMethod,
      currentLinked: _exitMethodLinked,
      site: site,
    );
    _entryMethod = entryExit.entry;
    _exitMethod = entryExit.exit;
    _exitMethodLinked = entryExit.linked;
    unawaited(_maybeAutoFillAltitude());
    final snap = _snapDiveTypesFromSite(site, markDirty: !_suppressDirty);
    _pendingDiveTypeSnap = snap;
    unawaited(snap);
  }

  /// Adds the dive types [site]'s types stand for, taking back what the
  /// previous site added (see [diveTypesAfterSiteAssign]). The site's types
  /// live in a junction table rather than on [DiveSite], so they are fetched;
  /// a result that arrives after the diver picked another site is dropped.
  /// [markDirty] is whether the assignment was the diver's rather than a
  /// load or prefill, since the result lands after dirty tracking resumes.
  Future<void> _snapDiveTypesFromSite(
    DiveSite? site, {
    required bool markDirty,
  }) async {
    final siteId = site?.id;
    List<String> siteDiveTypeIds = const [];
    if (siteId != null) {
      try {
        final siteTypes = await ref.read(
          siteTypesForSiteProvider(siteId).future,
        );
        final diveTypes = await ref.read(diveTypesProvider.future);
        siteDiveTypeIds = diveTypeIdsForSiteTypes(
          siteTypes: siteTypes,
          diveTypes: diveTypes,
        );
      } catch (e, stackTrace) {
        // Leave the dive types as they are: the snap is a convenience, and
        // the diver can still set them by hand.
        _log.warning(
          'Could not read the types of site $siteId',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
    }
    if (!mounted || _selectedSite?.id != siteId) return;
    final result = diveTypesAfterSiteAssign(
      currentTypeIds: _selectedDiveTypeIds,
      previousSiteAddedIds: _siteAddedDiveTypeIds,
      siteDiveTypeIds: siteDiveTypeIds,
    );
    final changed = !listEquals(result.typeIds, _selectedDiveTypeIds);
    setState(() {
      _selectedDiveTypeIds = result.typeIds;
      _siteAddedDiveTypeIds = result.siteAddedIds;
    });
    if (changed && markDirty) _markDirty();
  }

  /// Where this dive probably was, from the dives logged around it: the
  /// site of the nearest dive of the same trip, else of one within a few
  /// days. For a dive with no GPS of its own, so the picker can lead with
  /// the sites of that area. Null when nothing says; never fails the picker.
  Future<SiteAreaAnchor?> _areaAnchor() async {
    try {
      final repository = ref.read(siteAreaAnchorRepositoryProvider);
      final diverId =
          _existingDive?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      return await repository.forDive(
        at: _currentEntryTime(),
        tripId: _selectedTrip?.id,
        diverId: diverId,
        excludeDiveIds: [if (widget.diveId != null) widget.diveId!],
      );
    } catch (e, stackTrace) {
      _log.warning(
        'Could not work out the area of the dive for the site picker',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// True from a tap on the Site row until its picker has closed. Working
  /// out the dive's area takes a moment before the sheet shows, and a
  /// second tap in that moment would open a second sheet over the first.
  bool _openingSitePicker = false;

  Future<void> _showSitePicker() async {
    if (_openingSitePicker) return;
    _openingSitePicker = true;
    try {
      final anchor =
          _existingDive?.entryLocation ?? _existingDive?.exitLocation;
      // A dive with its own GPS needs no inference.
      final areaAnchor = anchor == null ? await _areaAnchor() : null;
      if (!mounted) return;
      final site = await pickOrCreateSite(
        context,
        ref,
        selectedSiteId: _selectedSite?.id,
        currentLocation: _currentLocation,
        diveLocation: anchor,
        areaAnchor: areaAnchor,
        newSiteSeedLocation: anchor,
      );
      if (site != null && mounted) {
        _markDirty();
        setState(() => _assignSite(site));
        _reevaluateGeofenceForSite();
      }
    } finally {
      _openingSitePicker = false;
    }
  }

  Widget _buildTripGroupSection(UnitFormatter units) {
    final diveDateTime = DateTime(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
      _entryTime.hour,
      _entryTime.minute,
    );
    return TripSection(
      expanded: _isExpanded('trip', defaultValue: false),
      onToggle: () => _toggleSection('trip', defaultValue: false),
      summary: _tripSummary(),
      isEmpty:
          _selectedTrip == null &&
          _selectedDiveCenter == null &&
          trimmedOrNull(_diveOperatorController.text) == null &&
          trimmedOrNull(_boatNameController.text) == null &&
          trimmedOrNull(_boatCaptainController.text) == null,
      logisticsRows: _logisticsRows(),
      tripName: _selectedTrip?.name,
      tripCaption: _selectedTrip != null
          ? units.formatDateRange(
              _selectedTrip!.startDate,
              _selectedTrip!.endDate,
              l10n: context.l10n,
            )
          : null,
      onPickTrip: _showTripPicker,
      onClearTrip: () => _setTrip(null),
      tripSuggestion: _selectedTrip == null
          ? _buildTripSuggestion(diveDateTime)
          : null,
      diveCenterName: _selectedDiveCenter?.name,
      centerCaption: _selectedDiveCenter?.displayLocation,
      centerChild: _selectedDiveCenter == null
          ? null
          : RentalMemoryCard(
              center: _selectedDiveCenter!,
              currentDiveId: widget.diveId,
              onApplyLastDive: _applyLastDiveAtCenter,
            ),
      onPickDiveCenter: _showDiveCenterPicker,
      onClearDiveCenter: () {
        _markDirty();
        setState(() => _selectedDiveCenter = null);
      },
    );
  }

  String _tripSummary() => [
    if (_selectedTrip != null) _selectedTrip!.name,
    if (_selectedDiveCenter != null) _selectedDiveCenter!.name,
    ?trimmedOrNull(_boatNameController.text),
  ].join(' · ');

  List<Widget> _logisticsRows() {
    final l10n = context.l10n;
    return [
      SuggestedTextRow(
        label: l10n.diveLog_edit_row_diveOperator,
        controller: _diveOperatorController,
        field: DiveTextSuggestionField.diveOperator,
      ),
      SuggestedTextRow(
        label: l10n.diveLog_edit_row_boatName,
        controller: _boatNameController,
        field: DiveTextSuggestionField.boatName,
      ),
      SuggestedTextRow(
        label: l10n.diveLog_edit_row_boatCaptain,
        controller: _boatCaptainController,
        field: DiveTextSuggestionField.boatCaptain,
      ),
    ];
  }

  Widget _buildTripSuggestion(DateTime diveDateTime) {
    final suggestedTripAsync = ref.watch(tripForDateProvider(diveDateTime));

    return suggestedTripAsync.when(
      data: (suggestedTrip) {
        if (suggestedTrip == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            button: true,
            label: 'Use suggested trip ${suggestedTrip.name}',
            child: InkWell(
              onTap: () => _setTrip(suggestedTrip),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.diveLog_edit_tripSuggested(
                        suggestedTrip.name,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _setTrip(suggestedTrip),
                    child: Text(context.l10n.diveLog_edit_tripUse),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Every change of the dive's trip goes through here. Tank links point
  /// into one trip's cylinders, so a different trip (or none) drops them
  /// all at once, with their suggestion marks, and new tanks get a
  /// suggestion from the new trip.
  void _setTrip(Trip? trip, {bool markDirty = true}) {
    if (markDirty) _markDirty();
    final changed = trip?.id != _selectedTrip?.id;
    setState(() {
      _selectedTrip = trip;
      if (changed && _tanks.any((t) => t.tripCylinderId != null)) {
        _tanks = [
          for (final t in _tanks)
            t.tripCylinderId == null
                ? t
                : t.copyWith(clearTripCylinderId: true),
        ];
        _tanksDirty = true;
      }
      if (changed) {
        _suggestedTankIds = const {};
        _declinedTankIds = const {};
      }
    });
    if (changed) {
      logFailure(
        _suggestTripCylinders(),
        _DiveEditPageState,
        'suggest trip cylinders',
      );
    }
  }

  /// The trip's cylinders as they stood when this dive starts, never
  /// counting this dive's own use (decided 2026-09-29).
  ({String tripId, int atMillis, String? excludeDiveId}) _tripCylinderKeyFor(
    String tripId,
  ) => (
    tripId: tripId,
    atMillis: _currentEntryTime().millisecondsSinceEpoch,
    excludeDiveId: widget.diveId,
  );

  /// The trip's slots at this dive's start, read once. The provider is
  /// auto-disposed, so a listener holds it while the read is in flight.
  Future<List<TripCylinderState>> _readTripCylinderStates(String tripId) async {
    final provider = tripCylinderStatesAtProvider(_tripCylinderKeyFor(tripId));
    final hold = ref.listenManual(provider, (_, _) {});
    try {
      return await ref.read(provider.future);
    } finally {
      hold.close();
    }
  }

  /// Suggests a full trip cylinder for each tank added in this editing
  /// session that has none and whose suggestion the diver has not turned
  /// down. Runs when the trip is set and when a tank is added.
  Future<void> _suggestTripCylinders() async {
    final tripId = _selectedTrip?.id;
    if (tripId == null) return;
    final states = await _readTripCylinderStates(tripId);
    if (!mounted || _selectedTrip?.id != tripId) return;
    final result = suggestTripCylindersForTanks(
      tanks: _tanks,
      states: states,
      eligibleTankIds: {
        for (final t in _tanks)
          if (!_loadedTankIds.contains(t.id) &&
              !_declinedTankIds.contains(t.id))
            t.id,
      },
    );
    if (result.suggested.isEmpty) return;
    setState(() {
      _tanks = result.tanks;
      _suggestedTankIds = {..._suggestedTankIds, ...result.suggested};
      // Keeps _loadDefaultPreset from rebuilding the first tank over it.
      _tanksDirty = true;
    });
  }

  /// The board's Log dive shortcut: the new dive goes on [tripId], and its
  /// first tank breathes from [cylinderId], filled from that slot. The
  /// diver chose the slot, so it is not marked as a suggestion; any other
  /// new tank, or a slot that no longer exists, gets the usual suggestion.
  Future<void> _applyTripLink(String tripId, String? cylinderId) async {
    final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
    // A trip the diver picked while this loaded stands.
    if (trip == null || !mounted || _selectedTrip != null) return;
    final states = await _readTripCylinderStates(tripId);
    if (!mounted || _selectedTrip != null) return;
    final slot = states.where((s) => s.cylinder.id == cylinderId).firstOrNull;
    setState(() {
      _selectedTrip = trip;
      if (slot != null && _tanks.isNotEmpty) {
        _tanks = [tankFromTripCylinder(_tanks.first, slot), ..._tanks.skip(1)];
        _tanksDirty = true;
      }
    });
    await _suggestTripCylinders();
  }

  Future<void> _showTripPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => TripPickerSheet(
          scrollController: scrollController,
          selectedTrip: _selectedTrip,
          onTripSelected: (trip) {
            Navigator.of(sheetContext).pop();
            _setTrip(trip);
          },
          onCreateNewTrip: () {
            Navigator.of(sheetContext).pop(_createNewTripSentinel);
          },
        ),
      ),
    );

    if (result == _createNewTripSentinel && mounted) {
      final tripId = await newTripForDiveEdit(context, ref, _newTripFacts);
      if (tripId != null && mounted) {
        final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
        if (trip != null && mounted) _setTrip(trip);
      }
    }
  }

  /// What a trip created from this form learns from its dives (#3351): the
  /// selected dives in bulk edit, else the dive as the form holds it, saved
  /// or not.
  Future<List<SelectionDiveFacts>> _newTripFacts() async {
    return [
      SelectionDiveFacts(
        diveId: '',
        diveDateTime: DateTime.utc(
          _entryDate.year,
          _entryDate.month,
          _entryDate.day,
        ),
        tripId: _selectedTrip?.id,
        siteRegion: _selectedSite?.region,
        siteCountry: _selectedSite?.country,
        diveCenterName: _selectedDiveCenter?.name,
      ),
    ];
  }

  Future<void> _showDiveCenterPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => DiveCenterPickerSheet(
          scrollController: scrollController,
          selectedCenter: _selectedDiveCenter,
          // Centers near the dive first (#3379): the site, else the dive's
          // GPS, else where a new dive was logged from.
          reference: resolveDiveCenterPickerReference(
            site: _selectedSite,
            entryLocation: _existingDive?.entryLocation,
            exitLocation: _existingDive?.exitLocation,
            deviceLocation: _currentLocation == null
                ? null
                : GeoPoint(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                  ),
          ),
          onCenterSelected: (center) {
            Navigator.of(sheetContext).pop();
            _markDirty();
            setState(() => _selectedDiveCenter = center);
          },
          onCreateNewCenter: () {
            Navigator.of(sheetContext).pop(_createNewDiveCenterSentinel);
          },
        ),
      ),
    );

    if (result == _createNewDiveCenterSentinel && mounted) {
      final centerId = await context.push<String>('/dive-centers/new');
      if (centerId != null && mounted) {
        final repo = ref.read(diveCenterRepositoryProvider);
        final center = await repo.getDiveCenterById(centerId);
        if (center != null && mounted) {
          _markDirty();
          setState(() => _selectedDiveCenter = center);
        }
      }
    }
  }

  /// The selected course names for the collapsed section's summary.
  String _courseSummary() {
    final names = {
      for (final c in ref.watch(courseListNotifierProvider).value ?? const [])
        c.id: c.name,
    };
    return [
      for (final id in _selectedCourseIds)
        if (names[id] != null) names[id]!,
    ].join(', ');
  }

  Widget _buildCourseGroupSection() {
    return RareSection(
      label: context.l10n.diveLog_edit_section_trainingCourses,
      icon: Icons.school_outlined,
      expanded: _isExpanded(
        'course',
        defaultValue: _selectedCourseIds.isNotEmpty,
      ),
      onToggle: () =>
          _toggleSection('course', defaultValue: _selectedCourseIds.isNotEmpty),
      summary: _courseSummary(),
      isEmpty: _selectedCourseIds.isEmpty,
      emptyInvitation: context.l10n.diveLog_edit_trainingCoursesHint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_trainingCoursesHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            CourseMultiSelectField(
              selectedCourseIds: _selectedCourseIds,
              onChanged: (ids) {
                // The picker is a sheet, not a FormField, so Form.onChanged
                // never sees it.
                _markDirty();
                setState(() => _selectedCourseIds = ids);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldsGroupSection() {
    return RareSection(
      label: context.l10n.diveLog_edit_section_customFields,
      icon: Icons.tune,
      expanded: _isExpanded(
        'customFields',
        defaultValue: _customFields.isNotEmpty,
      ),
      onToggle: () => _toggleSection(
        'customFields',
        defaultValue: _customFields.isNotEmpty,
      ),
      summary: '${_customFields.length}',
      isEmpty: _customFields.isEmpty,
      emptyInvitation: context.l10n.diveLog_edit_addCustomField,
      child: _customFieldsChild(),
    );
  }

  Widget _buildStatisticsSection() {
    return StatisticsSection(
      // Collapsed unless this dive is already excluded, so the setting stays
      // out of the way of the dives that are just dives.
      expanded: _isExpanded(
        'statistics',
        defaultValue: _excludedFromStats || _excludedFromGasStats,
      ),
      onToggle: () => _toggleSection(
        'statistics',
        defaultValue: _excludedFromStats || _excludedFromGasStats,
      ),
      excludedFromStats: _excludedFromStats,
      excludedFromGasStats: _excludedFromGasStats,
      onExcludedFromStatsChanged: (v) {
        _markDirty();
        setState(() {
          _excludedFromStats = v;
          _pinStatisticsOpen();
        });
      },
      onExcludedFromGasStatsChanged: (v) {
        _markDirty();
        setState(() {
          _excludedFromGasStats = v;
          _pinStatisticsOpen();
        });
      },
    );
  }

  /// The section's default expansion follows the two flags, so clearing the
  /// last one would otherwise shut the group under the diver's finger. Once
  /// they have touched a toggle, expansion is theirs to decide.
  void _pinStatisticsOpen() => _expanded['statistics'] = true;

  Widget _buildExperienceSection() {
    return ExperienceSection(
      expanded: _isExpanded('experience', defaultValue: false),
      onToggle: () => _toggleSection('experience', defaultValue: false),
      summary: _experienceSummary(),
      isEmpty: _experienceSummary().isEmpty,
      rating: _rating,
      onRatingChanged: (v) {
        _markDirty();
        setState(() => _rating = v);
      },
      notesController: _notesController,
      notesPlaceholder: context.l10n.diveLog_edit_notesHint,
      sightingsChild: _sightingsChild(),
      tagsChild: _tagsChild(),
      onAnnotate: _requestAnnotation,
    );
  }

  String _experienceSummary() {
    final l10n = context.l10n;
    return [
      if (_rating > 0) '★' * _rating,
      if (_sightings.isNotEmpty)
        l10n.diveLog_edit_summary_species(_sightings.length),
      if (_notesController.text.trim().isNotEmpty)
        l10n.diveLog_edit_summary_notes,
      if (_selectedTags.isNotEmpty) '#${_selectedTags.length}',
    ].join(' · ');
  }

  Widget _tagsChild() {
    return TagFormBlock(
      label: context.l10n.diveLog_edit_section_tags,
      selectedTags: _selectedTags,
      onTagsChanged: (tags) {
        _markDirty();
        setState(() => _selectedTags = tags);
      },
      scope: TagScope.dives,
    );
  }

  /// Opens the profile editor (issue #3066), then reads the dive again.
  Future<void> _openProfileEditor(String diveId, {String? initialMode}) async {
    final result = await openProfileEditor(
      context,
      ref,
      diveId,
      initialMode: initialMode,
    );
    if (!result.saved || !mounted) return;
    await _refreshAfterProfileSave(diveId, promoted: result.promoted);
  }

  /// A saved profile edit recomputed the dive's depths, and a change of
  /// primary source also replaced the fields taken from it. Reload them so
  /// saving this form does not write the old values back.
  Future<void> _refreshAfterProfileSave(
    String diveId, {
    required bool promoted,
  }) async {
    final dive = await ref.read(diveRepositoryProvider).getDiveById(diveId);
    if (dive == null || !mounted) return;
    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      _existingDive = dive;
      _seedDepthFields(dive, units);
      if (promoted) _seedSourceFields(dive, units);
    });
  }

  Widget _profileChild() {
    final l10n = context.l10n;
    final hasProfile = _existingDive?.profile.isNotEmpty == true;
    final profileLength = _existingDive?.profile.length ?? 0;
    final diveId = _existingDive?.id;
    if (hasProfile) {
      int? availableRevisions;
      if (diveId != null) {
        // `value` keeps the last history while it reloads, so the row does
        // not drop back to the points-only label on every refresh.
        final revisions = ref.watch(profileSeriesHistoryProvider(diveId)).value;
        if (revisions != null) {
          // Keep the row stable if history metadata is temporarily sparse.
          availableRevisions = revisions.isNotEmpty ? revisions.length : 1;
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.picker(
            label: l10n.diveLog_edit_row_diveProfile,
            value: availableRevisions == null || availableRevisions <= 1
                ? l10n.diveLog_edit_profile_points(profileLength)
                : l10n.diveLog_edit_profile_pointsAndProfiles(
                    profileLength,
                    availableRevisions,
                  ),
            onTap: () => _openProfileEditor(_existingDive!.id),
          ),
          Consumer(
            builder: (context, ref, _) {
              final outliersAsync = ref.watch(
                outlierSuggestionProvider(_existingDive!.id),
              );
              return outliersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (outliers) {
                  if (outliers.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(Icons.warning_amber, size: 18),
                        label: Text(
                          l10n.diveLog_edit_profile_outliers(outliers.length),
                        ),
                        onPressed: () => _openProfileEditor(
                          _existingDive!.id,
                          initialMode: 'outlier',
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    }
    if (widget.isEditing) {
      return FormRow.picker(
        label: l10n.diveLog_edit_row_diveProfile,
        value: null,
        placeholder: l10n.diveLog_edit_profile_draw,
        onTap: () => context.pushNamed(
          'editProfile',
          pathParameters: {'diveId': widget.diveId!},
          queryParameters: {'mode': 'draw'},
        ),
      );
    }
    return FormRow.display(
      label: l10n.diveLog_edit_row_diveProfile,
      value: l10n.diveLog_edit_profile_none,
    );
  }

  Widget _buildGasGearSection(UnitFormatter units) {
    final defaultExpanded = !widget.isEditing;
    // `value`, not `valueOrNull`: the list survives a reload, so a linked
    // tank never flickers to None while the provider refetches. Null until
    // the first load: no picker yet, rather than a list that looks empty.
    final tripId = _selectedTrip?.id;
    final List<TripCylinderState>? slotStates = tripId == null
        ? null
        : ref
              .watch(tripCylinderStatesAtProvider(_tripCylinderKeyFor(tripId)))
              .value;
    // The dive's primary source, which a tank with no computer and no
    // other source of its own belongs to (issue #2716). Read for every
    // saved dive, so it is loaded before the diver links a first tank: a
    // read that started only then would leave the first picks without it.
    final diveId = widget.diveId;
    final primarySourceId = diveId == null
        ? null
        : ref
              .watch(diveDataSourcesProvider(diveId))
              .value
              ?.where((s) => s.isPrimary)
              .firstOrNull
              ?.id;
    return GasGearSection(
      expanded: _isExpanded('gasGear', defaultValue: defaultExpanded),
      onToggle: () => _toggleSection('gasGear', defaultValue: defaultExpanded),
      summary: _gasGearSummary(),
      modeChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.custom(
            label: context.l10n.diveLog_diveMode_title,
            child: DiveModeSelector(
              selectedMode: _diveMode,
              dense: true,
              onChanged: (mode) {
                _markDirty();
                final enteringCcr =
                    mode == DiveMode.ccr && _diveMode != DiveMode.ccr;
                setState(() => _diveMode = mode);
                if (enteringCcr) _seedCcrSetpointsFromSettings();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              DiveModeSelector.descriptionFor(context, _diveMode),
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      rebreatherPanel: _rebreatherPanel(),
      tanks: [
        for (var i = 0; i < _tanks.length; i++)
          TankRow(
            key: ValueKey((_tanks[i].id, _tankRowGeneration)),
            tank: _tanks[i],
            tankNumber: i + 1,
            units: units,
            tripCylinderStates: slotStates,
            takenTripCylinderIds: tripCylinderIdsTakenFor(
              _tanks[i],
              _tanks,
              primaryComputerId: _existingDive?.computerId,
              primarySourceId: primarySourceId,
            ),
            suggested: _suggestedTankIds.contains(_tanks[i].id),
            // A saved dive's tanks can show the mix their computer logged.
            diveId: _existingDive?.id,
            // A diluent's MOD follows the Dil MOD limit on a rebreather
            // dive only (issue #3752).
            diveMode: _diveMode,
            // A linked cylinder offers the twin set it was in that day
            // (issue #4242).
            diveDate: _entryDate,
            onChanged: (updatedTank) {
              final before = _tanks[i];
              setState(() {
                _markDirty();
                _tanksDirty = true;
                _tanks[i] = updatedTank;
                if (updatedTank.tripCylinderId != before.tripCylinderId) {
                  // The diver chose: the link is no longer a suggestion,
                  // and a None is not overruled by the next suggestion.
                  _suggestedTankIds = {
                    for (final id in _suggestedTankIds)
                      if (id != updatedTank.id) id,
                  };
                  if (updatedTank.tripCylinderId == null) {
                    _declinedTankIds = {..._declinedTankIds, updatedTank.id};
                  }
                }
              });
            },
            onRemove: _tanks.length > 1 ? () => _removeTank(i) : null,
            canRemove: _tanks.length > 1,
            // An own cylinder, scanned (issue #2335) or picked from My
            // cylinders (issue #2599), joins this dive's gear; the tank row
            // itself never links to it.
            onOwnCylinderUsed: (item) => _addGear([item]),
            onScanPending: _trackTankScan,
          ),
      ],
      onAddTank: _addTank,
      addTankLabel: context.l10n.diveLog_edit_addTank,
      applyConfigChild: ApplyConfigurationMenu(
        onSelected: _applyCylinderConfig,
      ),
      gasSwitchesChild: _buildGasSwitchesChild(units),
      equipmentChild: _equipmentChild(),
      weightChild: _weightChild(units),
      showTankControls: _diveMode != DiveMode.gauge,
    );
  }

  String _gasGearSummary() {
    final l10n = context.l10n;
    // The dive's gas, never a suit inflation bottle's (issue #4243).
    final mix = breathingTanks(_tanks).firstOrNull?.gasMix.name;
    return [
      l10n.diveLog_edit_summary_tanks(_tanks.length),
      ?mix,
      // Top-level rows as the tree view places them: an assembly's parts
      // sit inside its row and an orphaned row is promoted (#1487).
      if (_selectedEquipment.isNotEmpty)
        l10n.diveLog_edit_summary_items(GearTree.topLevelCount(_gearRows)),
    ].join(' · ');
  }

  /// Entering CCR with no setpoints logged yet starts from the diver's own
  /// CCR ppO2 limits. Seeded into state, not just shown in the panel, so a
  /// dive saved without touching the panel keeps what the panel displayed.
  ///
  /// Waits for the diver's settings first: until they load, the providers
  /// hold the defaults, and seeding those would save setpoints the diver
  /// never set (#2802). A failed load seeds nothing; the panel then shows
  /// the held values as hints only.
  Future<void> _seedCcrSetpointsFromSettings() async {
    try {
      await ref.read(settingsProvider.notifier).settingsLoaded;
    } catch (_) {
      // Already logged by the notifier.
      return;
    }
    if (!mounted || _diveMode != DiveMode.ccr) return;
    if (_setpointLow != null && _setpointHigh != null) return;
    setState(() {
      _setpointLow ??= ref.read(ccrSetpointLowProvider);
      _setpointHigh ??= ref.read(ccrSetpointHighProvider);
      _ccrSeedGeneration++;
    });
  }

  Widget? _rebreatherPanel() {
    if (_diveMode == DiveMode.ccr) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: CcrSettingsPanel(
          key: ValueKey(_ccrSeedGeneration),
          // Switching to CCR seeds these from the diver's own CCR ppO2
          // limits (see the mode selector). A dive already logged as CCR
          // with no setpoints leaves them empty, with those limits as hint
          // text: nothing is shown that saving would not write (#2802).
          // Watched, so the hints follow settings that load after the page.
          setpointLow: _setpointLow,
          setpointHigh: _setpointHigh,
          setpointLowHint: ref.watch(ccrSetpointLowProvider),
          setpointHighHint: ref.watch(ccrSetpointHighProvider),
          setpointDeco: _setpointDeco,
          diluentGas: _diluentGas,
          scrubberType: _scrubberType,
          scrubberDurationMinutes: _scrubberDurationMinutes,
          scrubberRemainingMinutes: _scrubberRemainingMinutes,
          loopVolume: _loopVolume,
          onChanged:
              ({
                double? setpointLow,
                double? setpointHigh,
                double? setpointDeco,
                GasMix? diluentGas,
                String? scrubberType,
                int? scrubberDurationMinutes,
                int? scrubberRemainingMinutes,
                double? loopVolume,
              }) {
                setState(() {
                  _markDirty();
                  _setpointLow = setpointLow;
                  _setpointHigh = setpointHigh;
                  _setpointDeco = setpointDeco;
                  _diluentGas = diluentGas;
                  _scrubberType = scrubberType;
                  _scrubberDurationMinutes = scrubberDurationMinutes;
                  _scrubberRemainingMinutes = scrubberRemainingMinutes;
                  _loopVolume = loopVolume;
                });
              },
        ),
      );
    }
    if (_diveMode == DiveMode.scr) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: ScrSettingsPanel(
          scrType: _scrType,
          injectionRate: _scrInjectionRate,
          additionRatio: _scrAdditionRatio,
          orificeSize: _scrOrificeSize,
          supplyGas: _scrSupplyGas,
          assumedVo2: _assumedVo2,
          loopO2Min: _loopO2Min,
          loopO2Max: _loopO2Max,
          loopO2Avg: _loopO2Avg,
          scrubberType: _scrubberType,
          scrubberDurationMinutes: _scrubberDurationMinutes,
          scrubberRemainingMinutes: _scrubberRemainingMinutes,
          onChanged:
              ({
                ScrType? scrType,
                double? injectionRate,
                double? additionRatio,
                String? orificeSize,
                GasMix? supplyGas,
                double? assumedVo2,
                double? loopO2Min,
                double? loopO2Max,
                double? loopO2Avg,
                String? scrubberType,
                int? scrubberDurationMinutes,
                int? scrubberRemainingMinutes,
              }) {
                setState(() {
                  _markDirty();
                  _scrType = scrType;
                  _scrInjectionRate = injectionRate;
                  _scrAdditionRatio = additionRatio;
                  _scrOrificeSize = orificeSize;
                  _scrSupplyGas = supplyGas;
                  _assumedVo2 = assumedVo2;
                  _loopO2Min = loopO2Min;
                  _loopO2Max = loopO2Max;
                  _loopO2Avg = loopO2Avg;
                  _scrubberType = scrubberType;
                  _scrubberDurationMinutes = scrubberDurationMinutes;
                  _scrubberRemainingMinutes = scrubberRemainingMinutes;
                });
              },
        ),
      );
    }
    return null;
  }

  /// Calculate bottom time from dive profile data and update the field
  void _calculateBottomTimeFromProfile() {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedBottomTime = _existingDive!
        .calculateBottomTimeFromProfile();

    if (calculatedBottomTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_unableToCalculate),
        ),
      );
      return;
    }

    setState(() {
      _durationController.text = _seedInt(calculatedBottomTime.inMinutes);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_bottomTimeCalculated(
            calculatedBottomTime.inMinutes,
          ),
        ),
      ),
    );
  }

  /// Calculate max depth from dive profile data and update the field
  void _calculateMaxDepthFromProfile(UnitFormatter units) {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedDepth = _existingDive!.calculateMaxDepthFromProfile();

    if (calculatedDepth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveLog_edit_snackbar_unableToCalculateMaxDepth,
          ),
        ),
      );
      return;
    }

    final displayDepth = units.convertDepth(calculatedDepth);
    final depthText = _seedDecimal(displayDepth, 1);

    setState(() {
      _maxDepthController.text = depthText;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_maxDepthCalculated(
            '$depthText ${units.depthSymbol}',
          ),
        ),
      ),
    );
  }

  /// Calculate average depth from dive profile data and update the field
  void _calculateAvgDepthFromProfile(UnitFormatter units) {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedDepth = _existingDive!.calculateAvgDepthFromProfile();

    if (calculatedDepth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveLog_edit_snackbar_unableToCalculateAvgDepth,
          ),
        ),
      );
      return;
    }

    final displayDepth = units.convertDepth(calculatedDepth);
    final depthText = _seedDecimal(displayDepth, 1);

    setState(() {
      _avgDepthController.text = depthText;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_avgDepthCalculated(
            '$depthText ${units.depthSymbol}',
          ),
        ),
      ),
    );
  }

  /// Calculate runtime from dive profile data and update the field
  void _calculateRuntimeFromProfile() {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedRuntime = _existingDive!.calculateRuntimeFromProfile();

    if (calculatedRuntime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveLog_edit_snackbar_unableToCalculateRuntime,
          ),
        ),
      );
      return;
    }

    setState(() {
      _runtimeController.text = _seedInt(calculatedRuntime.inMinutes);
    });
    _followRuntime();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_runtimeCalculated(
            calculatedRuntime.inMinutes,
          ),
        ),
      ),
    );
  }

  /// Merges a saved cylinder configuration into the in-memory tank list.
  ///
  /// Deliberately does not touch dive_tanks: these cylinders are unsaved form
  /// state until the diver taps Save, so writing through would bypass dirty
  /// tracking and persist changes even if they then cancelled. All merge
  /// rules live in CylinderConfigApplier via DiveTankConfigAdapter, which
  /// never overwrites a gas mix already on the dive. A different size,
  /// pressure, material or label on a matched cylinder is replaced only once
  /// the diver confirms it (issue #2563), as is a role read off a
  /// transmitter's name, with the mix defaulted from it (issue #3307).
  Future<void> _applyCylinderConfig(CylinderConfig config) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    const adapter = DiveTankConfigAdapter();

    var result = adapter.apply(
      tanks: _tanks,
      items: config.items,
      newId: (_) => _uuid.v4(),
    );

    if (result.overwrites.isNotEmpty) {
      final confirmed = await confirmCylinderOverwrites(
        context,
        configName: config.name,
        overwrites: result.overwrites,
        tanks: _tanks,
        units: UnitFormatter(ref.read(settingsProvider)),
      );
      if (!confirmed || !mounted) return;
      result = adapter.apply(
        tanks: _tanks,
        items: config.items,
        newId: (_) => _uuid.v4(),
        overwrite: true,
      );
    }

    // A repeat apply matches every role and so reports a non-zero kept while
    // doing no work. Rebuilding then would mark the form dirty and raise an
    // unsaved-changes prompt for a merge that altered nothing.
    if (!result.changed) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.cylinderConfigs_applyNothingToDo)),
      );
      return;
    }

    setState(() {
      _markDirty();
      _tanksDirty = true;
      _tankRowGeneration++;
      _tanks
        ..clear()
        ..addAll(result.tanks);
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l10n.cylinderConfigs_applyAdded(result.added),
            l10n.cylinderConfigs_applyKept(result.kept),
            if (result.updated > 0)
              l10n.cylinderConfigs_applyUpdated(result.updated),
          ].join(', '),
        ),
      ),
    );
  }

  void _addTank() {
    final settings = ref.read(settingsProvider);
    setState(() {
      _markDirty();
      _tanksDirty = true;
      _tanks.add(
        DiveTank(
          id: _uuid.v4(),
          volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
          workingPressure: _defaultPreset?.workingPressureBar,
          startPressure: settings.defaultStartPressure,
          endPressure: 50.0,
          gasMix: const GasMix(),
          role: _tanks.isEmpty ? TankRole.backGas : TankRole.stage,
          material: _defaultPreset?.material,
          order: _tanks.length,
          presetName: _defaultPreset?.name,
        ),
      );
    });
    logFailure(
      _suggestTripCylinders(),
      _DiveEditPageState,
      'suggest trip cylinders',
    );
  }

  void _removeTank(int index) {
    setState(() {
      _markDirty();
      _tanksDirty = true;
      _tanks.removeAt(index);
      // Update order for remaining tanks
      for (var i = 0; i < _tanks.length; i++) {
        _tanks[i] = _tanks[i].copyWith(order: i);
      }
      _dropGasSwitchesWithoutTank();
    });
  }

  List<GeoPoint> _currentDivePoints() => [
    if (_selectedSite?.location != null) _selectedSite!.location!,
    if (_existingDive?.entryLocation != null) _existingDive!.entryLocation!,
    if (_existingDive?.exitLocation != null) _existingDive!.exitLocation!,
  ];

  /// New-dive path: fill empty equipment with the best set (geofence/default).
  /// Best-effort: skips silently if equipment sets cannot be resolved (e.g. no
  /// database in a widget test).
  Future<void> _applyEquipmentDefaultsOnEmpty() async {
    if (_selectedEquipment.isNotEmpty) return;
    try {
      final inputs = await ref.read(equipmentSetSelectionInputsProvider.future);
      final best = EquipmentSetSelector.bestSetFor(
        divePoints: _currentDivePoints(),
        sets: inputs.sets,
        geofences: inputs.geofences,
      );
      final items = best?.items ?? const <EquipmentItem>[];
      // Re-check emptiness after the await: the diver may have manually added
      // gear while the provider resolved, and auto-apply must never overwrite.
      // A set with no gear of its own may still carry weights or tanks
      // (issue #4525).
      if (best == null ||
          (items.isEmpty && !best.carriesBeyondGear) ||
          !mounted ||
          _selectedEquipment.isNotEmpty) {
        return;
      }
      await _useSet(best, items, auto: true);
    } catch (_) {
      // Equipment sets unavailable; skip best-effort auto-apply.
    }
  }

  /// Site-change path: apply on empty, else suggest a differing geofence set.
  /// Best-effort: skips silently if equipment sets cannot be resolved.
  Future<void> _reevaluateGeofenceForSite() async {
    // A site change invalidates any prior suggestion. Clear it up front so a
    // location with no match (or a dismissed / already-present set) cannot
    // leave a stale banner actionable under the new location label.
    if (_geofenceSuggestion != null && mounted) {
      setState(() => _geofenceSuggestion = null);
    }
    // Guard against stale async completions: if the diver picks another site
    // while this evaluation is in flight, its result no longer applies.
    final siteAtStart = _selectedSite;
    try {
      final inputs = await ref.read(equipmentSetSelectionInputsProvider.future);
      if (!mounted || _selectedSite != siteAtStart) return;
      final points = _currentDivePoints();
      if (_selectedEquipment.isEmpty) {
        final best = EquipmentSetSelector.bestSetFor(
          divePoints: points,
          sets: inputs.sets,
          geofences: inputs.geofences,
        );
        final items = best?.items ?? const <EquipmentItem>[];
        if (best != null &&
            (items.isNotEmpty || best.carriesBeyondGear) &&
            _selectedEquipment.isEmpty) {
          await _useSet(best, items, auto: true);
        }
        return;
      }
      final geofenceSet = EquipmentSetSelector.matchingGeofenceSet(
        divePoints: points,
        sets: inputs.sets,
        geofences: inputs.geofences,
      );
      if (geofenceSet == null) return;
      if (_dismissedSuggestionSetIds.contains(geofenceSet.id)) return;
      final currentIds = _selectedEquipment.map((e) => e.id).toSet();
      final hasNewItem = (geofenceSet.items ?? const []).any(
        (e) => !currentIds.contains(e.id),
      );
      if (!hasNewItem) return;
      setState(() => _geofenceSuggestion = geofenceSet);
    } catch (_) {
      // Equipment sets unavailable; skip best-effort geofence suggestion.
    }
  }

  Widget _equipmentChild() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormOverline(
          label: context.l10n.diveLog_edit_section_equipment,
          actions: [
            FormOverlineAction(
              label: context.l10n.diveLog_edit_useSet,
              icon: Icons.folder_special,
              onPressed: _showEquipmentSetPicker,
            ),
            FormOverlineAction(
              label: context.l10n.diveLog_edit_add,
              icon: Icons.add,
              onPressed: _showEquipmentPicker,
            ),
            FormOverlineAction(
              label: context.l10n.gearPassport_scan_action,
              icon: Icons.qr_code_scanner,
              onPressed: _scanGear,
            ),
            FormOverlineAction(
              label: context.l10n.equipment_list_sortTooltip,
              icon: Icons.sort,
              onPressed: () => showEquipmentArrangeSheet(context),
            ),
          ],
        ),
        // A Tank item here counts toward its dives and service but feeds no
        // gas data; the tank rows above do that (issue #2599). A gauge dive
        // shows no tank rows, so there is nothing to tell apart.
        if (_diveMode != DiveMode.gauge)
          FormCaption(context.l10n.diveLog_edit_equipmentCaption),
        if (_geofenceSuggestion != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: GeofenceSuggestionBanner(
              setName: _geofenceSuggestion!.name,
              locationLabel: _selectedSite?.name,
              onApply: () {
                final suggestion = _geofenceSuggestion!;
                setState(() => _geofenceSuggestion = null);
                _useSet(suggestion, suggestion.items ?? const [], auto: false);
              },
              onDismiss: () => setState(() {
                _dismissedSuggestionSetIds.add(_geofenceSuggestion!.id);
                _geofenceSuggestion = null;
              }),
            ),
          ),
        if (_selectedEquipment.isEmpty)
          FormEmptyRow(label: context.l10n.diveLog_edit_noEquipmentSelected)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rendered through the diver's arrangement as one list, set
                // gear and hand-added gear together, the sets as removable
                // chips above it, assemblies collapsed (#1486, #1576, #1487,
                // #2031). Removals are by id, never by display index: a
                // render position addresses a different item under an
                // arrangement. _selectedEquipment keeps its own order as the
                // source of truth for saving; sorting it would write a
                // pointless reordering of dive_equipment on every save.
                DiveGearTreeView(
                  links: gearLinksFor(_selectedEquipment, _gearRows),
                  overlapNote: _sharedGearNotes(
                    ref
                            .watch(
                              sharedGearOverlapProvider(
                                _sharedGearQuery(
                                  ref
                                      .watch(validatedCurrentDiverIdProvider)
                                      .value,
                                ),
                              ),
                            )
                            .value ??
                        const {},
                  ),
                  ownerReferenceDiverId:
                      _existingDive?.diverId ??
                      ref.watch(validatedCurrentDiverIdProvider).value,
                  // The diver is choosing gear right now, so today's
                  // service state is exactly what they need to see.
                  showServiceStatus: true,
                  onRemoveSet: _removeSet,
                  onRemoveSubtree: (id) =>
                      _setGear(GearExpander.removeSubtree(_gearRows, id)),
                  onRemovePart: (id) =>
                      _setGear(GearExpander.removePart(_gearRows, id)),
                  // Re-adding the assembly writes only what its template
                  // gained since the dive was logged; the picker cannot
                  // offer it again, since it is already on the dive (#1988).
                  onUpdateAssembly: (link) =>
                      _addGear([link.item], viaSetId: link.viaSetId),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _saveEquipmentAsSet,
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: Text(context.l10n.diveLog_edit_saveAsSet),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _markDirty();
                          _selectedEquipment = [];
                          _gearProvenance = [];
                        });
                      },
                      child: Text(context.l10n.diveLog_edit_clearAllEquipment),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// One provenance row per selected item: an item that arrived without a
  /// row (an older code path) is a loose top-level row.
  List<GearProvenance> get _gearRows {
    final byId = {for (final p in _gearProvenance) p.equipmentId: p};
    return [
      for (final e in _selectedEquipment)
        byId[e.id] ?? GearProvenance(equipmentId: e.id),
    ];
  }

  /// Every way gear reaches this page funnels here so an assembly expands
  /// identically whether it came from the picker, a set, a geofence
  /// suggestion or the on-empty default (issue #1487).
  /// The latest gear add, if one may still be running. Adds run one at a
  /// time (each merges into the list the one before it produced), and Save
  /// waits for them, so gear added a moment before Save (a scanned cylinder,
  /// a set) is not left out of the saved dive.
  Future<void>? _pendingGearAdd;

  /// Tank tag scans and My cylinders picks still resolving. Save waits for
  /// them before the gear adds, since their gear add only starts once their
  /// lookup finishes.
  final Set<Future<void>> _pendingTankScans = {};

  void _trackTankScan(Future<void> scan) {
    _pendingTankScans.add(scan);
    unawaited(scan.whenComplete(() => _pendingTankScans.remove(scan)));
  }

  Future<void> _addGear(
    List<EquipmentItem> items, {
    String? viaSetId,
    bool markDirty = true,
  }) {
    final previous = _pendingGearAdd;
    final run = () async {
      // The previous add's failure is its own caller's to report.
      if (previous != null) await previous.then((_) {}, onError: (_) {});
      await _addGearNow(items, viaSetId: viaSetId, markDirty: markDirty);
    }();
    _pendingGearAdd = run;
    return run;
  }

  Future<void> _addGearNow(
    List<EquipmentItem> items, {
    String? viaSetId,
    required bool markDirty,
  }) async {
    if (items.isEmpty) return;
    // A set can list gear no longer shared with this dive's diver; it stays
    // in the set but is not applied (issue #2046). The same diver scopes the
    // parts an added assembly brings along.
    var toAdd = items;
    String? diverId = _existingDive?.diverId;
    if (diverId == null) {
      // An unreadable diver adds unscoped, as before sharing, rather than
      // failing the add.
      try {
        diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      } catch (_) {
        diverId = null;
      }
      if (!mounted) return;
    }
    if (viaSetId != null) {
      if (diverId != null) {
        final usable = await EquipmentRepository().usableSetMemberIds([
          for (final i in items) i.id,
        ], diverId);
        if (!mounted) return;
        toAdd = usableSetItems(items, usable.toSet());
      }
    }
    if (toAdd.isEmpty) return;
    final merged = [
      ..._selectedEquipment,
      for (final item in toAdd)
        if (!_selectedEquipment.any((e) => e.id == item.id)) item,
    ];
    final expansion = await expandGearOnPage(
      ref,
      additions: [
        for (final i in toAdd) (equipmentId: i.id, viaSetId: viaSetId),
      ],
      existing: _gearRows,
      existingItems: merged,
      diverId: diverId,
    );
    if (!mounted) return;
    setState(() {
      if (markDirty) _markDirty();
      _selectedEquipment = [...merged, ...expansion.newItems];
      _gearProvenance = expansion.provenance;
    });
  }

  /// Takes set [setId] off the dive, asking first whether its gear goes
  /// with it or stays as gear of the dive's own (issue #4500).
  Future<void> _removeSet(String setId) async {
    final choice = await showRemoveSetDialog(context);
    if (choice == null || !mounted) return;
    _setGear(switch (choice) {
      RemoveSetChoice.keepGear => GearExpander.unlinkSet(_gearRows, setId),
      RemoveSetChoice.removeGear => GearExpander.removeSet(_gearRows, setId),
    });
  }

  /// Applies a removal: [rows] is the gear that stays, with provenance.
  void _setGear(List<GearProvenance> rows) {
    final keep = {for (final p in rows) p.equipmentId};
    setState(() {
      _markDirty();
      _gearProvenance = rows;
      _selectedEquipment = [
        for (final e in _selectedEquipment)
          if (keep.contains(e.id)) e,
      ];
    });
  }

  /// Adds the item a scanned tag names to this dive's gear, through the
  /// same path as the picker so components expand (issue #2652).
  Future<void> _scanGear() async {
    final item = await scanOwnedItem(context, ref);
    if (item == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (_selectedEquipment.any((e) => e.id == item.id)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.gearPassport_scan_alreadyOnDive(item.name)),
        ),
      );
      return;
    }
    await _addGear([item]);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.gearPassport_scan_added(item.name))),
    );
  }

  void _showEquipmentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        // A Consumer, so the shared gear note (issue #2853) loads while the
        // sheet is open.
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) => EquipmentPickerSheet(
            scrollController: scrollController,
            selectedEquipmentIds: _selectedEquipment.map((e) => e.id).toSet(),
            hideSpare: true,
            hideAssemblyParts: true,
            // A dive logged after the fact may have used gear since retired
            // or sold (#3210).
            offerLeftKit: true,
            overlapNote: _sharedGearNotes(
              ref
                      .watch(
                        sharedGearOverlapProvider(
                          _sharedGearQuery(
                            ref.watch(validatedCurrentDiverIdProvider).value,
                          ),
                        ),
                      )
                      .value ??
                  const {},
            ),
            // Multi-select, so a full kit goes on in one pass (#2175).
            onEquipmentConfirmed: (items) {
              Navigator.of(context).pop();
              _addGear(items);
            },
          ),
        ),
      ),
    );
  }

  void _showEquipmentSetPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentSetPickerSheet(
          scrollController: scrollController,
          onSetSelected: (set, items) {
            Navigator.of(context).pop();
            _useSet(set, items, auto: false);
          },
        ),
      ),
    );
  }

  void _saveEquipmentAsSet() {
    if (_selectedEquipment.isEmpty) return;
    // A set holds top-level rows only: an assembly re-expands into its
    // parts when the set is applied (issue #1487).
    showSaveGearAsSetDialog(
      context,
      topLevelIds: [
        for (final g in gearLinksFor(_selectedEquipment, _gearRows))
          if (g.isTopLevel) g.item.id,
      ],
    );
  }

  Widget _buildConditionsSection(UnitFormatter units) {
    return ConditionsSection(
      expanded: _isExpanded('conditions', defaultValue: false),
      onToggle: () => _toggleSection('conditions', defaultValue: false),
      summary: _conditionsSummary(units),
      isEmpty: _conditionsIsEmpty(units),
      temperatureSymbol: units.temperatureSymbol,
      waterTempController: _waterTempController,
      airTempController: _airTempController,
      topRows: [_autofillOverline(units)],
      environmentRows: _environmentRows(units),
      weatherRows: _weatherRows(units),
    );
  }

  /// The visibility field's value converted to meters, or null when the field
  /// is empty or does not parse. See [parseVisibilityInput].
  double? _visibilityMetersInput(UnitFormatter units) =>
      parseVisibilityInput(_visibilityController.text, units);

  VisibilityScale get _visibilityScale =>
      ref.read(settingsProvider).visibilityScale;

  /// Remembers the mode [saved] was entered in for the next new dive. A
  /// convenience after a save that already succeeded, so a failure is
  /// logged, never reported as a failed save.
  void _rememberVisibilityMode(StoredVisibility saved) {
    final mode = saved.modeToRemember;
    if (mode == null) return;
    unawaited(
      ref
          .read(visibilityInputModeProvider.notifier)
          .remember(mode)
          .catchError(
            (Object e) =>
                _log.warning('Could not remember the visibility mode: $e'),
          ),
    );
  }

  /// What a save writes for visibility. See [resolveVisibilityEntry].
  StoredVisibility _resolvedVisibility(UnitFormatter units) =>
      resolveVisibilityEntry(
        mode: _visibilityMode,
        preciseMeters: _visibilityMetersInput(units),
        band: _visibilityBand,
        preciseTouched: _preciseTouched,
        rangeTouched: _rangeTouched,
        original: _originalVisibility,
        scale: _visibilityScale,
      );

  /// The Range | Precise visibility input (issue #3226), shared by the dive
  /// form and bulk edit.
  Widget _visibilityInput(
    UnitFormatter units, {
    String? Function(String?)? validator,
  }) {
    final scale = ref.watch(settingsProvider.select((s) => s.visibilityScale));
    final band = effectiveVisibilityBand(
      band: _visibilityBand,
      rangeTouched: _rangeTouched,
      original: _originalVisibility,
      scale: scale,
    );
    return VisibilityInput(
      mode: _visibilityMode,
      onModeChanged: (m) {
        setState(() => _visibilityMode = m);
        _markDirty();
      },
      controller: _visibilityController,
      depthSymbol: units.depthSymbol,
      inputValidator: validator ?? numberValidator(context),
      onPreciseChanged: (_) => setState(() => _preciseTouched = true),
      band: band,
      onBandChanged: (b) {
        setState(() {
          _visibilityBand = b;
          _rangeTouched = true;
        });
        _markDirty();
      },
      caption: visibilityEntryCaption(
        mode: _visibilityMode,
        preciseMeters: _visibilityMetersInput(units),
        band: band,
        preciseTouched: _preciseTouched,
        rangeTouched: _rangeTouched,
        original: _originalVisibility,
        scale: scale,
        l10n: context.l10n,
        units: units,
      ),
    );
  }

  String _conditionsSummary(UnitFormatter units) {
    return [
      if (_waterType != null) _waterType!.localizedName(context.l10n),
      if (_waterTempController.text.isNotEmpty)
        '${_waterTempController.text} ${units.temperatureSymbol}',
      // Through the formatters rather than hand-concatenated, so the summary
      // matches how every other distance in the app renders.
      ...switch (_resolvedVisibility(units)) {
        StoredVisibility(:final meters?) => [units.formatDistance(meters)],
        StoredVisibility(:final range?) => [
          formatVisibilityRange(range, context.l10n, units),
        ],
        StoredVisibility(:final legacy?) => [
          ?formatLegacyVisibilityBand(legacy, context.l10n, units),
        ],
        _ => const <String>[],
      },
      ?trimmedOrNull(_surfaceConditionsController.text),
    ].join(' · ');
  }

  bool _conditionsIsEmpty(UnitFormatter units) =>
      _waterTempController.text.isEmpty &&
      _airTempController.text.isEmpty &&
      _visibilityController.text.isEmpty &&
      _resolvedVisibility(units).isEmpty &&
      _waterType == null &&
      _currentDirection == null &&
      _currentStrength == null &&
      _entryMethod == null &&
      _exitMethod == null &&
      _swellHeightController.text.isEmpty &&
      _altitudeController.text.isEmpty &&
      _humidityController.text.isEmpty &&
      _windSpeedController.text.isEmpty &&
      _cloudCover == null &&
      _precipitation == null &&
      _weatherDescriptionController.text.isEmpty &&
      _surfaceConditionsController.text.trim().isEmpty;

  List<Widget> _environmentRows(UnitFormatter units) {
    final l10n = context.l10n;
    final altitudeWarning = _getAltitudeWarning(units);
    return [
      _visibilityInput(units),
      EnumPickerRow<WaterType>(
        label: l10n.diveLog_edit_label_waterType,
        value: _waterType,
        values: WaterType.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() {
          _waterType = v;
          _waterTypeFromSite = false;
        }),
      ),
      EnumPickerRow<CurrentDirection>(
        label: l10n.diveLog_edit_label_currentDirection,
        value: _currentDirection,
        values: CurrentDirection.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() => _currentDirection = v),
      ),
      EnumPickerRow<CurrentStrength>(
        label: l10n.diveLog_edit_label_currentStrength,
        value: _currentStrength,
        values: CurrentStrength.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() => _currentStrength = v),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_swellHeight,
        controller: _swellHeightController,
        suffixText: units.depthSymbol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numberInputFormatters(),
        inputValidator: numberValidator(context),
      ),
      SuggestedTextRow(
        label: l10n.diveLog_edit_label_surfaceConditions,
        controller: _surfaceConditionsController,
        field: DiveTextSuggestionField.surfaceConditions,
        capitalization: TextCapitalization.sentences,
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.text(
            label: l10n.diveLog_edit_label_altitude,
            controller: _altitudeController,
            suffixText: units.altitudeSymbol,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: numberInputFormatters(),
            inputValidator: numberValidator(context),
            onChanged: (_) => setState(() {}),
          ),
          if (altitudeWarning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                altitudeWarning,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: _getAltitudeWarningColor(units),
                ),
              ),
            ),
        ],
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_entryMethod,
        value: _entryMethod,
        values: EntryMethod.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() {
          _entryMethod = v;
          if (_exitMethodLinked) _exitMethod = v;
        }),
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_exitMethod,
        value: _exitMethod,
        values: EntryMethod.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() {
          _exitMethod = v;
          _exitMethodLinked = false;
        }),
      ),
    ];
  }

  /// The section-leading auto-fill row: its action fills fields both above
  /// (air temperature) and below it, so it cannot live at the weather
  /// subsection overline.
  Widget _autofillOverline(UnitFormatter units) {
    final l10n = context.l10n;
    final canFetchWeather =
        _selectedSite != null && _selectedSite!.hasCoordinates;
    return FormOverline(
      label: l10n.diveLog_edit_subsection_autofill,
      actions: [
        FormOverlineAction(
          label: l10n.diveLog_edit_button_fetchWeather,
          icon: Icons.cloud_download,
          busy: _isFetchingWeather,
          onPressed: canFetchWeather ? () => _fetchWeather(units) : null,
        ),
      ],
    );
  }

  List<Widget> _weatherRows(UnitFormatter units) {
    final l10n = context.l10n;
    return [
      FormOverline(label: l10n.diveLog_edit_subsection_weather),
      FormRow.text(
        label: l10n.diveLog_edit_label_humidity,
        controller: _humidityController,
        suffixText: '%',
        keyboardType: TextInputType.number,
        inputFormatters: numberInputFormatters(),
        inputValidator: numberValidator(context),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_windSpeed,
        controller: _windSpeedController,
        suffixText: units.windSpeedSymbol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numberInputFormatters(),
        inputValidator: numberValidator(context),
      ),
      EnumPickerRow<CurrentDirection>(
        label: l10n.diveLog_edit_label_windDirection,
        value: _windDirection,
        values: CurrentDirection.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() => _windDirection = v),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_surfacePressure,
        controller: _surfacePressureController,
        suffixText: 'mbar',
        placeholder: l10n.diveLog_edit_surfacePressureDefault,
        keyboardType: TextInputType.number,
        inputFormatters: numberInputFormatters(),
        inputValidator: numberValidator(context),
      ),
      EnumPickerRow<CloudCover>(
        label: l10n.diveLog_edit_label_cloudCover,
        value: _cloudCover,
        values: CloudCover.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() => _cloudCover = v),
      ),
      EnumPickerRow<Precipitation>(
        label: l10n.diveLog_edit_label_precipitation,
        value: _precipitation,
        values: Precipitation.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() => _precipitation = v),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_weatherDescription,
        controller: _weatherDescriptionController,
        maxLines: 2,
      ),
    ];
  }

  /// Fill an empty altitude field from the dive's logged GPS or the selected
  /// site (spec: 2026-08-06 conditions design). Never overwrites a value and
  /// never marks the form dirty on its own.
  Future<void> _maybeAutoFillAltitude() async {
    if (_altitudeController.text.isNotEmpty) return;

    final resolver = AltitudeResolver(
      elevationService: ref.read(elevationServiceProvider),
    );
    final resolution = await resolver.resolve(
      entryLocation: _existingDive?.entryLocation,
      exitLocation: _existingDive?.exitLocation,
      site: _selectedSite,
    );
    if (!mounted) return;

    final writeBack = resolution.siteAltitudeWriteBack;
    if (writeBack != null) {
      await ref
          .read(siteListNotifierProvider.notifier)
          .updateSiteAltitude(writeBack.siteId, writeBack.altitudeMeters);
      if (!mounted) return;
      if (_selectedSite?.id == writeBack.siteId) {
        _selectedSite = _selectedSite?.copyWith(
          altitude: writeBack.altitudeMeters,
        );
      }
    }

    final meters = resolution.altitudeMeters;
    if (meters == null || _altitudeController.text.isNotEmpty) return;
    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      _silently(() {
        _altitudeController.text = _seedDecimal(
          units.convertAltitude(meters),
          0,
        );
      });
    });
  }

  /// Fetch weather data from Open-Meteo for the selected site and dive date.
  Future<void> _fetchWeather(UnitFormatter units) async {
    if (_selectedSite == null || !_selectedSite!.hasCoordinates) return;

    // If any weather field is already populated, confirm before overwriting
    final hasExistingWeatherData =
        _windSpeedController.text.isNotEmpty ||
        _humidityController.text.isNotEmpty ||
        _weatherDescriptionController.text.isNotEmpty ||
        _windDirection != null ||
        _cloudCover != null ||
        _precipitation != null;

    if (hasExistingWeatherData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.diveLog_edit_fetchWeatherConfirm),
          content: Text(context.l10n.diveLog_edit_fetchWeatherConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.common_action_ok),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isFetchingWeather = true);

    try {
      final entryDateTime = DateTime(
        _entryDate.year,
        _entryDate.month,
        _entryDate.day,
        _entryTime.hour,
        _entryTime.minute,
      );

      final service = ref.read(weatherServiceProvider);
      final weather = await service.fetchWeather(
        latitude: _selectedSite!.location!.latitude,
        longitude: _selectedSite!.location!.longitude,
        date: _entryDate,
        entryTime: entryDateTime,
      );

      if (!mounted) return;

      if (weather == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_edit_fetchWeatherUnavailable),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      setState(() {
        // Populate weather fields from fetched data
        if (weather.windSpeed != null) {
          _windSpeedController.text = _seedDecimal(
            units.convertWindSpeed(weather.windSpeed!),
            1,
          );
        }
        if (weather.windDirection != null) {
          _windDirection = weather.windDirection;
        }
        if (weather.cloudCover != null) {
          _cloudCover = weather.cloudCover;
        }
        if (weather.precipitation != null) {
          _precipitation = weather.precipitation;
        }
        if (weather.humidity != null) {
          _humidityController.text = _seedDecimal(weather.humidity!, 0);
        }
        if (weather.description != null && weather.description!.isNotEmpty) {
          _weatherDescriptionController.text = weather.description!;
        }
        // Only fill airTemp if the controller is currently empty
        if (weather.airTemp != null && _airTempController.text.isEmpty) {
          _airTempController.text = _seedDecimal(
            units.convertTemperature(weather.airTemp!),
            0,
          );
        }
        // Only fill surfacePressure if the controller is currently empty
        if (weather.surfacePressure != null &&
            _surfacePressureController.text.isEmpty) {
          _surfacePressureController.text = _seedDecimal(
            weather.surfacePressure! * 1000,
            0,
          );
        }
        _weatherSource = WeatherSource.openMeteo;
        _weatherFetchedAt = DateTime.now();
      });

      // Retry the altitude lookup: the on-load attempt may have failed while
      // offline, and the user has just asked for a network fill.
      unawaited(_maybeAutoFillAltitude());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.diveLog_edit_weatherFetched)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch weather: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingWeather = false);
      }
    }
  }

  Widget _weightChild(UnitFormatter units) {
    // Lead the attached weights gear already carries is in the total, as on
    // the dive page's Weight card (issue #4442).
    final leadGear = EquipmentLead.carriers(
      gearLinksFor(_selectedEquipment, _gearRows),
    );
    final totalWeight = editorWeightTotalKg(_weights, leadGear);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormOverline(
          label: context.l10n.diveLog_edit_section_weight,
          trailingText: totalWeight == null
              ? null
              : context.l10n.diveLog_edit_weightTotal(
                  units.formatWeight(totalWeight),
                ),
          actions: [
            FormOverlineAction(
              label: context.l10n.diveLog_edit_weightPreset_use,
              icon: Icons.fitness_center,
              onPressed: _applyWeightPreset,
            ),
            if (_weights.any((w) => w.amountKg > 0))
              FormOverlineAction(
                label: context.l10n.diveLog_edit_weightPreset_save,
                icon: Icons.bookmark_add_outlined,
                onPressed: _saveWeightsAsPreset,
              ),
          ],
        ),
        if (_weights.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final weight in _weights)
                  DiveWeightEntryRow(
                    key: ValueKey(weight.id),
                    weight: weight,
                    units: units,
                    onChanged: _replaceWeight,
                    onRemove: () => setState(() {
                      _markDirty();
                      _weights = [
                        for (final w in _weights)
                          if (w.id != weight.id) w,
                      ];
                    }),
                  ),
              ],
            ),
          ),
        GearLeadNote(items: leadGear, units: units),
        FormAppendRow(
          label: context.l10n.diveLog_edit_addWeightEntry,
          onTap: () {
            setState(() {
              _markDirty();
              _weights = [
                ..._weights,
                DiveWeight(
                  id: _uuid.v4(),
                  diveId: widget.diveId ?? '',
                  weightType: WeightType.integrated,
                  amountKg: 0,
                ),
              ];
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.diveLog_edit_weightFeedback_label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SegmentedButton<WeightingFeedback>(
                emptySelectionAllowed: true,
                segments: [
                  // Labels like "Overweighted" are wider than a third of the
                  // row on a phone; scale them down to stay on one line rather
                  // than wrapping mid-word.
                  ButtonSegment(
                    value: WeightingFeedback.correct,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.diveLog_edit_weightFeedback_correct,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: WeightingFeedback.overweighted,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.diveLog_edit_weightFeedback_over,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: WeightingFeedback.underweighted,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.diveLog_edit_weightFeedback_under,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                selected: {?_weightingFeedback},
                onSelectionChanged: (selection) => setState(() {
                  _weightingFeedback = selection.isEmpty
                      ? null
                      : selection.first;
                  _markDirty();
                }),
              ),
              if (_weightingFeedback == WeightingFeedback.overweighted ||
                  _weightingFeedback == WeightingFeedback.underweighted) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _weightingFeedbackAmountController,
                  decoration: InputDecoration(
                    labelText: context.l10n.diveLog_edit_weightFeedback_amount(
                      units.weightSymbol,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: numberInputFormatters(),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: numberValidator(context),
                  onChanged: (_) => _markDirty(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Apply a saved weight preset (issue #1609): opens the picker and replaces
  /// the current weight rows with editable copies of the preset's entries.
  /// Copies the weights and tanks of the diver's last dive at the selected
  /// center into the form (issue #2075). Asks first when the form already
  /// holds any, because the copy replaces them.
  Future<void> _applyLastDiveAtCenter(LastDiveAtCenter last) async {
    final l10n = context.l10n;
    if (applyLastDiveNeedsConfirm(weights: _weights, tanks: _tanks)) {
      final replace = await confirmApplyLastDive(context);
      if (!replace || !mounted) return;
    }
    final settings = ref.read(settingsProvider);
    setState(() {
      _markDirty();
      _tanksDirty = true;
      _weights = last.weightsForNewDive(
        diveId: widget.diveId ?? '',
        newId: _uuid.v4,
      );
      _tanks
        ..clear()
        ..addAll(
          last.tanksForNewDive(
            newId: _uuid.v4,
            startPressure: settings.defaultStartPressure,
            endPressure: 50.0,
          ),
        );
      // The copies carry new ids, so every gas switch loses its cylinder.
      _dropGasSwitchesWithoutTank();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.diveCenters_rental_applied)));
  }

  Future<void> _applyWeightPreset() async {
    final preset = await showModalBottomSheet<WeightPreset>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) =>
            WeightPresetPickerSheet(scrollController: scrollController),
      ),
    );
    if (preset == null || !mounted) return;
    setState(() {
      _markDirty();
      _weights = preset.toDiveWeights(
        diveId: widget.diveId ?? '',
        newId: _uuid.v4,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveLog_edit_weightPreset_applied)),
    );
  }

  /// Save the current weighting as a named, reusable preset (issue #1609).
  Future<void> _saveWeightsAsPreset() async {
    // Resolve the diver the same way weightPresetsProvider does -- fall back to
    // the default diver when the current-diver pref is unset, so "Save as
    // preset" works wherever "Use preset" does.
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final name = await NamePromptDialog.show(
      context,
      title: context.l10n.diveLog_edit_weightPreset_saveTitle,
      label: context.l10n.diveLog_edit_weightPreset_nameLabel,
      confirmLabel: context.l10n.common_action_save,
    );
    if (name == null || !mounted) return;

    final weights = _weights.where((w) => w.amountKg > 0).toList();
    if (weights.isEmpty) return;
    await ref
        .read(weightPresetRepositoryProvider)
        .createFromWeights(
          diverId: diverId,
          displayName: name,
          weights: weights,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_weightPreset_saved(name)),
        ),
      );
    }
  }

  /// Stores an edited weight row. The row keeps its own fields current, and
  /// the Form's onChanged marks the page dirty; the page rebuilds only when
  /// the amount or placement changed, which the Total and "Save as preset"
  /// above the rows read. A name alone shows nowhere outside its row.
  void _replaceWeight(DiveWeight updated) {
    final previous = _weights.firstWhere((w) => w.id == updated.id);
    final next = [for (final w in _weights) w.id == updated.id ? updated : w];
    if (previous.amountKg == updated.amountKg &&
        previous.weightType == updated.weightType) {
      _weights = next;
    } else {
      setState(() => _weights = next);
    }
  }

  Widget _buildBuddiesSection() {
    return BuddiesSection(
      expanded: _isExpanded('buddies', defaultValue: false),
      onToggle: () => _toggleSection('buddies', defaultValue: false),
      summary: _buddiesSummary(),
      isEmpty: _selectedBuddies.isEmpty && _diverRoleIds.isEmpty,
      buddyPicker: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: BuddyPicker(
          diveId: widget.diveId,
          selectedBuddies: _selectedBuddies,
          keepRoleIds: _loadedRoleIds,
          diverRoleIds: _diverRoleIds,
          diveOwnerId: _existingDive?.diverId,
          onDiverRoleChanged: (roleIds) {
            _markDirty();
            setState(() => _diverRoleIds = roleIds);
          },
          onChanged: (buddies) {
            _markDirty();
            setState(() => _selectedBuddies = buddies);
          },
        ),
      ),
    );
  }

  String _buddiesSummary() {
    if (_selectedBuddies.isEmpty) return '';
    final first = _selectedBuddies.first.buddy.name;
    final extra = _selectedBuddies.length - 1;
    return extra == 0 ? first : '$first +$extra';
  }

  Widget _sightingsChild() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: SightingsEditor(
        sightings: _sightings,
        diveId: widget.diveId ?? '',
        onChanged: (sightings) => setState(() {
          _markDirty();
          _sightings = sightings;
        }),
        // Bulk edit spans dives that may be at different sites, so there
        // is no one site to suggest from.
        siteId: _selectedSite?.id,
        siteName: _selectedSite?.name,
        excludeDiveId: widget.diveId,
      ),
    );
  }

  Future<void> _selectEntryDate() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() {
        _markDirty();
        _entryDate = date;
        // If exit date not set, default it to the same day
        _exitDate ??= date;
      });
    }
  }

  Future<void> _selectEntryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _entryTime,
    );
    if (time != null) {
      _markDirty();
      setState(() => _entryTime = time);
    }
  }

  Future<void> _selectExitDate() async {
    // Normalize dates to midnight to avoid time-based comparison issues
    final normalizedEntryDate = DateTime(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
    );
    final normalizedExitDate = _exitDate != null
        ? DateTime(_exitDate!.year, _exitDate!.month, _exitDate!.day)
        : normalizedEntryDate;

    // Use the earlier of entry and exit as firstDate to handle existing dives
    // that may have data inconsistencies
    final firstDate = normalizedExitDate.isBefore(normalizedEntryDate)
        ? normalizedExitDate
        : normalizedEntryDate;

    // Allow exit up to 1 day after entry (multi-day dives are rare in scuba)
    final lastDate = normalizedEntryDate.add(const Duration(days: 1));

    // Ensure initialDate is within the valid range
    DateTime initialDate = normalizedExitDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final date = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null) {
      _markDirty();
      setState(() => _exitDate = date);
    }
  }

  Future<void> _selectExitTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime:
          _exitTime ??
          TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
    );
    if (time != null) {
      setState(() {
        _markDirty();
        _exitTime = time;
        _seededTimes = _seededTimes?.withExitPicked();
        // Also set exit date if not set
        _exitDate ??= _entryDate;
      });
    }
  }

  Future<void> _saveDive(UnitFormatter units) async {
    final pendingSnap = _pendingDiveTypeSnap;
    if (pendingSnap != null) {
      await pendingSnap;
      if (!mounted) return;
    }
    // Wait for tank scans still resolving (each ends with its gear add),
    // then for gear still being added; work started meanwhile is waited for
    // too. A failed add was reported by its caller and adds nothing.
    while (_pendingTankScans.isNotEmpty) {
      await Future.wait(_pendingTankScans.toList());
      if (!mounted) return;
    }
    for (
      var pending = _pendingGearAdd;
      pending != null;
      pending = identical(pending, _pendingGearAdd) ? null : _pendingGearAdd
    ) {
      await pending.then((_) {}, onError: (_) {});
      if (!mounted) return;
    }
    // Collapsed sections un-mount their fields, hiding them from
    // Form.validate(); expand everything first so no error can hide.
    final anyCollapsed = [
      _isExpanded('gasGear', defaultValue: !widget.isEditing),
      _isExpanded('conditions', defaultValue: false),
      _isExpanded('trip', defaultValue: false),
      _isExpanded('buddies', defaultValue: false),
      _isExpanded('experience', defaultValue: false),
    ].any((expanded) => !expanded);
    if (anyCollapsed) {
      setState(() {
        for (final key in const [
          'gasGear',
          'conditions',
          'trip',
          'buddies',
          'experience',
        ]) {
          _expanded[key] = true;
        }
      });
      // A zero-length delay resolves before the frame that builds the
      // expanded sections, so their fields would miss validate() (#1900).
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    // Read now: the diver can leave while the save runs, and a dive logged
    // by hand gets its rules either way (#3513).
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);

    try {
      // The time inputs hold whole minutes; what the diver left alone saves
      // its stored precision.
      final times = resolveDiveTimes(_timeInputs(), seeded: _seededTimes);
      final entryDateTime = times.entry;

      // Parse form values and convert to metric for storage
      final maxDepth = _savedNumber(
        _maxDepthController,
      ).map(units.depthToMeters);
      final avgDepth = _savedNumber(
        _avgDepthController,
      ).map(units.depthToMeters);
      final waterTemp = _savedNumber(
        _waterTempController,
      ).map(units.temperatureToCelsius);
      final airTemp = _savedNumber(
        _airTempController,
      ).map(units.temperatureToCelsius);

      // Parse conditions values (convert to metric)
      final swellHeight = _savedNumber(
        _swellHeightController,
      ).map(units.depthToMeters);
      final altitude = _savedNumber(
        _altitudeController,
      ).map(units.altitudeToMeters);
      final surfacePressure = _savedNumber(_surfacePressureController).map(
        (mbar) => mbar / 1000, // Convert mbar to bar
      );

      // Create dive entity
      final savedVisibility = _resolvedVisibility(units);
      final dive = Dive(
        id: widget.diveId ?? '',
        diverId: _existingDive?.diverId, // Preserve diver assignment
        // A planned dive never holds a number, and a dive being promoted
        // leaves numbering to convertPlanToActualDive (issue #2002).
        diveNumber:
            _isPlanned ||
                _isDraft ||
                (_existingDive?.isPlanned ?? false) ||
                _diveNumberController.text.isEmpty
            ? null
            : _savedNumber(_diveNumberController, integer: true)?.toInt(),
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        dateTime: entryDateTime, // Keep for backward compatibility
        entryTime: entryDateTime,
        exitTime: times.exit,
        bottomTime: times.bottomTime,
        runtime: times.runtime,
        maxDepth: maxDepth,
        avgDepth: avgDepth,
        waterTemp: waterTemp,
        airTemp: airTemp,
        // One visibility shape (issue #3226): what the diver entered, or the
        // stored shape when they left the input alone.
        visibility: savedVisibility.legacy,
        visibilityMeters: savedVisibility.meters,
        visibilityMinMeters: savedVisibility.range?.minM,
        visibilityMaxMeters: savedVisibility.range?.maxM,
        diveTypeIds: _selectedDiveTypeIds,
        notes: _notesController.text,
        rating: _rating > 0 ? _rating : null,
        site: _selectedSite,
        importSource:
            widget.prefill?.importSource ?? _existingDive?.importSource,
        trip: _selectedTrip,
        diveCenter: _selectedDiveCenter,
        diveOperator: trimmedOrNull(_diveOperatorController.text),
        boatName: trimmedOrNull(_boatNameController.text),
        boatCaptain: trimmedOrNull(_boatCaptainController.text),
        surfaceConditions: trimmedOrNull(_surfaceConditionsController.text),
        courseIds: _selectedCourseIds,
        tanks: _tanks,
        gear: gearLinksFor(_selectedEquipment, _gearRows),
        // Conditions fields
        currentDirection: _currentDirection,
        currentStrength: _currentStrength,
        swellHeight: swellHeight,
        entryMethod: _entryMethod,
        exitMethod: _exitMethod,
        waterType: _waterType,
        altitude: altitude,
        surfacePressure: surfacePressure,
        // Weather fields
        windSpeed: _savedNumber(_windSpeedController).map(units.windSpeedToMs),
        windDirection: _windDirection,
        cloudCover: _cloudCover,
        precipitation: _precipitation,
        humidity: _savedNumber(_humidityController),
        weatherDescription: _weatherDescriptionController.text.isNotEmpty
            ? _weatherDescriptionController.text
            : null,
        weatherSource: _weatherSource,
        weatherFetchedAt: _weatherFetchedAt,
        // Weight entries (multiple)
        weights: _weights,
        // Weighting feedback (magnitude only meaningful for over/under)
        weightingFeedback: _weightingFeedback,
        weightingFeedbackKg:
            (_weightingFeedback == WeightingFeedback.overweighted ||
                    _weightingFeedback == WeightingFeedback.underweighted) &&
                _weightingFeedbackAmountController.text.isNotEmpty
            ? _savedNumber(
                _weightingFeedbackAmountController,
              ).map(units.weightToKg)
            : null,
        // Tags
        tags: _selectedTags,
        // Custom fields (filter out entries with empty keys)
        customFields: _customFields
            .where((f) => f.key.trim().isNotEmpty)
            .toList(),
        // Preserve favorite status when editing
        isFavorite: _existingDive?.isFavorite ?? false,
        excludedFromStats: _excludedFromStats,
        excludedFromGasStats: _excludedFromGasStats,
        // Preserve dive profile data (time series from dive computer)
        profile: _existingDive?.profile ?? const [],
        // Preserve photo associations
        photoIds: _existingDive?.photoIds ?? const [],
        // Preserve legacy buddy/divemaster text fields
        buddy: _existingDive?.buddy,
        diveMaster: _existingDive?.diveMaster,
        // Fields this form has no widget for. Every column updateDive does
        // write, it writes unconditionally, with no merge against the stored
        // row, so anything not carried through here is reset to the entity
        // default on every save (issue #1392). Columns it deliberately omits
        // (computerId, the entry/exit location pair) are not at risk and are
        // not listed. The census test in dive_edit_save_field_census_test.dart
        // fails when a new field is added to the writer without a carry here.
        // The switch state, except that an existing planned dive being
        // promoted keeps the flag here: updateDive must not clear it, since
        // convertPlanToActualDive below is the one path that also numbers.
        isPlanned: _isPlanned || (_existingDive?.isPlanned ?? false),
        // No switch sets it: a draft stays one until a download fills it
        // or the diver marks it complete (issue #637).
        isDraft: _existingDive?.isDraft ?? false,
        outingId: _existingDive?.outingId,
        diveComputerModel: _existingDive?.diveComputerModel,
        diveComputerSerial: _existingDive?.diveComputerSerial,
        diveComputerFirmware: _existingDive?.diveComputerFirmware,
        decoAlgorithm: _existingDive?.decoAlgorithm,
        decoConservatism: _existingDive?.decoConservatism,
        gradientFactorLow: _existingDive?.gradientFactorLow,
        gradientFactorHigh: _existingDive?.gradientFactorHigh,
        computerTissue: _existingDive?.computerTissue,
        weatherCode: _existingDive?.weatherCode,
        importId: _existingDive?.importId,
        surfaceInterval: _existingDive?.surfaceInterval,
        diverRoleIds: _diverRoleIds,
        // CCR/SCR rebreather settings
        diveMode: _diveMode,
        setpointLow: _diveMode == DiveMode.ccr ? _setpointLow : null,
        setpointHigh: _diveMode == DiveMode.ccr ? _setpointHigh : null,
        setpointDeco: _diveMode == DiveMode.ccr ? _setpointDeco : null,
        diluentGas: _diveMode == DiveMode.ccr
            ? _diluentGas
            : (_diveMode == DiveMode.scr ? _scrSupplyGas : null),
        loopVolume: _diveMode == DiveMode.ccr ? _loopVolume : null,
        scrubber:
            (_diveMode == DiveMode.ccr || _diveMode == DiveMode.scr) &&
                _scrubberType != null
            ? ScrubberInfo(
                type: _scrubberType!,
                ratedMinutes: _scrubberDurationMinutes,
                remainingMinutes: _scrubberRemainingMinutes,
              )
            : null,
        scrType: _diveMode == DiveMode.scr ? _scrType : null,
        scrInjectionRate: _diveMode == DiveMode.scr ? _scrInjectionRate : null,
        scrAdditionRatio: _diveMode == DiveMode.scr ? _scrAdditionRatio : null,
        scrOrificeSize: _diveMode == DiveMode.scr ? _scrOrificeSize : null,
        assumedVo2: _diveMode == DiveMode.scr ? _assumedVo2 : null,
        loopO2Min: _diveMode == DiveMode.scr ? _loopO2Min : null,
        loopO2Max: _diveMode == DiveMode.scr ? _loopO2Max : null,
        loopO2Avg: _diveMode == DiveMode.scr ? _loopO2Avg : null,
      );

      // Save using the notifier
      final notifier = ref.read(paginatedDiveListProvider.notifier);
      // Read now: the stretch below runs even if the page goes away meanwhile.
      final tripRepository = ref.read(tripRepositoryProvider);
      final messenger = ScaffoldMessenger.of(context);
      final l10n = context.l10n;
      String? savedDiveId;
      // A plan the diver just turned into a dive counts as logged by hand
      // for the logbook rules (#3513).
      final promotedPlan =
          widget.isEditing &&
          (_existingDive?.isPlanned ?? false) &&
          !_isPlanned;
      if (widget.isEditing) {
        await notifier.updateDive(dive);
        savedDiveId = widget.diveId;
        if ((_existingDive?.isPlanned ?? false) && !_isPlanned) {
          // The switch was turned off: promote through the one path that
          // clears the flag and assigns the next number (issue #2002).
          await ref
              .read(diveRepositoryProvider)
              .convertPlanToActualDive(widget.diveId!);
          ref.invalidate(diveNumberingInfoProvider);
          await notifier.refresh();
        }
      } else {
        final savedDive = await notifier.addDive(dive);
        savedDiveId = savedDive.id;

        // Attach the scanned logbook page photo (OCR flow). Failure must
        // never block the save.
        final photoPath = widget.prefill?.photoPath;
        if (photoPath != null) {
          try {
            await ref
                .read(mediaImportServiceProvider)
                .importLocalFileForDive(
                  sourceFile: File(photoPath),
                  diveId: savedDive.id,
                  takenAt: dive.dateTime,
                );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.ocrImport_editPage_photoAttachFailed,
                  ),
                ),
              );
            }
          }
        }

        // Auto-fetch weather for new dives with coordinates
        if (_selectedSite != null && _selectedSite!.hasCoordinates) {
          // Fire and forget -- don't await, don't block save
          ref
              .read(weatherRepositoryProvider)
              .fetchAndSaveWeather(
                diveId: savedDiveId,
                latitude: _selectedSite!.location!.latitude,
                longitude: _selectedSite!.location!.longitude,
                dateTime: dive.dateTime,
              );
        }
      }

      // A new visibility value sets the mode the next new dive opens in.
      if (_activeVisibilityTouched) _rememberVisibilityMode(savedVisibility);

      // After the dive and its cylinders, so the cylinder ids exist.
      await _saveGasSwitches(savedDiveId);
      // After the notes, which the annotation rows are reconciled against.
      await _reconcileAnnotations(savedDiveId);

      // Save sightings
      if (savedDiveId != null) {
        final speciesRepository = ref.read(speciesRepositoryProvider);

        // Get current sighting IDs
        final currentSightingIds = _sightings.map((s) => s.id).toSet();

        // Delete removed sightings (those in original but not in current)
        for (final originalId in _originalSightingIds) {
          if (!currentSightingIds.contains(originalId)) {
            await speciesRepository.deleteSighting(originalId);
          }
        }

        // Add or update sightings
        for (final sighting in _sightings) {
          final isExisting = _originalSightingIds.contains(sighting.id);
          if (isExisting) {
            // Update existing sighting
            await speciesRepository.updateSighting(sighting);
          } else {
            // Add new sighting
            await speciesRepository.addSighting(
              diveId: savedDiveId,
              speciesId: sighting.speciesId,
              abundance: sighting.abundance,
              count: sighting.count,
              notes: sighting.notes,
            );
          }
        }

        // Invalidate providers so detail pages update
        ref.invalidate(diveSightingsProvider(savedDiveId));
        if (_selectedSite != null) {
          ref.invalidate(siteSpottedSpeciesProvider(_selectedSite!.id));
        }
      }

      // Save buddies
      if (savedDiveId != null) {
        final buddyRepository = ref.read(buddyRepositoryProvider);
        await buddyRepository.setBuddiesForDive(savedDiveId, _selectedBuddies);
        // Invalidate the buddies provider so the detail page shows updated data
        ref.invalidate(buddiesForDiveProvider(savedDiveId));
        // Invalidate providers for all affected buddies (added + removed)
        final newBuddyIds = _selectedBuddies.map((b) => b.buddy.id).toSet();
        final affectedBuddyIds = _originalBuddyIds.union(newBuddyIds);
        for (final buddyId in affectedBuddyIds) {
          ref.invalidate(buddyStatsProvider(buddyId));
          ref.invalidate(diveIdsForBuddyProvider(buddyId));
          ref.invalidate(divesForBuddyProvider(buddyId));
        }
        ref.invalidate(allBuddiesWithDiveCountProvider);
      }

      // Apply the staged underwater route links. A planned dive has no
      // recording, so a draft left from before the switch was turned on is
      // dropped. A failure is reported but never undoes the dive save.
      final routeDraft = _routeDraft;
      if (savedDiveId != null &&
          !_isPlanned &&
          routeDraft != null &&
          routeDraft.hasChanges) {
        try {
          final skipped = await applyDiveRouteLinkDraft(
            ref.read(navTrackRepositoryProvider),
            diveId: savedDiveId,
            draft: routeDraft,
          );
          if (skipped.isNotEmpty) {
            _log.warning(
              'Routes not linked (linked elsewhere or deleted meanwhile): $skipped',
            );
          }
        } catch (e, stackTrace) {
          _log.error(
            'Failed to apply route links for dive $savedDiveId',
            error: e,
            stackTrace: stackTrace,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.navTrack_editRow_tracksSaveFailed(e.toString()),
                ),
              ),
            );
          }
        }
        ref.invalidate(navTracksForDiveProvider(savedDiveId));
      }

      // Refresh every course the dive joined or left (#2515).
      if (savedDiveId != null) {
        for (final courseId in {
          ...?_existingDive?.courseIds,
          ..._selectedCourseIds,
        }) {
          ref.invalidate(courseDivesProvider(courseId));
          ref.invalidate(courseDiveCountProvider(courseId));
        }
        ref.invalidate(coursesForDiveProvider(savedDiveId));
      }

      // Record tide conditions if the site has coordinates. The recorder
      // skips freshwater dives, judged by the dive's own water type first.
      if (savedDiveId != null &&
          _selectedSite != null &&
          _selectedSite!.hasCoordinates) {
        try {
          final resolved = await ref.read(
            resolvedTideDataProvider(_selectedSite!.location!).future,
          );
          if (resolved != null) {
            // entryDateTime is the dive's wall clock (DateTime.utc of the
            // picked digits); the recorder evaluates the real instant.
            await recordDiveTide(
              repository: ref.read(tideRecordRepositoryProvider),
              calculator: resolved.calculator,
              diveId: savedDiveId,
              entryWallClock: entryDateTime,
              location: _selectedSite!.location!,
              waterType: _waterType ?? _selectedSite!.waterType,
            );
          }
        } catch (e) {
          // Silently fail - tide recording is optional enhancement
          debugPrint('Failed to record tide data: $e');
        }
      }

      // Queue a data-quality rescan of the saved dive (fire-and-forget).
      if (savedDiveId != null) {
        scheduleQualityScan([savedDiveId]);
        scheduleSensorSummaryRefresh([savedDiveId]);
        scheduleDerivedMetricsRefresh([savedDiveId]);
      }

      // Logbook rules for a dive logged by hand (#3513): its first save, or
      // a plan just turned into a dive, once its children are saved so the
      // rules see the whole dive. Later edits never run them.
      if (savedDiveId != null &&
          !_isPlanned &&
          (!widget.isEditing || promotedPlan)) {
        await rulesAfterCreate(subject: RuleSubject.dives, ids: [savedDiveId]);
      }

      // A dive put on a trip, or moved to another day on one, stretches the
      // trip to cover it (#3351).
      if (savedDiveId != null &&
          diveSaveTouchesTrip(
            tripId: _selectedTrip?.id,
            previousTripId: _existingDive?.tripId ?? _existingDive?.trip?.id,
            date: entryDateTime,
            previousDate: _existingDive?.effectiveEntryTime,
          )) {
        try {
          final message = tripDateStretchMessage(
            l10n,
            units,
            await tripRepository.stretchToCoverDives([savedDiveId]),
          );
          if (message != null) {
            messenger.showSnackBar(SnackBar(content: Text(message)));
          }
        } catch (e, stackTrace) {
          // Reported, but it never undoes the dive save.
          _log.error(
            'Failed to stretch the trip of dive $savedDiveId',
            error: e,
            stackTrace: stackTrace,
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.trips_dateStretch_failed)),
          );
        }
      }

      // Offer to log the dive for linked buddies (issue #2002). Runs before
      // navigation so the dialog has this page's context; the runner uses
      // the container so its snackbar and refresh outlive this State. A
      // planned dive never prompts: a mirrored sibling is itself planned
      // and must not cascade.
      if (mounted && savedDiveId != null && !_isPlanned) {
        final candidates = await ref
            .read(diveMirrorServiceProvider)
            .candidates(savedDiveId);
        if (candidates.isNotEmpty && mounted) {
          final chosenIds = await showMirrorDiveDialog(
            context,
            candidates: candidates,
          );
          if (chosenIds != null && chosenIds.isNotEmpty && mounted) {
            await runDiveMirror(
              context: context,
              container: ProviderScope.containerOf(context, listen: false),
              sourceDiveId: savedDiveId,
              chosen: [
                for (final c in candidates)
                  if (chosenIds.contains(c.diver.id)) c,
              ],
            );
          }
        }
      }

      if (mounted && savedDiveId != null) {
        _hasUnsavedChanges = false;
        if (widget.embedded && widget.onSaved != null) {
          // In embedded mode, call the callback to update selection
          widget.onSaved!(savedDiveId);
        } else if (widget.diveId != null && context.canPop()) {
          // Editing an existing dive: return to whatever pushed this form
          // (normally that dive's own detail page). `go` would rebuild the
          // stack from `/dives` and discard the section the user came from --
          // Media, Insights, a trip -- stranding them on the dive list.
          context.pop();
        } else {
          // A new dive has no page to return to, so take the form's place
          // rather than replacing the whole stack.
          context.pushReplacement('/dives/$savedDiveId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_edit_snackbar_errorSaving(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Get warning text for altitude dives.
  String? _getAltitudeWarning(UnitFormatter units) {
    final altitudeInUserUnits = switch (readNumber(_altitudeController.text)) {
      NumberValue(:final value) => value,
      // No warning to show; an unreadable field shows its own error.
      NumberBlank() || NumberInvalid() => null,
    };
    if (altitudeInUserUnits == null) return null;

    final altitudeMeters = units.altitudeToMeters(altitudeInUserUnits);
    final group = AltitudeGroup.fromAltitude(altitudeMeters);

    if (group == AltitudeGroup.seaLevel) return null;
    return '${group.localizedName(context.l10n)} - ${group.localizedRange(context.l10n, units)}';
  }

  /// Get warning color for altitude dives based on altitude group.
  Color? _getAltitudeWarningColor(UnitFormatter units) {
    final altitudeInUserUnits = switch (readNumber(_altitudeController.text)) {
      NumberValue(:final value) => value,
      // No warning to show; an unreadable field shows its own error.
      NumberBlank() || NumberInvalid() => null,
    };
    if (altitudeInUserUnits == null) return null;

    final altitudeMeters = units.altitudeToMeters(altitudeInUserUnits);
    final group = AltitudeGroup.fromAltitude(altitudeMeters);

    switch (group.warningLevel) {
      case AltitudeWarningLevel.none:
        return null;
      case AltitudeWarningLevel.info:
        return Colors.blue;
      case AltitudeWarningLevel.caution:
        return Colors.orange;
      case AltitudeWarningLevel.warning:
        return Colors.deepOrange;
      case AltitudeWarningLevel.severe:
        return Colors.red;
    }
  }
}
