import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/units.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/utils/weight_calculator.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

class WeightCalculatorPage extends ConsumerStatefulWidget {
  const WeightCalculatorPage({super.key});

  @override
  ConsumerState<WeightCalculatorPage> createState() => _WeightCalculatorPageState();
}

class _WeightCalculatorPageState extends ConsumerState<WeightCalculatorPage> {
  String _selectedSuit = 'wetsuit_5mm';
  TankMaterial? _selectedTank = TankMaterial.aluminum;
  WaterType? _selectedWater = WaterType.salt;
  final _bodyWeightController = TextEditingController();

  @override
  void dispose() {
    _bodyWeightController.dispose();
    super.dispose();
  }

  double _getCalculatedWeightKg() {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    
    // Convert body weight input from display unit to kg
    final bodyWeightInput = double.tryParse(_bodyWeightController.text);
    final bodyWeightKg = bodyWeightInput != null ? units.weightToKg(bodyWeightInput) : null;
    
    return WeightCalculator.calculateRecommendedWeight(
      suitType: _selectedSuit,
      tankMaterial: _selectedTank,
      waterType: _selectedWater,
      bodyWeightKg: bodyWeightKg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final isMetric = settings.weightUnit == WeightUnit.kilograms;
    
    final calculatedWeightKg = _getCalculatedWeightKg();
    
    // Primary display in user's preferred unit
    final primaryWeight = units.convertWeight(calculatedWeightKg);
    final primaryUnit = units.weightSymbol;
    
    // Secondary display in the other unit
    final secondaryWeight = isMetric 
        ? calculatedWeightKg * 2.205  // kg to lbs
        : calculatedWeightKg;          // show kg
    final secondaryUnit = isMetric ? 'lbs' : 'kg';

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
                    '${primaryWeight.toStringAsFixed(1)} $primaryUnit',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${secondaryWeight.toStringAsFixed(1)} $secondaryUnit)',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
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
                final isSelected = entry.key == _selectedSuit;
                return ListTile(
                  title: Text(entry.value),
                  trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                  onTap: () => setState(() => _selectedSuit = entry.key),
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
                ListTile(
                  title: const Text('Not specified'),
                  trailing: _selectedTank == null ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                  onTap: () => setState(() => _selectedTank = null),
                ),
                ...TankMaterial.values.map((material) {
                  final isSelected = material == _selectedTank;
                  return ListTile(
                    title: Text(material.displayName),
                    subtitle: Text(_getTankDescription(material, isMetric)),
                    trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                    onTap: () => setState(() => _selectedTank = material),
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
                ListTile(
                  title: const Text('Not specified'),
                  trailing: _selectedWater == null ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                  onTap: () => setState(() => _selectedWater = null),
                ),
                ...WaterType.values.map((water) {
                  final isSelected = water == _selectedWater;
                  return ListTile(
                    title: Text(water.displayName),
                    trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                    onTap: () => setState(() => _selectedWater = water),
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
                decoration: InputDecoration(
                  labelText: 'Your weight',
                  suffixText: primaryUnit,
                  helperText: isMetric 
                      ? 'Adds ~1 kg per 10 kg over 70 kg'
                      : 'Adds ~2 lbs per 22 lbs over 154 lbs',
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

  String _getTankDescription(TankMaterial material, bool isMetric) {
    switch (material) {
      case TankMaterial.aluminum:
        return isMetric 
            ? 'More buoyant when empty (+2 kg)'
            : 'More buoyant when empty (+4 lbs)';
      case TankMaterial.steel:
        return isMetric
            ? 'Negatively buoyant (-2 kg)'
            : 'Negatively buoyant (-4 lbs)';
      case TankMaterial.carbonFiber:
        return isMetric
            ? 'Very buoyant (+3 kg)'
            : 'Very buoyant (+7 lbs)';
    }
  }
}
