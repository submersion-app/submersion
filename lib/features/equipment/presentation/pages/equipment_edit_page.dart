import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../domain/entities/equipment_item.dart';
import '../providers/equipment_providers.dart';

class EquipmentEditPage extends ConsumerStatefulWidget {
  final String? equipmentId;

  const EquipmentEditPage({super.key, this.equipmentId});

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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final equipmentAsync =
          ref.watch(equipmentItemProvider(widget.equipmentId!));
      return equipmentAsync.when(
        data: (equipment) {
          if (equipment == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Equipment Not Found')),
              body: const Center(
                child: Text('This equipment item no longer exists.'),
              ),
            );
          }
          _initializeFromEquipment(equipment);
          return _buildForm(context, equipment);
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Loading...')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(child: Text('Error: $error')),
        ),
      );
    }

    return _buildForm(context, null);
  }

  Widget _buildForm(BuildContext context, EquipmentItem? existingEquipment) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Equipment' : 'New Equipment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type
            DropdownButtonFormField<EquipmentType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type *',
                prefixIcon: Icon(Icons.category),
              ),
              items: EquipmentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Status
            DropdownButtonFormField<EquipmentStatus>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.flag),
              ),
              items: EquipmentStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.label),
                hintText: 'e.g., My Primary Regulator',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
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
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      prefixIcon: Icon(Icons.info_outline),
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
                    decoration: const InputDecoration(
                      labelText: 'Serial Number',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _sizeController,
                    decoration: const InputDecoration(
                      labelText: 'Size',
                      prefixIcon: Icon(Icons.straighten),
                      hintText: 'e.g., M, L, 42',
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
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes),
                hintText: 'Additional notes about this equipment...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed:
                  _isLoading ? null : () => _saveEquipment(existingEquipment),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Add Equipment'),
            ),
          ],
        ),
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
              'Purchase Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Purchase Date',
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
                    : 'Select Date',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_purchaseDate != null)
              TextButton(
                onPressed: () => setState(() => _purchaseDate = null),
                child: const Text('Clear Date'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _purchasePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _purchaseCurrencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
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
                  'Service Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serviceIntervalController,
              decoration: const InputDecoration(
                labelText: 'Service Interval (days)',
                prefixIcon: Icon(Icons.schedule),
                hintText: 'e.g., 365 for yearly',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              'Last Service Date',
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
                    : 'Select Date',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_lastServiceDate != null)
              TextButton(
                onPressed: () => setState(() => _lastServiceDate = null),
                child: const Text('Clear Date'),
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
      setState(() => _purchaseDate = date);
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
      setState(() => _lastServiceDate = date);
    }
  }

  Future<void> _saveEquipment(EquipmentItem? existingEquipment) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get the current diver ID - preserve existing for edits, get fresh for new items
      final diverId = existingEquipment?.diverId ??
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
      );

      final notifier = ref.read(equipmentListNotifierProvider.notifier);

      if (widget.isEditing) {
        await notifier.updateEquipment(equipment);
        ref.invalidate(equipmentItemProvider(widget.equipmentId!));
      } else {
        await notifier.addEquipment(equipment);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing ? 'Equipment updated' : 'Equipment added',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving equipment: $e'),
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
