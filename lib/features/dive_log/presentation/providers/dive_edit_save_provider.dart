import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// The service that saves an editing sitting on a dive.
final diveEditSaveServiceProvider = Provider<DiveEditSaveService>((ref) {
  return DiveEditSaveService(ref.watch(diveRepositoryProvider));
});
