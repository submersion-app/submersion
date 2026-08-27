import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_custom_fields_section.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

class EquipmentEditPage extends ConsumerStatefulWidget {
  final String? equipmentId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  const EquipmentEditPage({
    super.key,
    this.equipmentId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
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
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  bool? _customReminderEnabled;
  List<int> _customReminderDays = [7, 14, 30];

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
    // A legacy row can carry isActive=false with a non-retired status.
    // Show it as Retired so the form states the item's real condition --
    // otherwise saving would silently reactivate it (#636).
    _selectedStatus = !equipment.isActive
        ? EquipmentStatus.retired
        : equipment.status;
    _purchaseDate = equipment.purchaseDate;
    _customReminderEnabled = equipment.customReminderEnabled;
    _customReminderDays = equipment.customReminderDays ?? const [7, 14, 30];
  }

  void _handleCancel() {
    if (widget.embedded) {
      widget.onCancel?.call();
    } else {
      context.pop();
    }
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
          // Type
          DropdownButtonFormField<EquipmentType>(
            initialValue: _selectedType,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_edit_typeLabel,
              prefixIcon: const Icon(Icons.category),
            ),
            items: EquipmentType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                  _hasChanges = true;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Status
          DropdownButtonFormField<EquipmentStatus>(
            initialValue: _selectedStatus,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_edit_statusLabel,
              prefixIcon: const Icon(Icons.flag),
            ),
            items: EquipmentStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                  _hasChanges = true;
                });
              }
            },
          ),
          const SizedBox(height: 16),

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
            onChanged: (attr) => setState(() {
              _attrValues[attr.key] = attr;
              _hasChanges = true;
            }),
            onCleared: (key) => setState(() {
              _attrValues.remove(key);
              _hasChanges = true;
            }),
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
          _buildDateSection(context),
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

          // Advanced (buoyancy metadata for weight prediction)
          _buildAdvancedSection(context),
          const SizedBox(height: 24),

          // Notification Overrides
          _buildNotificationSection(context),

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
            final shouldPop = await _showDiscardDialog();
            if (shouldPop == true && mounted) {
              _handleCancel();
            }
          }
        },
        child: Column(
          children: [
            _buildEmbeddedHeader(context, existingEquipment),
            Expanded(child: body),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _showDiscardDialog();
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
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Tooltip(
                message: context.l10n.equipment_edit_appBar_saveTooltip,
                child: TextButton(
                  onPressed: () => _saveEquipment(existingEquipment),
                  child: Text(context.l10n.equipment_edit_appBar_saveButton),
                ),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    EquipmentItem? existingEquipment,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              widget.isEditing ? Icons.edit : Icons.add,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEditing
                  ? context.l10n.equipment_edit_embeddedHeader_editTitle
                  : context.l10n.equipment_edit_embeddedHeader_newTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_hasChanges) {
                final discard = await _showDiscardDialog();
                if (discard == true && mounted) {
                  _handleCancel();
                }
              } else {
                _handleCancel();
              }
            },
            child: Text(
              context.l10n.equipment_edit_embeddedHeader_cancelButton,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: widget.isEditing
                ? context.l10n.equipment_edit_embeddedHeader_saveTooltip_edit
                : context.l10n.equipment_edit_embeddedHeader_saveTooltip_new,
            child: FilledButton(
              onPressed: _isLoading
                  ? null
                  : () => _saveEquipment(existingEquipment),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.l10n.equipment_edit_embeddedHeader_saveButton),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.equipment_edit_discardDialog_title),
        content: Text(context.l10n.equipment_edit_discardDialog_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.equipment_edit_discardDialog_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.equipment_edit_discardDialog_discard),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.equipment_edit_purchaseInfoTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_edit_purchaseDateLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _selectPurchaseDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _purchaseDate != null
                    ? '${_purchaseDate!.month}/${_purchaseDate!.day}/${_purchaseDate!.year}'
                    : context.l10n.equipment_edit_selectDate,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_purchaseDate != null)
              TextButton(
                onPressed: () => setState(() {
                  _purchaseDate = null;
                  _hasChanges = true;
                }),
                child: Text(context.l10n.equipment_edit_clearDate),
              ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  // Rebuild the price field when the currency changes so its
                  // prefix shows the right symbol (€, $, £ ...).
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _purchaseCurrencyController,
                    builder: (context, value, _) {
                      final symbol = currencySymbol(value.text);
                      return TextFormField(
                        key: const ValueKey('equipment-purchase-price'),
                        controller: _purchasePriceController,
                        decoration: InputDecoration(
                          labelText:
                              context.l10n.equipment_edit_purchasePriceLabel,
                          prefixText: symbol.isEmpty ? null : '$symbol ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        // A price that cannot be read has to be reported. The
                        // repository writes Value(null) rather than
                        // Value.absent(), so accepting the save would erase
                        // the stored price instead of leaving it alone.
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          return parseUserDecimal(text) == null
                              ? context
                                    .l10n
                                    .equipment_edit_purchasePriceValidation
                              : null;
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Editable dropdown: common currencies as presets, but any
                  // ISO code can still be typed.
                  child: DropdownMenu<String>(
                    controller: _purchaseCurrencyController,
                    expandedInsets: EdgeInsets.zero,
                    requestFocusOnTap: true,
                    enableFilter: true,
                    label: Text(context.l10n.equipment_edit_currencyLabel),
                    dropdownMenuEntries: [
                      // The stored code leads the list when it is outside the
                      // presets, so an item priced in, say, ISK stays visible
                      // and re-selectable.
                      for (final code in currencyCodesWith(
                        _initialCurrencyCode,
                      ))
                        DropdownMenuEntry(
                          value: code,
                          label: code,
                          leadingIcon: SizedBox(
                            width: 28,
                            child: Center(child: Text(currencySymbol(code))),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_edit_advanced_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            EquipmentCustomFieldsSection(
              fields: _customFields,
              onChanged: (fields) => setState(() {
                _customFields = fields;
                _hasChanges = true;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_edit_notificationsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_edit_notificationsSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(context.l10n.equipment_edit_useCustomReminders),
              subtitle: Text(
                context.l10n.equipment_edit_useCustomRemindersSubtitle,
              ),
              value: _customReminderEnabled == true,
              onChanged: (value) {
                setState(() {
                  _customReminderEnabled = value ? true : null;
                  _hasChanges = true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_customReminderEnabled == true) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.equipment_edit_remindMeBeforeServiceDue,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [7, 14, 30].map((days) {
                  final isSelected = _customReminderDays.contains(days);
                  return FilterChip(
                    label: Text(context.l10n.equipment_edit_reminderDays(days)),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          if (_customReminderDays.length > 1) {
                            _customReminderDays = _customReminderDays
                                .where((d) => d != days)
                                .toList();
                          }
                        } else {
                          _customReminderDays = [..._customReminderDays, days];
                        }
                        _hasChanges = true;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 24),
            SwitchListTile(
              title: Text(context.l10n.equipment_edit_disableReminders),
              subtitle: Text(
                context.l10n.equipment_edit_disableRemindersSubtitle,
              ),
              value: _customReminderEnabled == false,
              onChanged: (value) {
                setState(() {
                  _customReminderEnabled = value ? false : null;
                  _hasChanges = true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

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

      // De-dupe custom fields by trimmed key before building the attribute
      // list. The schema enforces UNIQUE(equipment_id, attr_key, is_custom),
      // so two custom fields sharing a label would fail the insert. First
      // occurrence wins; sort order is re-packed to the surviving order.
      final customAttributes = <EquipmentAttribute>[];
      final seenCustomKeys = <String>{};
      for (final field in _customFields) {
        final key = field.key.trim();
        if (key.isEmpty || !field.hasValue) continue;
        if (!seenCustomKeys.add(key)) continue;
        customAttributes.add(
          field.copyWith(key: key, sortOrder: customAttributes.length),
        );
      }

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
        // Blank means "no price"; anything unreadable was already stopped by
        // the field validator, so null here can only mean blank.
        purchasePrice: parseUserDecimal(_purchasePriceController.text),
        purchaseCurrency: _purchaseCurrencyController.text.trim().isEmpty
            ? _fallbackCurrencyCode()
            : _purchaseCurrencyController.text.trim(),
        // Legacy service fields are frozen: service is managed via clocks on
        // the detail page. Preserve any existing values for export/import.
        lastServiceDate: existingEquipment?.lastServiceDate,
        serviceIntervalDays: existingEquipment?.serviceIntervalDays,
        notes: _notesController.text.trim(),
        // Retiring via the status dropdown must deactivate the item, or it
        // keeps appearing in active-gear pickers (#636).
        isActive: _selectedStatus != EquipmentStatus.retired,
        // Only attributes in the SELECTED type's catalog are kept: switching
        // type drops out-of-catalog values at save time (form = source of
        // truth), plus non-empty custom fields with re-packed sort order.
        attributes: [
          for (final def in EquipmentAttributeCatalog.attributesFor(
            _selectedType,
          ))
            if (_attrValues[def.key] case final attr? when attr.hasValue) attr,
          ...customAttributes,
        ],
        customReminderEnabled: _customReminderEnabled,
        customReminderDays: _customReminderEnabled == true
            ? _customReminderDays
            : null,
      );

      final notifier = ref.read(equipmentListNotifierProvider.notifier);
      String savedId;

      if (widget.isEditing) {
        await notifier.updateEquipment(equipment);
        ref.invalidate(equipmentItemProvider(widget.equipmentId!));
        savedId = widget.equipmentId!;
      } else {
        final newEquipment = await notifier.addEquipment(equipment);
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
