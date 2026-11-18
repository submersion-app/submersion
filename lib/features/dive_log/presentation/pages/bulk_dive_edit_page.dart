import 'dart:async';

import 'package:flutter/material.dart' hide Visibility;
import 'package:go_router/go_router.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/equipment/presentation/utils/usable_set_items.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_list_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_equipment_sets.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_input.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/features/trips/data/repositories/selection_trip_facts.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/helpers/new_trip_from_selection.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_date_stretch_message.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/name_prompt_dialog.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/weight_preset_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_gear_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_gear_rows.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/dive_log/presentation/providers/bulk_dive_edit_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_tank_specs_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_weight_entry_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gear_lead_note.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

part 'bulk_dive_edit_page_collections.dart';
part 'bulk_dive_edit_page_form.dart';
part 'bulk_dive_edit_page_rows.dart';
part 'bulk_dive_edit_page_save.dart';

const _createNewDiveCenterSentinel = '__create_new_dive_center__';
const _createNewTripSentinel = '__create_new_trip__';

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

/// Edits several dives at once: each row applies its value to every
/// selected dive, gated by its own switch (bulk edit). Mirrors
/// `SiteMergePage` for the merge flow.
class BulkDiveEditPage extends ConsumerStatefulWidget {
  /// The dives being edited.
  final List<String> diveIds;

  /// Leave by popping back to the list that opened the form, rather than
  /// going to /dives. Set when that list was itself pushed over another
  /// page, whose back arrow a go() would erase (#3292).
  final bool popOnSave;

  /// When true, renders without Scaffold wrapper.
  final bool embedded;

  /// Callback when save completes (used in embedded mode).
  final void Function(String savedId)? onSaved;

  /// Callback when user cancels editing (used in embedded mode).
  final VoidCallback? onCancel;

