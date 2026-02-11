import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

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
  final _sizeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _purchaseCurrencyController = TextEditingController(text: 'USD');
  final _serviceIntervalController = TextEditingController();
  final _notesController = TextEditingController();

  EquipmentType _selectedType = EquipmentType.regulator;
  EquipmentStatus _selectedStatus = EquipmentStatus.active;
  DateTime? _purchaseDate;
  DateTime? _lastServiceDate;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  bool? _customReminderEnabled;
  List<int> _customReminderDays = [7, 14, 30];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _brandController.addListener(_onFieldChanged);
    _modelController.addListener(_onFieldChanged);
    _serialController.addListener(_onFieldChanged);
    _sizeController.addListener(_onFieldChanged);
    _purchasePriceController.addListener(_onFieldChanged);
    _purchaseCurrencyController.addListener(_onFieldChanged);
    _serviceIntervalController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
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
    _sizeController.dispose();
    _purchasePriceController.dispose();
    _purchaseCurrencyController.dispose();
    _serviceIntervalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeFromEquipment(EquipmentItem equipment) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = equipment.name;
    _brandController.text = equipment.brand ?? '';
    _modelController.text = equipment.model ?? '';
    _serialController.text = equipment.serialNumber ?? '';
    _sizeController.text = equipment.size ?? '';
    _purchasePriceController.text = equipment.purchasePrice?.toString() ?? '';
    _purchaseCurrencyController.text = equipment.purchaseCurrency;
    _serviceIntervalController.text =
        equipment.serviceIntervalDays?.toString() ?? '';
    _notesController.text = equipment.notes;
    _selectedType = equipment.type;
    _selectedStatus = equipment.status;
    _purchaseDate = equipment.purchaseDate;
    _lastServiceDate = equipment.lastServiceDate;
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

          // Serial Number & Size
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _serialController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_edit_serialNumberLabel,
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _sizeController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_edit_sizeLabel,
                    prefixIcon: const Icon(Icons.straighten),
                    hintText: context.l10n.equipment_edit_sizeHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Purchase Date
          _buildDateSection(context),
          const SizedBox(height: 24),

          // Service Settings
          _buildServiceSection(context),
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
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _purchasePriceController,
                    decoration: InputDecoration(
                      labelText: context.l10n.equipment_edit_purchasePriceLabel,
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _purchaseCurrencyController,
                    decoration: InputDecoration(
                      labelText: context.l10n.equipment_edit_currencyLabel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_edit_serviceSettingsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serviceIntervalController,
              decoration: InputDecoration(
                labelText: context.l10n.equipment_edit_serviceIntervalLabel,
                prefixIcon: const Icon(Icons.schedule),
                hintText: context.l10n.equipment_edit_serviceIntervalHint,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_edit_lastServiceDateLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _selectLastServiceDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _lastServiceDate != null
                    ? '${_lastServiceDate!.month}/${_lastServiceDate!.day}/${_lastServiceDate!.year}'
                    : context.l10n.equipment_edit_selectDate,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_lastServiceDate != null)
              TextButton(
                onPressed: () => setState(() {
                  _lastServiceDate = null;
                  _hasChanges = true;
                }),
                child: Text(context.l10n.equipment_edit_clearDate),
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
    final date = await showDatePicker(
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

  Future<void> _selectLastServiceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _lastServiceDate = date;
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
        size: _sizeController.text.trim().isEmpty
            ? null
            : _sizeController.text.trim(),
        purchaseDate: _purchaseDate,
        purchasePrice: _purchasePriceController.text.isNotEmpty
            ? double.tryParse(_purchasePriceController.text)
            : null,
        purchaseCurrency: _purchaseCurrencyController.text.trim().isEmpty
            ? 'USD'
            : _purchaseCurrencyController.text.trim(),
        lastServiceDate: _lastServiceDate,
        serviceIntervalDays: _serviceIntervalController.text.isNotEmpty
            ? int.tryParse(_serviceIntervalController.text)
            : null,
        notes: _notesController.text.trim(),
        isActive: existingEquipment?.isActive ?? true,
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
