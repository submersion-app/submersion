import 'package:equatable/equatable.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Detects outliers in a dive's profile for showing suggestion badges.
///
/// Returns the list of detected outliers (empty if none found).
/// Read by the Profile card's outliers button, beside Edit profile.
final outlierSuggestionProvider = FutureProvider.autoDispose
    .family<List<OutlierResult>, String>((ref, diveId) async {
      retainDiveData(ref);
      // The profile alone: a change to anything else on the dive (notes, a
      // rating, a sync) does not run the detection again. Compared by value,
      // since every reload reads it into a new list.
      final profile = (await ref.watch(
        diveProvider(diveId).selectAsync((dive) => _ProfileKey(dive?.profile)),
      )).points;
      if (profile == null || profile.length < 10) return [];

      final service = ProfileEditingService();
      return service.detectOutliers(profile);
    });

/// A dive's profile compared point by point, not as the list object.
class _ProfileKey extends Equatable {
  const _ProfileKey(this.points);

  final List<DiveProfilePoint>? points;

  @override
  List<Object?> get props => [points];
}