  const BulkDiveEditPage({
    super.key,
    required this.diveIds,
    this.popOnSave = false,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

  @override
  ConsumerState<BulkDiveEditPage> createState() => _BulkDiveEditPageState();
}

class _BulkDiveEditPageState extends ConsumerState<BulkDiveEditPage> {
  static final _log = LoggerService.forClass(BulkDiveEditPage);

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _notesController = TextEditingController();

  late VisibilityInputMode _visibilityMode = ref.read(
    visibilityInputModeProvider,
  );
  VisibilityBand? _visibilityBand;

  /// Whether the diver has edited each visibility mode (typed a number,
  /// tapped a chip). Tracked per mode so a detour through the other mode
  /// never discards or rounds the stored value.
  bool _preciseTouched = false;
  bool _rangeTouched = false;

  int _rating = 0;
  // Statistics exclusion (#526 / #1272). Kept independent: unticking the
  // master flag must restore the diver's own gas-only choice rather than
  // having silently overwritten it.
  bool _bulkExcludedFromStats = false;
  bool _bulkExcludedFromGasStats = false;
  DiveSite? _selectedSite;
  Trip? _selectedTrip;
  DiveCenter? _selectedDiveCenter;
  List<Sighting> _sightings = [];

  /// The active diver's own roles on the dive (#547, several since #1221).
  List<String> _diverRoleIds = const [];

  // Conditions fields
  CurrentDirection? _currentDirection;
  CurrentStrength? _currentStrength;
  EntryMethod? _entryMethod;
  // Exit does not follow entry here: each is its own bulk row.
  EntryMethod? _exitMethod;
  WaterType? _waterType;

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
  final _windSpeedController = TextEditingController();
  final _humidityController = TextEditingController();
  final _weatherDescriptionController = TextEditingController();
  final _diveOperatorController = TextEditingController();
  final _boatNameController = TextEditingController();
  final _boatCaptainController = TextEditingController();
  final _surfaceConditionsController = TextEditingController();
  // Weight fields - multiple weight entries per dive
  List<DiveWeight> _weights = [];

  // No weighting feedback here: one value rarely fits several dives, and the
  // single-dive editor is where a diver records it (#4674).

  // Tank data - list of tanks with multi-tank support
  List<DiveTank> _tanks = [];

  final _uuid = const Uuid();
  TankPresetEntity? _defaultPreset;
  bool _tanksDirty = false;

  // Dive mode and rebreather settings
  DiveMode _diveMode = DiveMode.oc;
  // CCR settings
  double? _setpointLow;
  double? _setpointHigh;
  double? _setpointDeco;
  String? _scrubberType;
  int? _scrubberDurationMinutes;

  /// Text controllers for the bulk rebreather number fields, created on first
  /// build by [_bulkNumberField].
  final Map<BulkField, TextEditingController> _bulkNumberControllers = {};

  /// Unsaved-changes guard state. The page never had one before the form
  /// redesign; EditFormScaffold's PopScope consumes this.
  bool _hasUnsavedChanges = false;

  /// Suppressed while loading/populating so programmatic writes do not
  /// trip the discard guard.
  bool _suppressDirty = true;

  /// The one setState seam for the part files' extensions.
  void _update(VoidCallback fn) => setState(fn);

  void _markDirty() {
    if (_suppressDirty || _hasUnsavedChanges) return;
    _hasUnsavedChanges = true;
    // Deferred: this is called from listeners, Form.onChanged and inside
    // other setState callbacks; PopScope reads the flag on next build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();

    // Eagerly resolve built-in presets (sync), async for custom
    logFailure(
      _loadDefaultPreset(),
      _BulkDiveEditPageState,
      'load default preset',
    );

    // Bulk edit starts from an empty form: no draft, no GPS or number, and
    // no starting tank (bulk tanks are Add/Replace, not a default list).
    // Dive types start empty too (like tags); a ['recreational'] default
    // would make enabling the collection silently operate on it.
    _tanks = [];
    _suppressDirty = false;
    logFailure(_loadBulkMembers(), _BulkDiveEditPageState, 'load bulk members');

    for (final controller in [
      _notesController,
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
          // Apply preset to a lone tank the user hasn't edited yet.
          if (!_tanksDirty && preset != null && _tanks.length == 1) {
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

  @override
  void dispose() {
    for (final controller in _bulkNumberControllers.values) {
      controller.dispose();
    }
    _notesController.dispose();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _buildBulkScaffold(ref.watch(unitFormatterProvider));

  // === Bulk edit mode ===
  // Filled in across Phases 2-5. Shell + stubs here so bulk mode compiles.

  Widget _buildBulkScaffold(UnitFormatter units) {
    return EditFormScaffold(
      title: context.l10n.diveLog_bulkEdit_appBarTitle(widget.diveIds.length),
      embedded: widget.embedded,
      isSaving: _isSaving,
      hasUnsavedChanges: _hasUnsavedChanges,
      onSave: () => _saveBulk(units),
      onCancel: widget.onCancel,
      headerIcon: Icons.edit_note,
      child: _buildBulkForm(units),
    );
  }

  // Bulk-mode state.
  final Set<BulkField> _bulkEnabled = {};
  bool _bulkFavorite = false;
  bool _bulkNotesAppend = false; // false = Set (overwrite), true = Append
  final Map<BulkCollectionType, BulkCollectionMode> _collectionModes = {};
  bool _bulkTankOnlyIfEmpty = false;

  // Tanks "Update" mode (#797): a template cylinder plus the mask of which of
  // its attributes to write onto the tanks each dive already has.
  DiveTank _bulkTankSpecs = const DiveTank(id: 'bulk-tank-specs');
  Set<TankSpecField> _bulkTankSpecFields = {};

  /// A role per tank position for Update's Role field, or null for the
  /// template's single role on every tank (issue #4412).
  List<TankRole>? _bulkTankSlotRoles;

  // Bulk tri-state membership state for each reference collection: the members
  // shown across the selected dives (existing + picker-added), their per-item
  // dive counts, and the resulting add/remove delta.
  Map<String, int> _equipmentCounts = {};

  /// The gear listed in the bulk equipment editor, in no particular order:
  /// it renders through the diver's gear arrangement (#2274), so it is kept
  /// as whole items: the arrangement orders them by type and then by the
  /// diver's chosen item field (name, or one of the gear's dates).
  List<EquipmentItem> _bulkGear = [];
  MembershipDelta _equipmentDelta = MembershipDelta.empty;

  /// The last "Use Set" instruction to the equipment editor: every item of the
  /// set goes on all the selected dives (#1754). The serial makes each
  /// application a fresh request, even for the same set.
  ({int serial, Set<String> ids})? _equipmentEnsureOn;

  /// Which set "Use Set" switched each equipment row on with, so those adds
  /// carry the set (#4284).
  Map<String, String> _equipmentSetOf = const {};

  /// Sets staged to come off every selected dive with what they brought.
  List<BulkStagedSet> _equipmentSetRemovals = const [];

  /// Sets used in this bulk edit that bring no gear, only weights or tanks
  /// (issue #4525): with no gear row to carry them, they are staged here.
  List<BulkStagedSet> _equipmentSetAdds = const [];

  Map<String, int> _tagCounts = {};
  List<BulkMembershipItem> _tagMembers = [];
  MembershipDelta _tagDelta = MembershipDelta.empty;

  Map<String, int> _diveTypeCounts = {};
  final Map<String, String> _diveTypeNames = {};
  List<BulkMembershipItem> _diveTypeMembers = [];
  MembershipDelta _diveTypeDelta = MembershipDelta.empty;

  // The dives' training courses (#2515).
  Map<String, int> _courseCounts = {};
  List<BulkMembershipItem> _courseMembers = [];
  MembershipDelta _courseDelta = MembershipDelta.empty;

  Map<String, int> _buddyCounts = {};
  final Map<String, Buddy> _buddyById = {};

  /// Roles the user picked in the buddy picker during this edit. Membership
  /// alone never lands here, so an entry means "apply these roles" (#893,
  /// several since #1221).
  final Map<String, List<DiveRole>> _buddyRoleById = {};

  /// Role set each buddy already carries on every selected dive that has
  /// them, so filling in the missing links reuses it instead of the default
  /// Buddy. Buddies with a mix of sets across the selection are absent.
  final Map<String, List<String>> _existingBuddyRoleIds = {};

  /// The diver's own role set every selected dive shares, or null when the
  /// dives disagree ([_diverRolesMixed]). A shared set seeds [_diverRoleIds],
  /// so it is the My role row's value; only Mixed or Not set is shown as a
  /// placeholder.
  List<String>? _existingDiverRoleIds;
  bool _diverRolesMixed = false;
  List<BulkMembershipItem> _buddyMembers = [];
  MembershipDelta _buddyDelta = MembershipDelta.empty;

  /// True from a tap on the Site row until its picker has closed. Working
  /// out the dive's area takes a moment before the sheet shows, and a
  /// second tap in that moment would open a second sheet over the first.
  bool _openingSitePicker = false;
}
