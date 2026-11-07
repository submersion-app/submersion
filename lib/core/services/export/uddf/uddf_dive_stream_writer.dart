import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_computer_tissue.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_rebreather_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/core/services/export/uddf/uddf_streamed_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

/// Writes the per-dive sections of a UDDF export into [sections], reading
/// each run of [chunkSize] dives through [loadChunk] and letting it go once
/// its dives are written (issue #4249). Both the full backup and the
/// dives-only export write their dives through this.
///
/// [dives] is the dive list in the order the document holds them (see
/// [uddfDiveWriteOrder]), with no profile attached. For each dive this
/// writes the `<dive>` element [writeDive] builds into `<profiledata>`, a
/// `<repetitiongroup>` per [dayOf], and its entries in the
/// `<applicationdata>` sections that carry its recordings: the computer
/// tissue, the data source rows, the tank and pressure attribution and the
/// source profiles. Its dumps go into `<divecomputercontrol>`, linked to a
/// computer only when [declaredComputerIds] has it. Each of those writers
/// is run for the one dive and its output moved into the spool, so a
/// section's text is the same whether its dives are written together or
/// one at a time.
///
/// A dive's data source rows and dumps are written with the dive, so across
/// dives they follow the document's dive order rather than the order the
/// loader returned them in (from the database, dive id order). A restore
/// keys them by `diveref` and pairs each dive's dumps by ordinal, so that
/// order carries nothing; within a dive they keep the loader's order.
///
/// It yields to the event loop after every dive, so building a long log
/// never holds the isolate for longer than one dive takes.
///
/// Returns how many O2 cells the samples name, which the owner block ahead
/// of all of this declares.
/// Builds [dive]'s `<dive>` element into [builder]. [chunk] is the run the
/// dive came in, with its tank pressures; [sources] are its data source rows.
typedef UddfDiveElementWriter =
    void Function(
      XmlBuilder builder,
      Dive dive,
      UddfDiveChunk chunk,
      List<DiveSourceExport> sources,
    );

class UddfDiveStreamWriter {
  UddfDiveStreamWriter({
    required this.sections,
    required this.dayOf,
    required this.includeRawData,
    required this.declaredComputerIds,
    required this.writeDive,
    this.includeSourceIdentity = true,
  });

  final UddfStreamedSections sections;
  final String Function(Dive dive) dayOf;
  final bool includeRawData;
  final Set<String> declaredComputerIds;

  /// Builds one dive's `<dive>` element into the builder it is given, from
  /// the dive's run and its data source rows.
  final UddfDiveElementWriter writeDive;

  /// Whether each `<source>` names its computer and file; see
  /// [UddfExportBuilders.buildDataSources].
  final bool includeSourceIdentity;

  static const _group = 'repetitiongroup';
  static const _groupDepth = 2;
  static const _diveDepth = 3;

  Future<int> write(
    List<Dive> dives, {
    required UddfDiveChunkLoader loadChunk,
    required int chunkSize,
  }) async {
    if (chunkSize < 1) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be at least 1');
    }
    var o2CellCount = 0;
    String? day;
    for (var start = 0; start < dives.length; start += chunkSize) {
      final run = dives.sublist(
        start,
        math.min(start + chunkSize, dives.length),
      );
      final chunk = await loadChunk(run);
      // A backup that quietly left out a dive is worse than no backup.
      if (!const ListEquality<String>().equals(
        [for (final dive in chunk.dives) dive.id],
        [for (final dive in run) dive.id],
      )) {
        throw StateError(
          'the dive loader returned a different run than it was asked for',
        );
      }
      o2CellCount = math.max(
        o2CellCount,
        UddfRebreatherWriters.cellCount(chunk.dives),
      );
      final encodedById = await _encodeDumps(chunk.sources);
      final sourcesByDive = UddfSourceAttribution.groupByDive(chunk.sources);
      for (final dive in chunk.dives) {
        final diveDay = dayOf(dive);
        if (diveDay != day) {
          if (day != null) _closeGroup();
          sections.addTag(
            UddfStreamedSections.profileData,
            '<$_group>',
            depth: _groupDepth,
          );
          day = diveDay;
        }
        final sources = sourcesByDive[dive.id] ?? const <DiveSourceExport>[];
        _writeDive(dive, chunk, sources);
        _writeApplicationEntries(dive, chunk, sources, encodedById);
        await sections.flush();
        // A timer, not a microtask, so a frame can be drawn in between.
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (day != null) _closeGroup();
    return o2CellCount;
  }

  void _closeGroup() => sections.addTag(
    UddfStreamedSections.profileData,
    '</$_group>',
    depth: _groupDepth,
  );

  /// The original bytes of [sources], encoded, by source id; none when the
  /// export leaves them out. A source mapped to null failed to encode.
  Future<Map<String, String?>> _encodeDumps(
    List<DiveSourceExport> sources,
  ) async {
    if (!includeRawData) return const {};
    final withBytes = [
      for (final source in sources)
        if (source.hasDump) source,
    ];
    final encoded = await UddfDumpCodec.encodeAll([
      for (final source in withBytes) source.rawData!,
    ]);
    return {
      for (var i = 0; i < withBytes.length; i++) withBytes[i].id: encoded[i],
    };
  }

  void _writeDive(
    Dive dive,
    UddfDiveChunk chunk,
    List<DiveSourceExport> sources,
  ) {
    final builder = XmlBuilder();
    writeDive(builder, dive, chunk, sources);
    for (final element
        in builder.buildFragment().children.whereType<XmlElement>()) {
      sections.addElement(
        UddfStreamedSections.profileData,
        element,
        depth: _diveDepth,
      );
    }
  }

  void _writeApplicationEntries(
    Dive dive,
    UddfDiveChunk chunk,
    List<DiveSourceExport> sources,
    Map<String, String?> encodedById,
  ) {
    final builder = XmlBuilder();
    UddfComputerTissue.write(builder, [dive]);
    // The rows of the dive's sources, then which of them recorded each tank,
    // pressure series and depth series: the order the backup writes the
    // blocks in.
    UddfExportBuilders.buildDataSources(
      builder,
      sources,
      encodedById,
      includeIdentity: includeSourceIdentity,
    );
    UddfSourceAttribution.write(
      builder,
      dives: [dive],
      pressures: chunk.tankPressures,
      sources: sources,
    );
    UddfExportBuilders.buildDiveComputerControl(
      builder,
      sources,
      encodedById,
      declaredComputerIds: declaredComputerIds,
    );
    sections.addSectionContents(builder.buildFragment());
  }
}
