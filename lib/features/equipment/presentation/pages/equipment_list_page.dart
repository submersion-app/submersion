import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/equipment_item.dart';
import '../providers/equipment_providers.dart';

class EquipmentListPage extends ConsumerWidget {
  const EquipmentListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equipment'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Retired'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_outlined),
              tooltip: 'Equipment Sets',
              onPressed: () => context.push('/equipment/sets'),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: EquipmentSearchDelegate(ref),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ActiveEquipmentTab(),
            _RetiredEquipmentTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _showAddEquipmentDialog(context, ref);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Equipment'),
        ),
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

class _ActiveEquipmentTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipmentAsync = ref.watch(equipmentListNotifierProvider);

    return equipmentAsync.when(
      data: (equipment) => equipment.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildEquipmentList(context, ref, equipment),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading equipment: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(equipmentListNotifierProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentList(BuildContext context, WidgetRef ref, List<EquipmentItem> equipment) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(equipmentListNotifierProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: equipment.length,
        itemBuilder: (context, index) {
          final item = equipment[index];
          return EquipmentListTile(
            name: item.name,
            type: item.type,
            brandModel: item.fullName != item.name ? item.fullName : null,
            isServiceDue: item.isServiceDue,
            daysUntilService: item.daysUntilService,
            onTap: () => context.push('/equipment/${item.id}'),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No equipment added yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your diving equipment to track usage and service',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => AddEquipmentSheet(ref: ref),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Equipment'),
          ),
        ],
      ),
    );
  }
}

class _RetiredEquipmentTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retiredAsync = ref.watch(retiredEquipmentProvider);

    return retiredAsync.when(
      data: (equipment) => equipment.isEmpty
          ? _buildEmptyState(context)
          : _buildEquipmentList(context, ref, equipment),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentList(BuildContext context, WidgetRef ref, List<EquipmentItem> equipment) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: equipment.length,
      itemBuilder: (context, index) {
        final item = equipment[index];
        return EquipmentListTile(
          name: item.name,
          type: item.type,
          brandModel: item.fullName != item.name ? item.fullName : null,
          isServiceDue: false,
          onTap: () => context.push('/equipment/${item.id}'),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No retired equipment',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Retired equipment will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
                  value: _selectedType,
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
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      final equipment = EquipmentItem(
        id: '',
        name: _nameController.text.trim(),
        type: _selectedType,
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        size: _sizeController.text.trim().isEmpty ? null : _sizeController.text.trim(),
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

      await widget.ref.read(equipmentListNotifierProvider.notifier).addEquipment(equipment);

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

/// List item widget for displaying equipment
class EquipmentListTile extends StatelessWidget {
  final String name;
  final EquipmentType type;
  final String? brandModel;
  final bool isServiceDue;
  final int? daysUntilService;
  final VoidCallback? onTap;

  const EquipmentListTile({
    super.key,
    required this.name,
    required this.type,
    this.brandModel,
    this.isServiceDue = false,
    this.daysUntilService,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isServiceDue
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.tertiaryContainer,
          child: Icon(
            _getIconForType(type),
            color: isServiceDue
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        title: Text(name),
        subtitle: brandModel != null ? Text(brandModel!) : Text(type.displayName),
        trailing: isServiceDue
            ? Chip(
                label: const Text('Service Due'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              )
            : daysUntilService != null
                ? Text(
                    '$daysUntilService days',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
      ),
    );
  }

  IconData _getIconForType(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.accessibility_new;
      case EquipmentType.wetsuit:
      case EquipmentType.drysuit:
        return Icons.checkroom;
      case EquipmentType.fins:
        return Icons.directions_walk;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.tank:
        return Icons.propane_tank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      default:
        return Icons.inventory_2;
    }
  }
}

/// Search delegate for equipment
class EquipmentSearchDelegate extends SearchDelegate<EquipmentItem?> {
  final WidgetRef ref;

  EquipmentSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search equipment...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search by name, brand, model, or serial number',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final searchAsync = ref.watch(equipmentSearchProvider(query));

    return searchAsync.when(
      data: (equipment) {
        if (equipment.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No equipment found for "$query"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: equipment.length,
          itemBuilder: (context, index) {
            final item = equipment[index];
            return EquipmentListTile(
              name: item.name,
              type: item.type,
              brandModel: item.fullName != item.name ? item.fullName : null,
              isServiceDue: item.isServiceDue,
              daysUntilService: item.daysUntilService,
              onTap: () {
                close(context, item);
                context.push('/equipment/${item.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
