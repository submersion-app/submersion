import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

const _uuid = Uuid();

/// Dialog for creating and editing dive plan segments.
class SegmentEditor extends ConsumerStatefulWidget {
  /// Segment to edit (null for new segment).
  final PlanSegment? segment;

  /// Available tanks for gas selection.
  final List<DiveTank> availableTanks;

  /// Callback when segment is saved.
  final ValueChanged<PlanSegment> onSave;

  const SegmentEditor({
    super.key,
    this.segment,
    required this.availableTanks,
    required this.onSave,
  });

  @override
  ConsumerState<SegmentEditor> createState() => _SegmentEditorState();
}

class _SegmentEditorState extends ConsumerState<SegmentEditor> {
  late SegmentType _type;
  late TextEditingController _startDepthController;
  late TextEditingController _endDepthController;
  late TextEditingController _durationController;
  late TextEditingController _rateController;
  late String _selectedTankId;
  bool _unitsInitialized = false;

  @override
  void initState() {
    super.initState();
    final segment = widget.segment;

    _type = segment?.type ?? SegmentType.bottom;
    // Initialize with raw meter values - will convert in first build
    _startDepthController = TextEditingController(
      text: segment != null ? segment.startDepth.toStringAsFixed(0) : '0',
    );
    _endDepthController = TextEditingController(
      text: segment != null ? segment.endDepth.toStringAsFixed(0) : '18',
    );
    _durationController = TextEditingController(
      text: segment != null ? (segment.durationSeconds ~/ 60).toString() : '20',
    );
    _rateController = TextEditingController(
      text: segment?.rate?.abs().toStringAsFixed(0) ?? '10',
    );
    _selectedTankId = segment?.tankId ?? widget.availableTanks.first.id;
  }

