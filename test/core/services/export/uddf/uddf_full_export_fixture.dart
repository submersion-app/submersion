import 'dart:typed_data';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/tank_pressure_export_fixtures.dart';

/// A small logbook that reaches every part of the full UDDF backup a dive's
/// heavy data feeds (issue #4249): the samples, the O2 cells the owner block
/// declares from them, the computer tissue block, the tank pressure series
/// and source profiles beside `<datasources>`, and the dumps in
/// `<divecomputercontrol>`.
///
/// The dives are newest first and each day's dives sit together, the order
/// `DiveRepository.getAllDives` returns them in.
class UddfFullExportFixture {
  UddfFullExportFixture._();

  static final owner = Diver(
    id: 'me',
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  static const site = DiveSite(id: 'site-1', name: 'Blue Hole');

  static const equipment = [
    EquipmentItem(
      id: 'reg-1',
      name: 'Regulator',
      type: EquipmentType.regulator,
    ),
  ];

  static const _tissue = ComputerTissueSnapshot(
    end: ComputerTissueState(n2Bar: [1.52, 1.21], gf99Percent: 37),
  );

  static const _tankA = DiveTank(
    id: 'tank-a',
    gasMix: GasMix(o2: 32),
    sourceId: 'src-c1',
    computerId: 'comp-1',
  );
  static const _tankB = DiveTank(
    id: 'tank-b',
    gasMix: GasMix(o2: 50),
    order: 1,
    sourceId: 'src-c2',
    computerId: 'comp-2',
  );

  /// [count] samples a second apart, every field the backup writes for a
  /// sample that is not about cells or tissue.
  static List<DiveProfilePoint> samples(int count, {double scale = 1}) => [
    for (var i = 0; i < count; i++)
      DiveProfilePoint(
        timestamp: i * 10,
        depth: (i % 7) * 1.5 * scale,
        temperature: 20 + (i % 3) * 0.5,
      ),
  ];

  /// Reads a run of [leanDives] the way the export's database loader does:
  /// each dive with its profile, and the run's pressures and sources only.
  /// [reads] records each run's ids.
  static UddfDiveChunkLoader recordingLoader(List<List<String>> reads) =>
      (lean) async {
        reads.add([for (final dive in lean) dive.id]);
        final ids = {for (final dive in lean) dive.id};
        return UddfDiveChunk(
          dives: [
            for (final dive in lean) dives.singleWhere((d) => d.id == dive.id),
          ],
          tankPressures: {
            for (final entry in tankPressures.entries)
              if (ids.contains(entry.key)) entry.key: entry.value,
          },
          sources: [
            for (final source in sources)
              if (ids.contains(source.diveId)) source,
          ],
        );
      };

  /// [recordingLoader] for a test that does not look at the reads.
  static Future<UddfDiveChunk> loadChunk(List<Dive> lean) =>
      recordingLoader([])(lean);

  /// The logbook's dives as `getAllDives` lists them: no profile on any.
  static List<Dive> get leanDives => [
    for (final dive in dives) dive.copyWith(profile: const []),
  ];

  /// The logbook's dives with their recorded profiles attached.
  static final List<Dive> dives = [
    // Two dives on the newest day.
    Dive(
      id: 'dive-d',
      diveNumber: 4,
      dateTime: DateTime.utc(2026, 3, 4, 14),
      site: site,
      diveComputerModel: 'Perdix',
      diveComputerSerial: 'P-1',
      tanks: const [_tankA, _tankB],
      profile: samples(6),
    ),
    Dive(
      id: 'dive-c',
      diveNumber: 3,
      dateTime: DateTime.utc(2026, 3, 4, 9),
      site: site,
      diveComputerModel: 'Perdix',
      diveComputerSerial: 'P-1',
      computerTissue: _tissue,
      profile: [
        const DiveProfilePoint(timestamp: 0, depth: 0.5, n2Load: 12),
        const DiveProfilePoint(timestamp: 60, depth: 12),
        const DiveProfilePoint(timestamp: 120, depth: 18, n2Load: 34),
      ],
    ),
    // A rebreather dive with three cells.
    Dive(
      id: 'dive-b',
      diveNumber: 2,
      dateTime: DateTime.utc(2026, 3, 2, 10),
      diveComputerModel: 'Petrel',
      tanks: const [DiveTank(id: 'tank-c', gasMix: GasMix(o2: 21))],
      profile: [
        for (var i = 0; i < 4; i++)
          DiveProfilePoint(
            timestamp: i * 20,
            depth: 5.0 + i,
            o2Sensor1: 1.1,
            o2Sensor2: 1.2,
            o2SensorMv3: 40 + i,
          ),
      ],
    ),
    // A dive with no recorded samples at all.
    Dive(id: 'dive-a', diveNumber: 1, dateTime: DateTime.utc(2026, 3, 1, 8)),
  ];

  static final tankPressures = <String, DiveTankPressureExport>{
    // Two computers recorded tank A: every series goes in the block.
    'dive-d': DiveTankPressureExport(
      primarySourceId: 'src-c1',
      series: [
        testTankSeries(
          's-1',
          diveId: 'dive-d',
          tankId: 'tank-a',
          sourceId: 'src-c1',
          computerId: 'comp-1',
          samples: [(0, 200), (10, 195), (20, 190)],
        ),
        testTankSeries(
          's-2',
          diveId: 'dive-d',
          tankId: 'tank-a',
          sourceId: 'src-c2',
          computerId: 'comp-2',
          samples: [(1, 201.5), (11, 196.5)],
        ),
      ],
    ),
    // One reading between samples: the waypoints cannot hold it, so the
    // series is written beside them.
    'dive-b': DiveTankPressureExport(
      series: [
        testTankSeries(
          's-3',
          diveId: 'dive-b',
          tankId: 'tank-c',
          samples: [(0, 210), (30, 205)],
        ),
      ],
    ),
  };

  static DiveSourceExport _source(
    String id,
    String diveId,
    int ordinal, {
    bool primary = false,
    Uint8List? rawData,
    List<SourceSeriesExport> profileSeries = const [],
  }) => DiveSourceExport(
    id: id,
    diveId: diveId,
    ordinal: ordinal,
    isPrimary: primary,
    importedAt: DateTime.utc(2026, 3, 5, 12),
    createdAt: DateTime.utc(2026, 3, 5, 12),
    rawData: rawData,
    computerModel: 'Perdix',
    computerSerial: 'P-1',
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 5,
    sourceFileName: '$id.bin',
    maxDepth: 18.5,
    profileSeries: profileSeries,
  );

  static final sources = [
    _source(
      'src-c1',
      'dive-d',
      0,
      primary: true,
      rawData: Uint8List.fromList(List<int>.generate(64, (i) => i)),
      profileSeries: [
        SourceSeriesExport(
          blob: Uint8List.fromList(const [1, 2, 3, 4]),
          isPrimary: true,
          sourceId: 'src-c1',
          computerId: 'comp-1',
        ),
      ],
    ),
    _source(
      'src-c2',
      'dive-d',
      1,
      profileSeries: [
        SourceSeriesExport(
          blob: Uint8List.fromList(const [5, 6, 7]),
          isPrimary: false,
          sourceId: 'src-c2',
          computerId: 'comp-2',
        ),
      ],
    ),
    _source(
      'src-b',
      'dive-b',
      0,
      primary: true,
      rawData: Uint8List.fromList(List<int>.generate(32, (i) => 255 - i)),
    ),
  ];
}
