import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/weight_calculator.dart';

class WeightCalculatorPage extends StatefulWidget {
  const WeightCalculatorPage({super.key});

  @override
  State<WeightCalculatorPage> createState() => _WeightCalculatorPageState();
}

class _WeightCalculatorPageState extends State<WeightCalculatorPage> {
  String _selectedSuit = 'wetsuit_5mm';
  TankMaterial? _selectedTank = TankMaterial.aluminum;
  WaterType? _selectedWater = WaterType.salt;
  final _bodyWeightController = TextEditingController();

  @override
  void dispose() {
    _bodyWeightController.dispose();
    super.dispose();
  }

  double get _calculatedWeight {
    final bodyWeight = double.tryParse(_bodyWeightController.text);
    return WeightCalculator.calculateRecommendedWeight(
      suitType: _selectedSuit,
      tankMaterial: _selectedTank,
      waterType: _selectedWater,
      bodyWeightKg: bodyWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Calculator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Result card at top
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Recommended Weight',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_calculatedWeight.toStringAsFixed(1)} kg',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${(_calculatedWeight * 2.205).toStringAsFixed(1)} lbs)',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Exposure Suit
          Text('Exposure Suit', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: WeightCalculator.suitTypes.entries.map((entry) {
                return RadioListTile<String>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: _selectedSuit,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSuit = value);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Tank Material
          Text('Tank Material', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<TankMaterial?>(
                  title: const Text('Not specified'),
                  value: null,
                  groupValue: _selectedTank,
                  onChanged: (value) {
                    setState(() => _selectedTank = value);
                  },
                ),
                ...TankMaterial.values.map((material) {
                  return RadioListTile<TankMaterial?>(
                    title: Text(material.displayName),
                    subtitle: Text(_getTankDescription(material)),
                    value: material,
                    groupValue: _selectedTank,
                    onChanged: (value) {
                      setState(() => _selectedTank = value);
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Water Type
          Text('Water Type', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<WaterType?>(
                  title: const Text('Not specified'),
                  value: null,
                  groupValue: _selectedWater,
                  onChanged: (value) {
                    setState(() => _selectedWater = value);
                  },
                ),
                ...WaterType.values.map((water) {
                  return RadioListTile<WaterType?>(
                    title: Text(water.displayName),
                    value: water,
                    groupValue: _selectedWater,
                    onChanged: (value) {
                      setState(() => _selectedWater = value);
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Body Weight (optional)
          Text('Body Weight (optional)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _bodyWeightController,
                decoration: const InputDecoration(
                  labelText: 'Your weight',
                  suffixText: 'kg',
                  helperText: 'Adds ~1 kg per 10 kg over 70 kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Disclaimer
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is an estimate only. Always perform a buoyancy check at the start of your dive and adjust as needed. Factors like BCD, personal buoyancy, and breathing patterns will affect your actual weight requirements.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getTankDescription(TankMaterial material) {
    switch (material) {
      case TankMaterial.aluminum:
        return 'More buoyant when empty (+2 kg)';
      case TankMaterial.steel:
        return 'Negatively buoyant (-2 kg)';
      case TankMaterial.carbonFiber:
        return 'Very buoyant (+3 kg)';
    }
  }
}

