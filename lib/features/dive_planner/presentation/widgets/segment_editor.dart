import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../dive_log/domain/entities/dive.dart';
import '../../domain/entities/plan_segment.dart';

const _uuid = Uuid();

/// Dialog for creating and editing dive plan segments.
class SegmentEditor extends StatefulWidget {
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
  State<SegmentEditor> createState() => _SegmentEditorState();
}

class _SegmentEditorState extends State<SegmentEditor> {
  late SegmentType _type;
  late TextEditingController _startDepthController;
  late TextEditingController _endDepthController;
  late TextEditingController _durationController;
  late TextEditingController _rateController;
  late String _selectedTankId;

  @override
  void initState() {
    super.initState();
    final segment = widget.segment;

    _type = segment?.type ?? SegmentType.bottom;
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
      text: segment?.rate?.toStringAsFixed(0) ?? '10',
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
                    decoration: const InputDecoration(
                      labelText: 'Start Depth (m)',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: _type != SegmentType.gasSwitch,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _endDepthController,
                    decoration: const InputDecoration(
                      labelText: 'End Depth (m)',
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
                      ? 'Descent Rate (m/min)'
                      : 'Ascent Rate (m/min)',
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

  void _updateDefaultsForType(SegmentType type) {
    switch (type) {
      case SegmentType.descent:
        _startDepthController.text = '0';
        _rateController.text = '18';
        break;
      case SegmentType.bottom:
        // Keep end depth as target
        _startDepthController.text = _endDepthController.text;
        break;
      case SegmentType.ascent:
        _rateController.text = '9';
        break;
      case SegmentType.decoStop:
        _durationController.text = '3';
        break;
      case SegmentType.safetyStop:
        _startDepthController.text = '5';
        _endDepthController.text = '5';
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
    final selectedTank = widget.availableTanks.firstWhere(
      (t) => t.id == _selectedTankId,
    );

    final startDepth = double.tryParse(_startDepthController.text) ?? 0;
    final endDepth = double.tryParse(_endDepthController.text) ?? 0;
    final durationMinutes = int.tryParse(_durationController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 10;

    final segment = PlanSegment(
      id: widget.segment?.id ?? _uuid.v4(),
      type: _type,
      startDepth: startDepth,
      endDepth: endDepth,
      durationSeconds: durationMinutes * 60,
      tankId: _selectedTankId,
      gasMix: selectedTank.gasMix,
      rate: rate,
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
