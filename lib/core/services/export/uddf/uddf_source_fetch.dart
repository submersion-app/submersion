import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Fetches the data source rows a UDDF export should carry for [diveIds].
typedef UddfSourceFetch =
    Future<List<DiveSourceExport>> Function(
      List<String> diveIds,
      UddfExportOptions options,
    );

/// The fetch every UDDF export path uses.
///
/// A provider rather than a direct repository read at each call site, because
/// the export actions live in widgets whose tests have no database. Overriding
/// this is how such a test opts out, the same way they already override
/// `exportServiceProvider`, and it keeps the rule itself in one place.
final uddfSourceFetchProvider = Provider<UddfSourceFetch>((ref) {
  return (diveIds, options) =>
      resolveDataSources(ref.read(diveRepositoryProvider), diveIds, options);
});

/// Whether a UDDF export fetches data source rows, and the fetch itself.
///
/// One rule rather than four copies of it: the settings notifier and the three
/// page level export actions all go through here. A share with the raw data
/// box unchecked must not pay for a query it will not use, which is the whole
/// point of the toggle on the dives only paths.
Future<List<DiveSourceExport>> resolveDataSources(
  DiveRepository repository,
  List<String> diveIds,
  UddfExportOptions options,
) async {
  if (!options.includeRawData) return const [];
  return repository.getSourcesForExport(diveIds);
}
