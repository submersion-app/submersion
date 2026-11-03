import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Fetches the data source rows a UDDF export should carry for [diveIds].
///
/// [options] is unused by the default fetch, which needs the rows whatever
/// they say; it keeps the shape of `UddfDivesExtrasFetch`, whose fetch does
/// read them.
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
      resolveDataSources(ref.read(diveRepositoryProvider), diveIds);
});

/// The data source rows a UDDF export carries for [diveIds].
///
/// Every export needs them, with the raw data box ticked or not: they are a
/// dive's computers, each one's own samples and its per-source values. The box
/// decides only whether the writers add each row's original bytes (issue
/// #4180), so the rows are fetched either way.
Future<List<DiveSourceExport>> resolveDataSources(
  DiveRepository repository,
  List<String> diveIds,
) => repository.getSourcesForExport(diveIds);
