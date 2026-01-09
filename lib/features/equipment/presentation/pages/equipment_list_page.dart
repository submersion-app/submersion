import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../shared/widgets/master_detail/master_detail_scaffold.dart';
import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../domain/entities/equipment_item.dart';
import '../providers/equipment_providers.dart';
import '../widgets/equipment_list_content.dart';
import '../widgets/equipment_summary_widget.dart';
import 'equipment_detail_page.dart';
import 'equipment_edit_page.dart';

class EquipmentListPage extends ConsumerWidget {
  const EquipmentListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isDesktopExtended(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          _showAddEquipmentDialog(context, ref);
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Add Equipment'),
    );

    if (ResponsiveBreakpoints.isDesktopExtended(context)) {
      return MasterDetailScaffold(
        sectionId: 'equipment',
        masterBuilder: (context, onItemSelected, selectedId) =>
            EquipmentListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, id) => EquipmentDetailPage(
          equipmentId: id,
          embedded: true,
          onDeleted: () {
            context.go('/equipment');
          },
        ),
        summaryBuilder: (context) => const EquipmentSummaryWidget(),
        editBuilder: (context, id, onSaved, onCancel) => EquipmentEditPage(
          equipmentId: id,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) => EquipmentEditPage(
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        floatingActionButton: fab,
      );
    }

    return EquipmentListContent(
      showAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEquipmentDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Equipment'),
      ),
    );
  }

  void _showAddEquipmentDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEquipmentSheet(ref: ref),
    );
  }
}

class AddEquipmentSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const AddEquipmentSheet({super.key, required this.ref});

  @override
  ConsumerState<AddEquipmentSheet> createState() => _AddEquipmentSheetState();
}

class _AddEquipmentSheetState extends ConsumerState<AddEquipmentSheet> {
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
  DateTime? _purchaseDate;
  bool _isSaving = false;

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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Equipment',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
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
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    prefixIcon: Icon(Icons.business),
                    hintText: 'e.g., Scubapro',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    prefixIcon: Icon(Icons.info_outline),
                    hintText: 'e.g., MK25 EVO',
                  ),
                ),
                const SizedBox(height: 16),
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
                // Purchase Information
                Text(
                  'Purchase Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: OutlinedButton.icon(
                        onPressed: _selectPurchaseDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _purchaseDate != null
                              ? '${_purchaseDate!.month}/${_purchaseDate!.day}/${_purchaseDate!.year}'
                              : 'Date',
                          style: TextStyle(
                            color: _purchaseDate != null
                                ? null
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _purchaseCurrencyController,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Service Interval
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
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes),
                    hintText: 'Additional notes...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _saveEquipment,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Equipment'),
                ),
              ],
            ),
          ),
        );
      },
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

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get the current diver ID for new equipment
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);

      final equipment = EquipmentItem(
        id: '',
        diverId: diverId,
        name: _nameController.text.trim(),
        type: _selectedType,
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
        serviceIntervalDays: _serviceIntervalController.text.isNotEmpty
            ? int.tryParse(_serviceIntervalController.text)
            : null,
        notes: _notesController.text.trim(),
        isActive: true,
      );

      await widget.ref
          .read(equipmentListNotifierProvider.notifier)
          .addEquipment(equipment);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding equipment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
