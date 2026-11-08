import 'package:drift/drift.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_empty_parse.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

/// Parses one dive's raw dive computer bytes. The native Pigeon call in the
/// app; a fake in tests.
typedef RawDiveParseFn =
    Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    );

/// The error a dive fails with when a stored source lacks the vendor,
/// product or model needed to parse it. The results dialog shows its own
/// translation in place of this English text.
const missingDescriptorsError = 'Missing dive computer details';

/// One dive a batch re-parse could not refresh, with the first error.
class ReparseDiveFailure {
  const ReparseDiveFailure({required this.diveId, required this.error});

  final String diveId;
  final String error;
}

/// What a batch re-parse did, counted in dives.
class ReparseBatchResult {
  const ReparseBatchResult({
    required this.total,
    required this.succeeded,
    required this.skipped,
    required this.notProcessed,
    required this.profilesPreserved,
    required this.failures,
  });

  /// Every dive the run was asked to re-parse.
  final int total;
  final int succeeded;

  /// Dives with no raw data to re-parse (in the filter, when one is given).
  final int skipped;

  /// Dives a cancel stopped the run before reaching.
  final int notProcessed;

  /// Succeeded dives whose combined profile was deliberately left alone.
  final int profilesPreserved;
  final List<ReparseDiveFailure> failures;

  int get failed => failures.length;
  bool get cancelled => notProcessed > 0;
}

/// How many dives one dive computer has raw data for.
class ComputerRawDataCount {
  const ComputerRawDataCount({
    required this.computerId,
    required this.computerName,
    required this.dives,
  });

  final String? computerId;

  /// Empty when the computer row is gone; the UI names it.
  final String computerName;
  final int dives;
}

/// Re-parses many dives from their stored raw bytes (issue #224).
///
/// Every batch re-parse runs through [run]: selected dives, the whole log
/// and one computer's dives. Work is counted per dive: each of a dive's
/// sources is parsed before any is written, so a parse failure leaves the
/// whole dive untouched. The writes themselves stay
/// [ReparseService.applyParsedUpdate], one transaction per source.
class ReparseBatchService {
  ReparseBatchService(this._reparse);

  static final _log = LoggerService.forClass(ReparseBatchService);

  final ReparseService _reparse;

  AppDatabase get _db => _reparse.db;

  /// Every dive with raw data, oldest first, for [diverId] (every diver when
  /// null).
  Future<List<String>> diveIdsWithRawData({required String? diverId}) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'WHERE EXISTS (SELECT 1 FROM dive_data_sources s '
          'WHERE s.dive_id = d.id AND s.raw_data IS NOT NULL) '
          '${diverId == null ? '' : 'AND d.diver_id = ? '}'
          'ORDER BY d.dive_date_time, d.id',
          variables: [if (diverId != null) Variable(diverId)],
          readsFrom: {_db.dives, _db.diveDataSources},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// The dives [computerId] holds raw data for, oldest first.
  Future<List<String>> diveIdsForComputer(String computerId) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'WHERE EXISTS (SELECT 1 FROM dive_data_sources s '
          'WHERE s.dive_id = d.id AND s.computer_id = ? '
          'AND s.raw_data IS NOT NULL) '
          'ORDER BY d.dive_date_time, d.id',
          variables: [Variable(computerId)],
          readsFrom: {_db.dives, _db.diveDataSources},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// The dives of [diveIds] that have raw data, in the order given.
  Future<List<String>> withRawData(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    final query = _db.selectOnly(_db.diveDataSources, distinct: true)
      ..addColumns([_db.diveDataSources.diveId])
      ..where(
        _db.diveDataSources.diveId.isIn(diveIds) &
            _db.diveDataSources.rawData.isNotNull(),
      );
    final found = {
      for (final row in await query.get())
        row.read(_db.diveDataSources.diveId)!,
    };
    return [
      for (final id in diveIds)
        if (found.contains(id)) id,
    ];
  }

  /// Dives with raw data per computer, for [diverId] (every diver when null).
  Future<List<ComputerRawDataCount>> rawDataCountsByComputer({
    required String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT s.computer_id AS computer_id, '
          "COALESCE(c.name, '') AS name, "
          'COUNT(DISTINCT s.dive_id) AS dives '
          'FROM dive_data_sources s '
          'JOIN dives d ON d.id = s.dive_id '
          'LEFT JOIN dive_computers c ON c.id = s.computer_id '
          'WHERE s.raw_data IS NOT NULL '
          '${diverId == null ? '' : 'AND d.diver_id = ? '}'
          'GROUP BY s.computer_id, c.name '
          'ORDER BY name',
          variables: [if (diverId != null) Variable(diverId)],
          readsFrom: {_db.dives, _db.diveDataSources, _db.diveComputers},
        )
        .get();
    return [
      for (final r in rows)
        ComputerRawDataCount(
          computerId: r.readNullable<String>('computer_id'),
          computerName: r.read<String>('name'),
          dives: r.read<int>('dives'),
        ),
    ];
  }