  @override
  void dispose() {
    _startDepthController.dispose();
    _endDepthController.dispose();
    _durationController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.segment == null;
    final showRate =
        _type == SegmentType.descent || _type == SegmentType.ascent;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Convert meter values to user's preferred units on first build
    if (!_unitsInitialized) {
      _unitsInitialized = true;
      _convertControllersToUserUnits(units);
    }

    return AlertDialog(
      title: Text(isNew ? 'Add Segment' : 'Edit Segment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Segment type dropdown
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Segment Type'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SegmentType>(
                  value: _type,
                  isExpanded: true,
                  isDense: true,
                  items: SegmentType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          _SegmentTypeIcon(type: type),
                          const SizedBox(width: 8),
                          Text(_getTypeLabel(type)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _type = value;
                        _updateDefaultsForType(value);
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Depth inputs
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startDepthController,
                    decoration: InputDecoration(
                      labelText: 'Start Depth (${units.depthSymbol})',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: _type != SegmentType.gasSwitch,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _endDepthController,
                    decoration: InputDecoration(
                      labelText: 'End Depth (${units.depthSymbol})',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: _type != SegmentType.gasSwitch,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duration input
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Duration (min)',
                helperText: _type == SegmentType.gasSwitch
                    ? 'Gas switch time'
                    : null,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Rate input (only for descent/ascent)
            if (showRate) ...[
              TextField(
                controller: _rateController,
                decoration: InputDecoration(
                  labelText: _type == SegmentType.descent
                      ? 'Descent Rate (${units.depthSymbol}/min)'
                      : 'Ascent Rate (${units.depthSymbol}/min)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],

            // Tank selection
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Tank / Gas'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTankId,
                  isExpanded: true,
                  isDense: true,
                  items: widget.availableTanks.map((tank) {
                    return DropdownMenuItem(
                      value: tank.id,
                      child: Text(tank.name ?? tank.gasMix.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTankId = value);
                    }
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

  /// Convert controller values from meters to user's preferred units.
  void _convertControllersToUserUnits(UnitFormatter units) {
    final startDepthMeters = double.tryParse(_startDepthController.text) ?? 0;
    final endDepthMeters = double.tryParse(_endDepthController.text) ?? 0;
    final rateMeters = double.tryParse(_rateController.text) ?? 10;

    _startDepthController.text = units
        .convertDepth(startDepthMeters)
        .toStringAsFixed(0);
    _endDepthController.text = units
        .convertDepth(endDepthMeters)
        .toStringAsFixed(0);
    _rateController.text = units.convertDepth(rateMeters).toStringAsFixed(0);
  }

  void _updateDefaultsForType(SegmentType type) {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);

    switch (type) {
      case SegmentType.descent:
        _startDepthController.text = '0';
        // 18 m/min default descent rate
        _rateController.text = units.convertDepth(18).toStringAsFixed(0);
        break;
      case SegmentType.bottom:
        // Keep end depth as target
        _startDepthController.text = _endDepthController.text;
        break;
      case SegmentType.ascent:
        // 9 m/min default ascent rate
        _rateController.text = units.convertDepth(9).toStringAsFixed(0);
        break;
      case SegmentType.decoStop:
        _durationController.text = '3';
        break;
      case SegmentType.safetyStop:
        // 5m default safety stop depth
        final safetyDepth = units.convertDepth(5).toStringAsFixed(0);
        _startDepthController.text = safetyDepth;
        _endDepthController.text = safetyDepth;
        _durationController.text = '3';
        break;
      case SegmentType.gasSwitch:
        _durationController.text = '1';
        break;
    }
  }

  String _getTypeLabel(SegmentType type) {
    switch (type) {
      case SegmentType.descent:
        return 'Descent';
      case SegmentType.bottom:
        return 'Bottom Time';
      case SegmentType.ascent:
        return 'Ascent';
      case SegmentType.decoStop:
        return 'Deco Stop';
      case SegmentType.safetyStop:
        return 'Safety Stop';
      case SegmentType.gasSwitch:
        return 'Gas Switch';
    }
  }

  void _save() {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);

    final selectedTank = widget.availableTanks.firstWhere(
      (t) => t.id == _selectedTankId,
    );

    // Parse values in user's units and convert to meters for storage
    final startDepthUserUnits =
        double.tryParse(_startDepthController.text) ?? 0;
    final endDepthUserUnits = double.tryParse(_endDepthController.text) ?? 0;
    final durationMinutes = int.tryParse(_durationController.text) ?? 0;
    final rateUserUnits = double.tryParse(_rateController.text) ?? 10;

    // Convert depths and rate from user units to meters
    final startDepthMeters = units.depthToMeters(startDepthUserUnits);
    final endDepthMeters = units.depthToMeters(endDepthUserUnits);
    final rateMeters = units.depthToMeters(rateUserUnits);

    final segment = PlanSegment(
      id: widget.segment?.id ?? _uuid.v4(),
      type: _type,
      startDepth: startDepthMeters,
      endDepth: endDepthMeters,
      durationSeconds: durationMinutes * 60,
      tankId: _selectedTankId,
      gasMix: selectedTank.gasMix,
      rate: rateMeters,
      order: widget.segment?.order ?? 0,
    );

    widget.onSave(segment);
    Navigator.pop(context);
  }
}

class _SegmentTypeIcon extends StatelessWidget {
  final SegmentType type;

  const _SegmentTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case SegmentType.descent:
        icon = Icons.arrow_downward;
        color = Colors.blue;
        break;
      case SegmentType.bottom:
        icon = Icons.horizontal_rule;
        color = Theme.of(context).colorScheme.primary;
        break;
      case SegmentType.ascent:
        icon = Icons.arrow_upward;
        color = Colors.green;
        break;
      case SegmentType.decoStop:
        icon = Icons.stop_circle;
        color = Colors.orange;
        break;
      case SegmentType.gasSwitch:
        icon = Icons.swap_horiz;
        color = Colors.purple;
        break;
      case SegmentType.safetyStop:
        icon = Icons.pause_circle;
        color = Colors.teal;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }
}
