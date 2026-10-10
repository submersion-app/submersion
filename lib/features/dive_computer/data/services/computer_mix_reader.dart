import 'package:drift/drift.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/computer_recorded_tank.dart';

/// Parses one download's raw bytes, as `DiveComputerHostApi.parseRawDiveData`
/// does. A parameter so tests need no native bridge.
typedef RawDiveParseFn =
    Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    );

final _log = LoggerService.forClass(ComputerMixReader);

/// Reads the gas mix a dive computer recorded for a tank back out of the
/// download's stored raw bytes (issue #3021).
///
/// The tank row's own mix is the diver's to edit, so once edited it no
/// longer says what the computer logged. The raw bytes still do: parsing
/// them resolves the cylinders exactly as the download did, and the row's
/// parsed tank index picks its cylinder. Nothing is written; the editor
/// shows the mix and offers to put it back.
class ComputerMixReader {
  const ComputerMixReader({required this.db, required this.parseFn});

  final AppDatabase db;
  final RawDiveParseFn parseFn;

  /// The mix [tank]'s computer recorded on dive [diveId], or null when it
  /// cannot be known: a hand-added tank, a download without raw bytes, or
  /// bytes that no longer parse to that cylinder.
  Future<domain.GasMix?> recordedMix({
    required String diveId,
    required domain.DiveTank tank,
  }) async {
    final index = computerTankIndex(tank);
    if (index == null) return null;
    try {
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId) & t.rawData.isNotNull())).get();
      final source = _sourceFor(sources, tank);
      if (source == null) return null;
      final vendor = source.descriptorVendor;
      final product = source.descriptorProduct;
      final model = source.descriptorModel;
      if (vendor == null || product == null || model == null) return null;
      final parsed = await parseFn(vendor, product, model, source.rawData!);
      final cylinder = resolveParsedTanks(
        parsed,
        vendor: vendor,
      ).where((t) => t.index == index).firstOrNull;
      if (cylinder == null) return null;
      return domain.GasMix(o2: cylinder.o2Percent, he: cylinder.hePercent);
    } catch (e, stackTrace) {
      // A read or parse that fails means the mix cannot be known: the note
      // shows nothing rather than an error under the gas fields.
      _log.error(
        'Failed to read the recorded mix for tank ${tank.id} on dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// The download [tank] came from: the source it names, else one from its
  /// computer (the primary first), else the dive's primary source, which a
  /// row naming no source belongs to.
  static DiveDataSourcesData? _sourceFor(
    List<DiveDataSourcesData> sources,
    domain.DiveTank tank,
  ) {
    if (tank.sourceId case final sourceId?) {
      return sources.where((s) => s.id == sourceId).firstOrNull;
    }
    final candidates = tank.computerId == null
        ? sources
        : sources.where((s) => s.computerId == tank.computerId).toList();
    return candidates.where((s) => s.isPrimary).firstOrNull ??
        (candidates.length == 1 ? candidates.single : null);
  }
}