  /// Logged dives of [diverId] (every diver when null) with nothing to
  /// re-parse.
  Future<int> diveCountWithoutRawData({required String? diverId}) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM dives d '
          'WHERE d.is_planned = 0 '
          'AND NOT EXISTS (SELECT 1 FROM dive_data_sources s '
          'WHERE s.dive_id = d.id AND s.raw_data IS NOT NULL) '
          '${diverId == null ? '' : 'AND d.diver_id = ? '}',
          variables: [if (diverId != null) Variable(diverId)],
          readsFrom: {_db.dives, _db.diveDataSources},
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Re-parses [diveIds] in order, as one change-log operation.
  ///
  /// With [computerId], only that computer's sources on each dive are
  /// re-parsed. [onProgress] runs after every dive; [isCancelled] is checked
  /// before every dive, so a cancel never splits one.
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) => ChangeLogScope.bulk(
    _db,
    label: ChangeLogLabels.reparse,
    body: () => _run(
      diveIds,
      parseFn: parseFn,
      computerId: computerId,
      onProgress: onProgress,
      isCancelled: isCancelled,
    ),
  );

  Future<ReparseBatchResult> _run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final total = diveIds.length;
    final failures = <ReparseDiveFailure>[];
    final changed = <String>[];
    var skipped = 0;
    var notProcessed = 0;
    var profilesPreserved = 0;

    for (var i = 0; i < total; i++) {
      if (isCancelled?.call() ?? false) {
        notProcessed = total - i;
        break;
      }
      final diveId = diveIds[i];
      final outcome = await _reparseOne(diveId, parseFn, computerId);
      switch (outcome) {
        case _Skipped():
          skipped++;
        case _Failed(:final error):
          failures.add(ReparseDiveFailure(diveId: diveId, error: error));
        case _Succeeded(:final profilePreserved):
          changed.add(diveId);
          if (profilePreserved) profilesPreserved++;
      }
      onProgress?.call(i + 1, total);
    }

    // The re-parse rewrote the profile strands; the sensor summary and the
    // derived metrics are computed from them.
    if (changed.isNotEmpty) {
      scheduleSensorSummaryRefresh(changed);
      scheduleDerivedMetricsRefresh(changed);
    }

    return ReparseBatchResult(
      total: total,
      succeeded: changed.length,
      skipped: skipped,
      notProcessed: notProcessed,
      profilesPreserved: profilesPreserved,
      failures: List.unmodifiable(failures),
    );
  }

  /// Parses every source of [diveId] first, then applies them all, so a
  /// parse failure writes nothing.
  Future<_DiveOutcome> _reparseOne(
    String diveId,
    RawDiveParseFn parseFn,
    String? computerId,
  ) async {
    final sources = [
      for (final s in await _reparse.getSourcesForDiveReparse(diveId))
        if (computerId == null || s.computerId == computerId) s,
    ];
    if (sources.isEmpty) return const _Skipped();

    final parsed = <(DiveDataSourcesData, pigeon.ParsedDive)>[];
    for (final source in sources) {
      final vendor = source.descriptorVendor;
      final product = source.descriptorProduct;
      final model = source.descriptorModel;
      if (vendor == null || product == null || model == null) {
        return const _Failed(missingDescriptorsError);
      }
      try {
        final dive = await parseFn(vendor, product, model, source.rawData!);
        if (isEmptyParse(dive)) {
          return _Failed(const EmptyParseException().toString());
        }
        parsed.add((source, dive));
      } catch (e) {
        return _Failed(e.toString());
      }
    }

    var profilePreserved = false;
    for (final (source, dive) in parsed) {
      try {
        final outcome = await _reparse.applyParsedUpdate(
          diveId: diveId,
          sourceRowId: source.id,
          parsed: dive,
          descriptorVendor: source.descriptorVendor,
          descriptorProduct: source.descriptorProduct,
          descriptorModel: source.descriptorModel,
          libdivecomputerVersion: source.libdivecomputerVersion,
        );
        profilePreserved = profilePreserved || outcome.profilePreserved;
      } catch (e, stackTrace) {
        // A database fault: sources already applied stay applied.
        _log.error(
          'Re-parse of dive $diveId failed while writing',
          error: e,
          stackTrace: stackTrace,
        );
        return _Failed(e.toString());
      }
    }
    return _Succeeded(profilePreserved: profilePreserved);
  }
}

sealed class _DiveOutcome {
  const _DiveOutcome();
}

class _Skipped extends _DiveOutcome {
  const _Skipped();
}

class _Failed extends _DiveOutcome {
  const _Failed(this.error);
  final String error;
}

class _Succeeded extends _DiveOutcome {
  const _Succeeded({required this.profilePreserved});
  final bool profilePreserved;
}
