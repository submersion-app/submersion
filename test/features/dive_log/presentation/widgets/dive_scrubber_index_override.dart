import 'dart:async';

import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Serves [entries] as the scrubber index, built for the current diver,
/// filter and sort and refetched whenever one of them changes.
Override diveScrubberIndexOverride(
  FutureOr<List<DiveScrubberEntry>> Function() entries,
) => diveScrubberIndexProvider.overrideWith((ref) {
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(diveFilterProvider);
  final sort = ref.watch(diveSortProvider);
  DiveScrubberIndex built(List<DiveScrubberEntry> list) => DiveScrubberIndex(
    entries: list,
    diverId: diverId,
    filter: filter,
    sort: sort,
  );
  final result = entries();
  return result is Future<List<DiveScrubberEntry>>
      ? result.then(built)
      : built(result);
});
