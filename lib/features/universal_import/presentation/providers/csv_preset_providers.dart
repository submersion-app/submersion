import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';

/// Singleton repository for user-saved CSV presets.
final csvPresetRepositoryProvider = Provider<CsvPresetRepository>((ref) {
  return CsvPresetRepository();
});

/// All user-saved CSV presets, ordered by name.
///
/// Invalidate this provider after saving or deleting a preset to refresh.
final userCsvPresetsProvider = FutureProvider<List<CsvPreset>>((ref) async {
  final repo = ref.read(csvPresetRepositoryProvider);
  return repo.getAllPresets();
});
