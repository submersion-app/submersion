import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart'
    show tankPressureRepositoryProvider;
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
  return (diveIds, options) => resolveDataSources(
    ref.read(diveRepositoryProvider),
    diveIds,
    includeRawData: options.includeRawData,
  );
});

/// Builds the loader a UDDF export reads each run of its dives through, for
/// an export made with [UddfExportOptions].
typedef UddfDiveChunksFor =
    UddfDiveChunkLoader Function(UddfExportOptions options);

/// The run loader every UDDF export path uses: each run's profiles and tank
/// pressures from the database, and its sources through
/// [uddfSourceFetchProvider], read as the run is written (issue #4249).
///
/// A provider for the same reason as [uddfSourceFetchProvider].
final uddfDiveChunksProvider = Provider<UddfDiveChunksFor>((ref) {
  return (options) => databaseUddfDiveChunks(
    diveRepository: ref.read(diveRepositoryProvider),
    tankPressureRepository: ref.read(tankPressureRepositoryProvider),
    fetchSources: (ids) => ref.read(uddfSourceFetchProvider)(ids, options),
  );
});

/// The data source rows a UDDF export carries for [diveIds].
///
/// Every export needs them, with the raw data box ticked or not: they are a
/// dive's computers, each one's own samples and its per-source values. The box
/// decides only whether each row's original bytes come too (issue #4180), so
/// the rows are fetched either way, and the bytes only when [includeRawData].
Future<List<DiveSourceExport>> resolveDataSources(
  DiveRepository repository,
  List<String> diveIds, {
  bool includeRawData = true,
}) => repository.getSourcesForExport(diveIds, includeRawData: includeRawData);
