import 'dart:async';
import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';

/// Generic StateNotifier that manages in-memory [EntityCardViewConfig] state
/// and debounces persistence to the database.
///
/// The card sibling of [EntityTableConfigNotifier]: each entity type creates
/// one provider per card mode (detailed, compact) with its own storage key,
/// for example `card_detailed_sites`.
class EntityCardConfigNotifier<F extends EntityField>
    extends StateNotifier<EntityCardViewConfig<F>> {
  static final _log = LoggerService.forClass(EntityCardConfigNotifier);

  ViewConfigRepository? _repository;
  String? _diverId;
  String? _storageKey;
  final EntityCardViewConfig<F> _defaultConfig;
  final F Function(String) _fieldFromName;
  Timer? _saveTimer;

  EntityCardConfigNotifier({
    required EntityCardViewConfig<F> defaultConfig,
    required F Function(String) fieldFromName,
  }) : _defaultConfig = defaultConfig,
       _fieldFromName = fieldFromName,
       super(defaultConfig);

  /// Load the saved config for [diverId] under [storageKey].
  ///
  /// A saved layout that names a field this build does not know (a layout
  /// written by a newer build) is ignored rather than thrown, so the list
  /// still renders with the default slots.
  Future<void> init(
    ViewConfigRepository repository,
    String diverId,
    String storageKey,
  ) async {
    _repository = repository;
    _diverId = diverId;
    _storageKey = storageKey;
    final json = await repository.getRawConfig(diverId, storageKey);
    if (json == null || !mounted) return;
    try {
      state = EntityCardViewConfig.fromJson<F>(
        jsonDecode(json) as Map<String, dynamic>,
        _fieldFromName,
      );
    } catch (e, stackTrace) {
      _log.warning(
        'Ignoring unreadable card config for $storageKey',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  /// Assign [field] to the slot with [slotId].
  ///
  /// An unknown [slotId], or one that already holds [field], returns without
  /// touching the state. StateNotifier notifies on identity rather than
  /// equality, so rebuilding the slot list regardless would repaint every
  /// card in the list and schedule a database write for a no-op.
  void setSlotField(String slotId, F field) {
    final index = state.slots.indexWhere((s) => s.slotId == slotId);
    if (index < 0 || state.slots[index].field == field) return;
    final slots = List<EntityCardSlotConfig<F>>.from(state.slots);
    slots[index] = slots[index].copyWith(field: field);
    state = state.copyWith(slots: slots);
    _save();
  }

  void setExtraFields(List<F> fields) {
    state = state.copyWith(extraFields: List<F>.unmodifiable(fields));
    _save();
  }

  void addExtraField(F field) {
    if (state.extraFields.contains(field)) return;
    setExtraFields([...state.extraFields, field]);
  }

  void removeExtraField(F field) {
    setExtraFields(state.extraFields.where((f) => f != field).toList());
  }

  /// Move the extra field at [oldIndex] to [newIndex].
  void reorderExtraFields(int oldIndex, int newIndex) {
    final fields = List<F>.from(state.extraFields);
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex.clamp(0, fields.length), item);
    setExtraFields(fields);
  }

  /// Replace the whole config; the settings page edits a copy and hands it
  /// back through this.
  void replace(EntityCardViewConfig<F> config) {
    state = config;
    _save();
  }

  void resetToDefault() {
    state = _defaultConfig;
    _save();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final repo = _repository;
      final diverId = _diverId;
      final key = _storageKey;
      if (repo != null && diverId != null && key != null) {
        repo.saveRawConfig(diverId, key, jsonEncode(state.toJson()));
      }
    });
  }
}
