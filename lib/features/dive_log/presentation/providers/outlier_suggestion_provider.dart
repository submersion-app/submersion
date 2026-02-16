import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Detects outliers in a dive's profile for showing suggestion badges.
///
/// Returns the list of detected outliers (empty if none found).
/// Used on DiveDetailPage to show "X potential outliers detected" chip.
final outlierSuggestionProvider =
    FutureProvider.family<List<OutlierResult>, String>((ref, diveId) async {
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null || dive.profile.length < 10) return [];

      final service = ProfileEditingService();
      return service.detectOutliers(dive.profile);
    });
