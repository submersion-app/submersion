import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/provider.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../dive_log/domain/entities/dive.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/dive_planner_providers.dart';

const _uuid = Uuid();

/// Widget for managing tanks in a dive plan.
class PlanTankList extends ConsumerWidget {
  const PlanTankList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.propane_tank, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tanks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Tank',
                  onPressed: () => _showAddTankDialog(context, ref, units),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tank chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: planState.tanks.map((tank) {
                return _TankChip(
                  tank: tank,
                  units: units,
                  onEdit: () => _showEditTankDialog(context, ref, tank, units),
                  onDelete: planState.tanks.length > 1
                      ? () => ref
                            .read(divePlanNotifierProvider.notifier)
                            .removeTank(tank.id)
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTankDialog(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    showDialog(
      context: context,
      builder: (context) => _TankEditDialog(
        units: units,
        onSave: (tank) {
          ref.read(divePlanNotifierProvider.notifier).addTank(tank);
        },
      ),
    );
  }

  void _showEditTankDialog(
    BuildContext context,
    WidgetRef ref,
    DiveTank tank,
    UnitFormatter units,
  ) {
    showDialog(
      context: context,
      builder: (context) => _TankEditDialog(
        tank: tank,
        units: units,
        onSave: (updated) {
          ref
              .read(divePlanNotifierProvider.notifier)
              .updateTank(tank.id, updated);
        },
      ),
    );
  }
}

class _TankChip extends StatelessWidget {
  final DiveTank tank;
  final UnitFormatter units;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _TankChip({
    required this.tank,
    required this.units,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InputChip(
      avatar: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          tank.gasMix.name.substring(0, 1),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tank.name ?? tank.gasMix.name),
          Text(
            '${units.formatPressure(tank.startPressure?.toDouble())} • ${units.formatVolume(tank.volume)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      onPressed: onEdit,
      deleteIcon: onDelete != null ? const Icon(Icons.close, size: 18) : null,
      onDeleted: onDelete,
    );
  }
}

class _TankEditDialog extends StatefulWidget {
  final DiveTank? tank;
  final UnitFormatter units;
  final ValueChanged<DiveTank> onSave;

  const _TankEditDialog({this.tank, required this.units, required this.onSave});

  @override
  State<_TankEditDialog> createState() => _TankEditDialogState();
}

class _TankEditDialogState extends State<_TankEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _volumeController;
  late TextEditingController _pressureController;
  late TextEditingController _o2Controller;
  late TextEditingController _heController;
  TankRole _role = TankRole.backGas;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tank?.name ?? '');
    _volumeController = TextEditingController(
      text: widget.tank?.volume?.toStringAsFixed(1) ?? '11.1',
    );
    _pressureController = TextEditingController(
      text: widget.tank?.startPressure?.toString() ?? '200',
    );
    _o2Controller = TextEditingController(
      text: widget.tank?.gasMix.o2.toString() ?? '21',
    );
    _heController = TextEditingController(
      text: widget.tank?.gasMix.he.toString() ?? '0',
    );
    _role = widget.tank?.role ?? TankRole.backGas;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    _pressureController.dispose();
    _o2Controller.dispose();
    _heController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.tank == null;

    return AlertDialog(
      title: Text(isNew ? 'Add Tank' : 'Edit Tank'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Primary, Stage 1',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _volumeController,
                    decoration: InputDecoration(
                      labelText: 'Volume (${widget.units.volumeSymbol})',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _pressureController,
                    decoration: InputDecoration(
                      labelText: 'Start (${widget.units.pressureSymbol})',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _o2Controller,
                    decoration: const InputDecoration(labelText: 'O₂ %'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _heController,
                    decoration: const InputDecoration(labelText: 'He %'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Role'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TankRole>(
                  value: _role,
                  isExpanded: true,
                  isDense: true,
                  items: TankRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final tank = DiveTank(
      id: widget.tank?.id ?? _uuid.v4(),
      name: _nameController.text.isNotEmpty ? _nameController.text : null,
      volume: double.tryParse(_volumeController.text),
      startPressure: int.tryParse(_pressureController.text),
      gasMix: GasMix(
        o2: double.tryParse(_o2Controller.text) ?? 21,
        he: double.tryParse(_heController.text) ?? 0,
      ),
      role: _role,
      order: widget.tank?.order ?? 0,
    );

    widget.onSave(tank);
    Navigator.pop(context);
  }
}
