import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/equipment_item.dart';
import '../../domain/entities/service_record.dart';
import '../providers/equipment_providers.dart';

class EquipmentDetailPage extends ConsumerWidget {
  final String equipmentId;

  const EquipmentDetailPage({
    super.key,
    required this.equipmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipmentAsync = ref.watch(equipmentItemProvider(equipmentId));

    return equipmentAsync.when(
      data: (equipment) {
        if (equipment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Equipment Not Found')),
            body: const Center(child: Text('This equipment item no longer exists.')),
          );
        }
        return _buildContent(context, ref, equipment);
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

  Widget _buildContent(BuildContext context, WidgetRef ref, EquipmentItem equipment) {
    return Scaffold(
      appBar: AppBar(
        title: Text(equipment.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/equipment/$equipmentId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value, equipment),
            itemBuilder: (context) => [
              if (equipment.isActive)
                const PopupMenuItem(
                  value: 'service',
                  child: ListTile(
                    leading: Icon(Icons.build),
                    title: Text('Mark as Serviced'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: equipment.isActive ? 'retire' : 'reactivate',
                child: ListTile(
                  leading: Icon(equipment.isActive ? Icons.archive : Icons.unarchive),
                  title: Text(equipment.isActive ? 'Retire Equipment' : 'Reactivate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(context, equipment),
            const SizedBox(height: 24),
            _buildDetailsSection(context, equipment),
            if (equipment.serviceIntervalDays != null) ...[
              const SizedBox(height: 24),
              _buildServiceSection(context, equipment),
            ],
            const SizedBox(height: 24),
            _ServiceHistorySection(equipmentId: equipmentId),
            if (equipment.notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildNotesSection(context, equipment),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, EquipmentItem equipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: equipment.isServiceDue
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(
                    _getIconForType(equipment.type),
                    size: 32,
                    color: equipment.isServiceDue
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        equipment.type.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (!equipment.isActive)
                        Chip(
                          label: const Text('Retired'),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (equipment.isServiceDue) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Service is overdue!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, EquipmentItem equipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildDetailRow(context, 'Status', equipment.status.displayName),
            if (equipment.brand != null)
              _buildDetailRow(context, 'Brand', equipment.brand!),
            if (equipment.model != null)
              _buildDetailRow(context, 'Model', equipment.model!),
            if (equipment.serialNumber != null)
              _buildDetailRow(context, 'Serial Number', equipment.serialNumber!),
            if (equipment.size != null)
              _buildDetailRow(context, 'Size', equipment.size!),
            if (equipment.purchaseDate != null)
              _buildDetailRow(
                context,
                'Purchase Date',
                DateFormat('MMM d, yyyy').format(equipment.purchaseDate!),
              ),
            if (equipment.purchasePrice != null)
              _buildDetailRow(
                context,
                'Purchase Price',
                '${equipment.purchasePrice!.toStringAsFixed(2)} ${equipment.purchaseCurrency}',
              ),
            if (equipment.ownershipDuration != null)
              _buildDetailRow(
                context,
                'Owned For',
                _formatDuration(equipment.ownershipDuration!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection(BuildContext context, EquipmentItem equipment) {
    final daysUntil = equipment.daysUntilService;
    final isOverdue = daysUntil != null && daysUntil < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Service Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow(
              context,
              'Service Interval',
              '${equipment.serviceIntervalDays} days',
            ),
            if (equipment.lastServiceDate != null)
              _buildDetailRow(
                context,
                'Last Service',
                DateFormat('MMM d, yyyy').format(equipment.lastServiceDate!),
              ),
            if (equipment.nextServiceDue != null)
              _buildDetailRow(
                context,
                'Next Service Due',
                DateFormat('MMM d, yyyy').format(equipment.nextServiceDue!),
              ),
            if (daysUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Theme.of(context).colorScheme.errorContainer
                        : daysUntil < 30
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverdue ? Icons.warning : Icons.schedule,
                        size: 16,
                        color: isOverdue
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOverdue
                            ? '${daysUntil.abs()} days overdue'
                            : '$daysUntil days until service',
                        style: TextStyle(
                          color: isOverdue
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isOverdue ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, EquipmentItem equipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              equipment.notes,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    if (days < 30) return '$days days';
    if (days < 365) return '${(days / 30).floor()} months';
    final years = (days / 365).floor();
    final months = ((days % 365) / 30).floor();
    if (months == 0) return '$years ${years == 1 ? 'year' : 'years'}';
    return '$years ${years == 1 ? 'year' : 'years'}, $months ${months == 1 ? 'month' : 'months'}';
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    EquipmentItem equipment,
  ) async {
    final notifier = ref.read(equipmentListNotifierProvider.notifier);

    switch (action) {
      case 'service':
        await notifier.markAsServiced(equipmentId);
        ref.invalidate(equipmentItemProvider(equipmentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as serviced')),
          );
        }
        break;

      case 'retire':
        await notifier.retireEquipment(equipmentId);
        ref.invalidate(equipmentItemProvider(equipmentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment retired')),
          );
        }
        break;

      case 'reactivate':
        await notifier.reactivateEquipment(equipmentId);
        ref.invalidate(equipmentItemProvider(equipmentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment reactivated')),
          );
        }
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Equipment'),
            content: const Text(
              'Are you sure you want to delete this equipment? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await notifier.deleteEquipment(equipmentId);
          if (context.mounted) {
            context.go('/equipment');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Equipment deleted')),
            );
          }
        }
        break;
    }
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

/// Service History Section Widget
class _ServiceHistorySection extends ConsumerWidget {
  final String equipmentId;

  const _ServiceHistorySection({required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(serviceRecordNotifierProvider(equipmentId));
    final totalCostAsync = ref.watch(serviceRecordTotalCostProvider(equipmentId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service History',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddServiceDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Divider(),
            recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.build_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No service records yet',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Total cost summary
                    totalCostAsync.when(
                      data: (totalCost) {
                        if (totalCost > 0) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Service Cost',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  '\$${totalCost.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    // Service records list
                    ...records.map((record) => _ServiceRecordTile(
                          record: record,
                          onTap: () => _showEditServiceDialog(context, ref, record),
                          onDelete: () => _confirmDeleteRecord(context, ref, record),
                        )),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ServiceRecordDialog(
        equipmentId: equipmentId,
        onSave: (record) async {
          await ref.read(serviceRecordNotifierProvider(equipmentId).notifier).addRecord(record);
        },
      ),
    );
  }

  void _showEditServiceDialog(BuildContext context, WidgetRef ref, ServiceRecord record) {
    showDialog(
      context: context,
      builder: (context) => ServiceRecordDialog(
        equipmentId: equipmentId,
        existingRecord: record,
        onSave: (updatedRecord) async {
          await ref.read(serviceRecordNotifierProvider(equipmentId).notifier).updateRecord(updatedRecord);
        },
      ),
    );
  }

  Future<void> _confirmDeleteRecord(BuildContext context, WidgetRef ref, ServiceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service Record?'),
        content: Text('Are you sure you want to delete this ${record.serviceType.displayName} record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(serviceRecordNotifierProvider(equipmentId).notifier).deleteRecord(record.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service record deleted')),
        );
      }
    }
  }
}

/// Service Record Tile Widget
class _ServiceRecordTile extends StatelessWidget {
  final ServiceRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ServiceRecordTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getServiceTypeIcon(record.serviceType),
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(record.serviceType.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMM d, yyyy').format(record.serviceDate)),
          if (record.provider != null)
            Text(
              record.provider!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.cost != null)
            Text(
              '\$${record.cost!.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onTap();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  IconData _getServiceTypeIcon(ServiceType type) {
    switch (type) {
      case ServiceType.annual:
        return Icons.event_repeat;
      case ServiceType.repair:
        return Icons.build;
      case ServiceType.inspection:
        return Icons.search;
      case ServiceType.overhaul:
        return Icons.settings_suggest;
      case ServiceType.replacement:
        return Icons.swap_horiz;
      case ServiceType.cleaning:
        return Icons.cleaning_services;
      case ServiceType.calibration:
        return Icons.tune;
      case ServiceType.warranty:
        return Icons.verified_user;
      case ServiceType.recall:
        return Icons.warning;
      case ServiceType.other:
        return Icons.handyman;
    }
  }
}

/// Service Record Dialog for Add/Edit
class ServiceRecordDialog extends StatefulWidget {
  final String equipmentId;
  final ServiceRecord? existingRecord;
  final Future<void> Function(ServiceRecord) onSave;

  const ServiceRecordDialog({
    super.key,
    required this.equipmentId,
    this.existingRecord,
    required this.onSave,
  });

  @override
  State<ServiceRecordDialog> createState() => _ServiceRecordDialogState();
}

class _ServiceRecordDialogState extends State<ServiceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late ServiceType _serviceType;
  late DateTime _serviceDate;
  final _providerController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _nextServiceDue;
  bool _isSaving = false;

  bool get isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final record = widget.existingRecord!;
      _serviceType = record.serviceType;
      _serviceDate = record.serviceDate;
      _providerController.text = record.provider ?? '';
      _costController.text = record.cost?.toString() ?? '';
      _notesController.text = record.notes;
      _nextServiceDue = record.nextServiceDue;
    } else {
      _serviceType = ServiceType.annual;
      _serviceDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _providerController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Service Record' : 'Add Service Record'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Service type dropdown
                DropdownButtonFormField<ServiceType>(
                  value: _serviceType,
                  decoration: const InputDecoration(
                    labelText: 'Service Type',
                    prefixIcon: Icon(Icons.build),
                  ),
                  items: ServiceType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _serviceType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Service date picker
                InkWell(
                  onTap: () => _pickServiceDate(),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Service Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(_serviceDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Provider field
                TextFormField(
                  controller: _providerController,
                  decoration: const InputDecoration(
                    labelText: 'Provider/Shop',
                    prefixIcon: Icon(Icons.store),
                    hintText: 'e.g., Dive Shop Name',
                  ),
                ),
                const SizedBox(height: 16),

                // Cost field
                TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                    labelText: 'Cost',
                    prefixIcon: Icon(Icons.attach_money),
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid amount';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Next service due date picker
                InkWell(
                  onTap: () => _pickNextServiceDate(),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Next Service Due',
                      prefixIcon: const Icon(Icons.event),
                      suffixIcon: _nextServiceDue != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _nextServiceDue = null),
                            )
                          : null,
                    ),
                    child: Text(
                      _nextServiceDue != null
                          ? DateFormat('MMM d, yyyy').format(_nextServiceDue!)
                          : 'Not set',
                      style: TextStyle(
                        color: _nextServiceDue == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _pickServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _serviceDate = picked);
    }
  }

  Future<void> _pickNextServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextServiceDue ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _nextServiceDue = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final record = ServiceRecord(
        id: widget.existingRecord?.id ?? '',
        equipmentId: widget.equipmentId,
        serviceType: _serviceType,
        serviceDate: _serviceDate,
        provider: _providerController.text.trim().isEmpty ? null : _providerController.text.trim(),
        cost: _costController.text.isEmpty ? null : double.tryParse(_costController.text),
        currency: 'USD',
        nextServiceDue: _nextServiceDue,
        notes: _notesController.text.trim(),
        createdAt: widget.existingRecord?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(record);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Service record updated' : 'Service record added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
