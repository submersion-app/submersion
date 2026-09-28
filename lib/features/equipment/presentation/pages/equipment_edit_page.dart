import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tags_field.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_advanced_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_edit_embedded_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_notification_overrides_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_parent_picker.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_purchase_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_type_status_fields.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_form_attributes.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

class EquipmentEditPage extends ConsumerStatefulWidget {
  final String? equipmentId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  /// For a new item: the parent it starts fitted to (a host's "Add part").
  /// Kept while the chosen type can live in that parent.
  final String? initialParentId;

  const EquipmentEditPage({
    super.key,
    this.equipmentId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.initialParentId,
  });

  bool get isEditing => equipmentId != null;

  @override
  ConsumerState<EquipmentEditPage> createState() => _EquipmentEditPageState();
}

class _EquipmentEditPageState extends ConsumerState<EquipmentEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  // Filled from the diver's default (new items) or the stored value (existing
  // items); left blank until then so a stale 'USD' never flashes on load.
  final _purchaseCurrencyController = TextEditingController();
  final _notesController = TextEditingController();

  EquipmentType _selectedType = EquipmentType.regulator;
  EquipmentStatus _selectedStatus = EquipmentStatus.active;
  DateTime? _purchaseDate;
  String? _parentEquipmentId;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  bool? _customReminderEnabled;
  List<int> _customReminderDays = [7, 14, 30];

  /// The item's tags on this form (issue #1942) and the stored set a save
  /// compares against. Tags live beside the entity, not on it, so they load
  /// on their own.
  List<Tag> _selectedTags = [];
  Set<String> _originalTagIds = {};

  /// Set once an edit's stored tags are read. Until then (and for good, if
  /// the read fails) the Tags field is disabled and a save leaves the stored
  /// tags alone: a pick made against the still-empty field would otherwise
  /// replace them all.
  bool _tagsLoaded = false;

  static final _log = LoggerService.forClass(EquipmentEditPage);

  /// The code this form opened with. Currency is free text, so it can be
  /// outside the presets; keeping it lets the dropdown still offer it.
  String _initialCurrencyCode = '';

  @override
  void initState() {
    super.initState();
    // New items start in the diver's default currency; existing items get
    // their stored currency from _loadEquipment.
    if (widget.equipmentId == null) {
      _initialCurrencyCode = ref.read(defaultCurrencyProvider);
      _purchaseCurrencyController.text = _initialCurrencyCode;
      _parentEquipmentId = widget.initialParentId;
    }
    _nameController.addListener(_onFieldChanged);
    _brandController.addListener(_onFieldChanged);
    _modelController.addListener(_onFieldChanged);
    _serialController.addListener(_onFieldChanged);
    _purchasePriceController.addListener(_onFieldChanged);
    _purchaseCurrencyController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  /// The code to store when the currency field is left blank: the diver's
  /// default, or USD if that is somehow unset (the column is NOT NULL).
  String _fallbackCurrencyCode() {
    final code = ref.read(defaultCurrencyProvider).trim().toUpperCase();
    return code.isEmpty ? 'USD' : code;
  }

  void _onFieldChanged() {
    if (!_hasChanges && _isInitialized) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _purchasePriceController.dispose();
    _purchaseCurrencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Curated attribute values keyed by attrKey, plus user custom fields.
  final Map<String, EquipmentAttribute> _attrValues = {};
  List<EquipmentAttribute> _customFields = [];

  void _initializeFromEquipment(EquipmentItem equipment) {
    if (_isInitialized) return;
    _isInitialized = true;

    for (final attr in equipment.attributes) {
      if (attr.isCustom) {
        _customFields.add(attr);
      } else {
        _attrValues[attr.key] = attr;
      }
    }
    _customFields.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    _nameController.text = equipment.name;
    _brandController.text = equipment.brand ?? '';
    _modelController.text = equipment.model ?? '';
    _serialController.text = equipment.serialNumber ?? '';
    // Seeded in the diver's locale convention, matching how the field is read
    // back on save. double.toString() would seed "12.5" even where ',' is the
    // decimal separator and '.' groups thousands, so an untouched re-save
    // would store 125 (#1091).
    final price = equipment.purchasePrice;
    _purchasePriceController.text = price == null
        ? ''
        : formatDecimalForInput(price);
    _initialCurrencyCode = equipment.purchaseCurrency;
    _purchaseCurrencyController.text = _initialCurrencyCode;
    _notesController.text = equipment.notes;
    _selectedType = equipment.type;
    // A legacy row can carry isActive=false with a non-terminal status.
    // Show it as Retired so the form states the item's real condition --
    // otherwise saving would silently reactivate it (#636). "Sold" is the
    // other status that means gone, so keep it rather than overwrite it.
    _selectedStatus =
        !equipment.isActive && equipment.status != EquipmentStatus.sold
        ? EquipmentStatus.retired
        : equipment.status;
    _purchaseDate = equipment.purchaseDate;
    _parentEquipmentId = equipment.parentEquipmentId;
    _customReminderEnabled = equipment.customReminderEnabled;
    _customReminderDays = equipment.customReminderDays ?? const [7, 14, 30];
    _loadTags(equipment.id);
  }

  /// Loads the item's tags into the Tags field (issue #1942) and the
  /// baseline a save compares against, then enables the field.
  Future<void> _loadTags(String equipmentId) async {
    // Called from build: yield before the first provider read, which
    // riverpod rejects while the tree is building (as media_item_view does).
    await null;
    if (!mounted) return;
    try {
      final tags = await ref.read(tagsForEquipmentProvider(equipmentId).future);
      if (!mounted) return;
      setState(() {
        _originalTagIds = {for (final t in tags) t.id};
        _selectedTags = tags;
        _tagsLoaded = true;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Could not load the tags of equipment $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleCancel() {
    if (widget.embedded) {
      widget.onCancel?.call();
    } else {
      context.pop();
    }
  }

  /// [_parentEquipmentId] only when it names an active item whose type can
  /// hold [type]; a stale choice from a previous type is never written.
  String? _validParentIdFor(EquipmentType type) {
    final id = _parentEquipmentId;
    if (id == null) return null;
    // While the active list is still loading (or failed) the id is kept as
    // is: a quick open-and-save must not drop a link the page never got to
    // check.
    final items = ref.read(activeEquipmentProvider).valueOrNull;
    if (items == null) return id;
    final allowed = equipmentParentTypesFor(type);
    return items.any((e) => e.id == id && allowed.contains(e.type)) ? id : null;
  }

  /// The parent to write on save: [_validParentIdFor] once the active list
  /// has loaded. Before that, the id may have come from a deep link
  /// (`/equipment/new?parent=`), so it is looked up directly and kept only
  /// when it names a fitted item visible to [diverId] (owned or shared) whose
  /// type can hold [type].
  Future<String?> _parentIdToSave(EquipmentType type, String? diverId) async {
    final id = _parentEquipmentId;
    if (id == null) return null;
    if (ref.read(activeEquipmentProvider).valueOrNull != null) {
      return _validParentIdFor(type);
    }
    final parent = await ref
        .read(equipmentRepositoryProvider)
        .getEquipmentById(id);
    if (parent == null || !parent.isFitted) return null;
    // A parent shared with [diverId] is as usable as one it owns (#2046).
    if (diverId != null &&
        !await ref.read(equipmentRepositoryProvider).isVisibleTo(id, diverId)) {
      return null;
    }
    return equipmentParentTypesFor(type).contains(parent.type) ? id : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final equipmentAsync = ref.watch(
        equipmentItemProvider(widget.equipmentId!),
      );
      return equipmentAsync.when(
        data: (equipment) {
          if (equipment == null) {
            if (widget.embedded) {
              return Center(
                child: Text(context.l10n.equipment_edit_notFoundMessage),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.equipment_edit_notFoundTitle),
              ),
              body: Center(
                child: Text(context.l10n.equipment_edit_notFoundMessage),
              ),
            );
          }
          _initializeFromEquipment(equipment);
          return _buildForm(context, equipment);
        },
        loading: () {
          if (widget.embedded) {
            return const Center(child: CircularProgressIndicator());
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.equipment_edit_loadingTitle),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, _) {
          if (widget.embedded) {
            return Center(
              child: Text(context.l10n.equipment_edit_errorMessage('$error')),
            );
          }
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.equipment_edit_errorTitle)),
            body: Center(
              child: Text(context.l10n.equipment_edit_errorMessage('$error')),
            ),
          );
        },
      );
    }

    // For new equipment, mark as initialized immediately
    if (!_isInitialized) {
      _isInitialized = true;
    }

    return _buildForm(context, null);
  }

  Widget _buildForm(BuildContext context, EquipmentItem? existingEquipment) {
    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EquipmentTypeStatusFields(
            type: _selectedType,
            status: _selectedStatus,
            onTypeChanged: (value) => setState(() {
              _selectedType = value;
              // A parent chosen for the old type may not hold the new one (a
              // computer holds a battery, never an O2 cell), and the picker
              // would show "none" while the stale id was still written on
              // save. Keep it only if it can: a host's "Add part" starts on a
              // type that holds nothing, and its parent must survive the
              // switch to a cell or battery.
              _parentEquipmentId = _validParentIdFor(value);
              _hasChanges = true;
            }),
            onStatusChanged: (value) => setState(() {
              _selectedStatus = value;
              _hasChanges = true;
            }),
          ),
          const SizedBox(height: 16),

          // Parent item, for the child types only (v202).
          if (equipmentParentTypesFor(_selectedType).isNotEmpty) ...[
            EquipmentParentPicker(
              equipmentId: widget.equipmentId,
              allowedTypes: equipmentParentTypesFor(_selectedType),
              selectedParentId: _parentEquipmentId,
              onChanged: (value) => setState(() {
                _parentEquipmentId = value;
                _hasChanges = true;
              }),
            ),
            const SizedBox(height: 16),
          ],

          // Name
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_edit_nameLabel,
              prefixIcon: const Icon(Icons.label),
              hintText: context.l10n.equipment_edit_nameHint,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.equipment_edit_nameValidation;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Brand & Model
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_edit_brandLabel,
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_edit_modelLabel,
                    prefixIcon: const Icon(Icons.info_outline),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Type-specific attributes (catalog-driven; rebuilds on type change)
          EquipmentAttributeFormSection(
            key: ValueKey('attrs-${_selectedType.name}'),
            type: _selectedType,
            values: _attrValues,
            units: UnitFormatter(ref.watch(settingsProvider)),
            onChanged: _setAttribute,
            onCleared: _clearAttribute,
          ),
          // The item's colour, which tints its artwork on the diver figure
          // (issue #2326). Renders nothing for the types that have none.
          EquipmentAttributeFormSection(
            key: ValueKey('appearance-${_selectedType.name}'),
            type: _selectedType,
            group: AttributeGroup.appearance,
            values: _attrValues,
            units: UnitFormatter(ref.watch(settingsProvider)),
            onChanged: _setAttribute,
            onCleared: _clearAttribute,
          ),
          // Serial #
          TextFormField(
            controller: _serialController,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_edit_serialNumberLabel,
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 24),
          // Purchase Date
          EquipmentPurchaseCard(
            purchaseDate: _purchaseDate,
            onPickDate: _selectPurchaseDate,
            onClearDate: () => setState(() {
              _purchaseDate = null;
              _hasChanges = true;
            }),
            priceController: _purchasePriceController,
            currencyController: _purchaseCurrencyController,
            initialCurrencyCode: _initialCurrencyCode,
            type: _selectedType,
            attrValues: _attrValues,
            units: UnitFormatter(ref.watch(settingsProvider)),
            onAttrChanged: _setAttribute,
            onAttrCleared: _clearAttribute,
          ),
          const SizedBox(height: 24),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_edit_notesLabel,
              prefixIcon: const Icon(Icons.notes),
              hintText: context.l10n.equipment_edit_notesHint,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Tags (issue #1942), directly after Notes.
          EquipmentTagsField(
            selectedTags: _selectedTags,
            enabled: !widget.isEditing || _tagsLoaded,
            onTagsChanged: (tags) => setState(() {
              _selectedTags = tags;
              _hasChanges = true;
            }),
          ),
          const SizedBox(height: 24),
          // Advanced (buoyancy metadata for weight prediction)
          EquipmentAdvancedCard(
            fields: _customFields,
            onChanged: (fields) => setState(() {
              _customFields = fields;
              _hasChanges = true;
            }),
          ),
          const SizedBox(height: 24),

          // Notification Overrides
          EquipmentNotificationOverridesCard(
            customReminderEnabled: _customReminderEnabled,
            customReminderDays: _customReminderDays,
            onEnabledChanged: (enabled) => setState(() {
              _customReminderEnabled = enabled;
              _hasChanges = true;
            }),
            onDaysChanged: (days) => setState(() {
              _customReminderDays = days;
              _hasChanges = true;
            }),
          ),

          if (!widget.embedded) ...[
            const SizedBox(height: 32),
            // Save Button
            Tooltip(
              message: widget.isEditing
                  ? context.l10n.equipment_edit_saveTooltip_edit
                  : context.l10n.equipment_edit_saveTooltip_new,
              child: FilledButton(
                onPressed: _isLoading
                    ? null
                    : () => _saveEquipment(existingEquipment),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing
                            ? context.l10n.equipment_edit_saveButton_edit
                            : context.l10n.equipment_edit_saveButton_new,
                      ),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && _hasChanges) {
            final shouldPop = await showEquipmentDiscardDialog(context);
            if (shouldPop == true && mounted) {
              _handleCancel();
            }
          }
        },
        child: Column(
          children: [
            EquipmentEditEmbeddedHeader(
              isEditing: widget.isEditing,
              isLoading: _isLoading,
              onCancel: () async {
                if (_hasChanges) {
                  final discard = await showEquipmentDiscardDialog(context);
                  if (discard == true && mounted) {
                    _handleCancel();
                  }
                } else {
                  _handleCancel();
                }
              },
              onSave: () => _saveEquipment(existingEquipment),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await showEquipmentDiscardDialog(context);
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? context.l10n.equipment_edit_appBar_editTitle
                : context.l10n.equipment_edit_appBar_newTitle,
          ),
          actions: [
            Tooltip(
              message: context.l10n.equipment_edit_appBar_saveTooltip,
              child: AppBarTextAction(
                label: context.l10n.equipment_edit_appBar_saveButton,
                onPressed: _isLoading
                    ? null
                    : () => _saveEquipment(existingEquipment),
                busy: _isLoading,
              ),
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  void _setAttribute(EquipmentAttribute attr) => setState(() {
    _attrValues[attr.key] = attr;
    _hasChanges = true;
  });

  void _clearAttribute(String key) => setState(() {
    _attrValues.remove(key);
    _hasChanges = true;
  });

  Future<void> _selectPurchaseDate() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _purchaseDate = date;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveEquipment(EquipmentItem? existingEquipment) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get the current diver ID - preserve existing for edits, get fresh for new items
      final diverId =
          existingEquipment?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      // Catalog attributes of the selected type plus the de-duped custom
      // fields (see equipmentAttributesToSave).
      final attributes = equipmentAttributesToSave(
        type: _selectedType,
        values: _attrValues,
        customFields: _customFields,
      );

      final equipment = EquipmentItem(
        id: widget.equipmentId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        purchaseDate: _purchaseDate,
        parentEquipmentId: equipmentParentTypesFor(_selectedType).isEmpty
            ? null
            : await _parentIdToSave(_selectedType, diverId),
        // Blank means "no price"; anything unreadable was already stopped by
        // the field validator, so null here can only mean blank.
        purchasePrice: switch (readNumber(_purchasePriceController.text)) {
          NumberValue(:final value) => value,
          NumberBlank() || NumberInvalid() => null,
        },
        purchaseCurrency: _purchaseCurrencyController.text.trim().isEmpty
            ? _fallbackCurrencyCode()
            : _purchaseCurrencyController.text.trim(),
        // Legacy service fields are frozen: service is managed via clocks on
        // the detail page. Preserve any existing values for export/import.
        lastServiceDate: existingEquipment?.lastServiceDate,
        serviceIntervalDays: existingEquipment?.serviceIntervalDays,
        notes: _notesController.text.trim(),
        // Retiring or selling via the status dropdown must deactivate the
        // item, or it keeps appearing in active-gear pickers (#636).
        isActive:
            _selectedStatus != EquipmentStatus.retired &&
            _selectedStatus != EquipmentStatus.sold,
        attributes: attributes,
        customReminderEnabled: _customReminderEnabled,
        customReminderDays: _customReminderEnabled == true
            ? _customReminderDays
            : null,
      );

      final notifier = ref.read(equipmentListNotifierProvider.notifier);
      String savedId;

      // Tags (issue #1942) are written with the row, in one transaction,
      // only when they differ from what the form loaded; a new item writes
      // them when it has any.
      final tagIds = [for (final t in _selectedTags) t.id];
      final tagsChanged = widget.isEditing
          ? _tagsLoaded && !setEquals(tagIds.toSet(), _originalTagIds)
          : tagIds.isNotEmpty;

      if (widget.isEditing) {
        await notifier.updateEquipment(
          equipment,
          tagIds: tagsChanged ? tagIds : null,
        );
        ref.invalidate(equipmentItemProvider(widget.equipmentId!));
        savedId = widget.equipmentId!;
      } else {
        final newEquipment = await notifier.addEquipment(
          equipment,
          tagIds: tagsChanged ? tagIds : null,
        );
        savedId = newEquipment.id;
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEditing
                    ? context.l10n.equipment_edit_snackbar_updated
                    : context.l10n.equipment_edit_snackbar_added,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.equipment_edit_snackbar_error('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
