import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/shared/export_text_spool.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_stream_writer.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/core/services/export/uddf/uddf_shared_dive_writer.dart';
import 'package:submersion/core/services/export/uddf/uddf_streamed_sections.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_gas_mix_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_site_classification_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_site_feature_writers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Handles simple UDDF export of dives with optional site data.
class UddfExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  /// The day a dive's `<repetitiongroup>` is for.
  String _dayOf(Dive dive) => _dateFormat.format(dive.dateTime);

  /// Writes the dives-only document for [dives] into [out].
  ///
  /// Each run of [chunkSize] dives gets its samples, tank pressures and data
  /// sources from [loadDiveChunk] as the run is written, and lets them go
  /// after, as the full backup does (issue #4249); [spools] holds the
  /// sections they fill until the rest of the document is known.
  Future<void> _writeDives(
    List<Dive> dives, {
    required ExportTextSink out,
    required ExportSpoolStore spools,
    required UddfDiveChunkLoader loadDiveChunk,
    required int chunkSize,
    List<DiveSite>? sites,
    CertificationCatalog? certificationCatalog,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    final sections = UddfStreamedSections(spools);

    // Participants (issue #1796): only the people on the exported dives,
    // in dive order, and nobody at all when the user left them out of a
    // shared file.
    final diveBuddies = <String, List<BuddyWithRole>>{
      if (options.includeParticipants)
        for (final dive in dives)
          if (extras.diveBuddies[dive.id] case final rows? when rows.isNotEmpty)
            dive.id: rows,
    };
    final people = <String, Buddy>{
      for (final rows in diveBuddies.values)
        for (final row in rows) row.buddy.id: row.buddy,
    }.values.toList(growable: false);
    // A <buddyroles> row or a dive's <diverrole> naming a custom role is
    // dropped on import unless the file also defines that role. Only the
    // diver's own roles are defined: a synthetic role (an id with no row, or
    // another diver's role) has nothing but its raw id for a name. The
    // diver's own role is not a participant, so, like <diverrole> itself, it
    // is defined whether or not participants are included.
    final ownRoles = {for (final role in extras.diveRoles) role.id: role};
    final customRoles = <String, DiveRole>{
      for (final id in [
        for (final rows in diveBuddies.values)
          for (final row in rows) ...row.roleIds,
        for (final dive in dives) ...dive.diverRoleIds,
      ])
        if (ownRoles[id] case final role?
            when !DiveRole.builtInIds.contains(id))
          id: role,
    }.values.toList(growable: false);

    // Gear (issue #1718): each distinct item on the exported dives, the
    // assembly rows between two of them, and the dives' computers. None of
    // it when the user left gear out.
    final items = <String, EquipmentItem>{
      if (options.includeGear)
        for (final dive in dives)
          for (final link in dive.gear) link.item.id: link.item,
    }.values.toList(growable: false);
    final itemIds = {for (final item in items) item.id};
    final components = [
      for (final c in extras.components)
        if (itemIds.contains(c.parentEquipmentId) &&
            itemIds.contains(c.componentEquipmentId))
          c,
    ];
    final computerIds = options.includeGear
        ? UddfGearWriters.computerIds(dives)
        : const <String>{};
    // The dives go first: the O2 cells their samples name are declared under
    // the owner however the gear option is set, since they are no gear, only
    // what each reading names. The raw data box keeps or drops only the
    // original bytes; the source rows go either way, since without them a
    // restore keeps one computer (issue #4180).
    final o2CellCount =
        await UddfDiveStreamWriter(
          sections: sections,
          dayOf: _dayOf,
          includeRawData: options.includeRawData,
          // A dump links only to a computer the owner block declares, which
          // it does only when gear is included.
          declaredComputerIds: computerIds,
          // The computers are gear: a share without gear names none.
          includeSourceIdentity: options.includeGear,
          writeDive: (builder, dive, chunk, sources) =>
              UddfSharedDiveWriter.write(
                builder,
                dive,
                options: options,
                buddies: diveBuddies[dive.id] ?? const [],
                tankPressures: chunk.tankPressures[dive.id]?.displayedByTank,
                gasSwitches: extras.diveGasSwitches[dive.id] ?? const [],
                sources: sources,
              ),
        ).write(
          uddfDiveWriteOrder(dives, _dayOf),
          loadChunk: loadDiveChunk,
          chunkSize: chunkSize,
        );
    // Provenance may name only what this file declares: it shares no
    // equipment sets, and a parent assembly counts only when it is itself one
    // of the exported items. A row left with neither is plain gear, which the
    // gear links section skips.
    final gearLinkDives = [
      if (options.includeGear)
        for (final dive in dives)
          dive.copyWith(
            gear: [
              for (final link in dive.gear)
                GearLink(
                  item: link.item,
                  viaEquipmentId: itemIds.contains(link.viaEquipmentId)
                      ? link.viaEquipmentId
                      : null,
                ),
            ],
          ),
    ];

    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'uddf',
      attributes: {
        'version': '3.2.0',
        'xmlns': 'http://www.streit.cc/uddf/3.2/',
      },
      nest: () {
        // Generator info
        builder.element(
          'generator',
          nest: () {
            builder.element('name', nest: 'Submersion');
            builder.element('version', nest: '0.1.0');
            builder.element('datetime', nest: DateTime.now().toIso8601String());
            builder.element(
              'manufacturer',
              nest: () {
                builder.element('name', nest: 'Submersion App');
              },
            );
          },
        );

        // Diver section: an id-only owner hosting the computer and O2 cell
        // declarations, then the participants. Both trimmed, because this
        // file is shared with other people.
        if (computerIds.isNotEmpty || o2CellCount > 0 || people.isNotEmpty) {
          builder.element(
            'diver',
            nest: () {
              if (computerIds.isNotEmpty || o2CellCount > 0) {
                UddfGearWriters.writeIdOnlyOwner(
                  builder,
                  options.includeGear ? dives : const [],
                  o2CellCount: o2CellCount,
                );
              }
              UddfParticipantWriters.writeBuddyDeclarations(
                builder,
                people,
                trimmed: true,
                certificationCatalog: certificationCatalog,
              );
            },
          );
        }

        // Dive sites
        if (sites != null || dives.any((d) => d.site != null)) {
          builder.element(
            'divesite',
            nest: () {
              final allSites =
                  sites ??
                  dives
                      .map((d) => d.site)
                      .whereType<DiveSite>()
                      .toSet()
                      .toList();
              for (final site in allSites) {
                builder.element(
                  'site',
                  attributes: {'id': 'site_${site.id}'},
                  nest: () {
                    builder.element('name', nest: site.name);
                    if (site.location != null) {
                      builder.element(
                        'geography',
                        nest: () {
                          builder.element(
                            'latitude',
                            nest: site.location!.latitude.toString(),
                          );
                          builder.element(
                            'longitude',
                            nest: site.location!.longitude.toString(),
                          );
                        },
                      );
                    }
                    if (site.country != null) {
                      builder.element('country', nest: site.country);
                    }
                    if (site.region != null) {
                      builder.element('state', nest: site.region);
                    }
                    if (site.maxDepth != null) {
                      builder.element(
                        'maximumdepth',
                        nest: site.maxDepth.toString(),
                      );
                    }
                    if (site.rating != null) {
                      builder.element(
                        'siterating',
                        nest: site.rating.toString(),
                      );
                    }
                    if (site.description.isNotEmpty) {
                      builder.element('notes', nest: site.description);
                    }
                    if (site.notes.isNotEmpty &&
                        site.notes != site.description) {
                      builder.element('sitenotesadditional', nest: site.notes);
                    }
                    // Shared with the full export's site builder (#1765).
                    UddfSiteClassificationWriters.writeSiteRefs(
                      builder,
                      siteTypeIds:
                          extras.siteTypeIdsBySite[site.id] ?? const [],
                      tagIds: extras.siteTagIdsBySite[site.id] ?? const [],
                    );
                    // Shared with it too (#2200), so the two site builders
                    // cannot drift apart over features either.
                    UddfSiteFeatureWriters.writeSiteFeatures(
                      builder,
                      extras.siteFeaturesBySite[site.id] ?? const [],
                    );
                  },
                );
              }
            },
          );
        }

        // Gas definitions
        UddfGasMixWriters.writeGasDefinitions(builder, dives);

        // Profile data (repetition groups and dives), already written a run
        // at a time. Written even with no dives, as it always was.
        sections.writeSlot(
          builder,
          UddfStreamedSections.profileData,
          evenIfEmpty: true,
        );

        // Every private section in one top level <applicationdata>
        // <submersion>, as the full export writes it: the importer reads
        // only the first top level block for everything except data
        // sources. The per dive inline <applicationdata> for custom fields
        // is a different element in a different position and is untouched.
        UddfExportBuilders.buildApplicationData(
          builder,
          equipment: items,
          omitPurchaseDetails: true,
          components: components,
          gearLinkDives: gearLinkDives,
          visibilityRangeDives: dives,
          diveBuddies: diveBuddies,
          customDiveRoles: customRoles,
          streamed: sections,
          // The definitions the sites' type and tag references need.
          tags: extras.siteTags,
          customSiteTypes: extras.customSiteTypes,
        );

        // Last section, per the UDDF specification.
        sections.writeSlot(builder, UddfStreamedSections.diveComputerControl);
      },
    );

    await sections.writeDocument(
      builder.buildDocument().toXmlString(pretty: true, indent: '  '),
      out,
    );
  }

  /// [_writeDives] for one of the public methods, reading each run's
  /// recordings through [loadDiveChunk], or from [dives] (with whatever
  /// profile each carries), [diveTankPressures] and [dataSources] without
  /// one.
  Future<void> Function(ExportTextSink, ExportSpoolStore) _writer(
    List<Dive> dives, {
    required UddfDiveChunkLoader? loadDiveChunk,
    required int chunkSize,
    required Map<String, DiveTankPressureExport>? diveTankPressures,
    required List<DiveSourceExport>? dataSources,
    required List<DiveSite>? sites,
    required CertificationCatalog? certificationCatalog,
    required UddfDivesExtras extras,
    required UddfExportOptions options,
  }) =>
      (out, spools) => _writeDives(
        dives,
        out: out,
        spools: spools,
        loadDiveChunk:
            loadDiveChunk ??
            inMemoryUddfDiveChunks(
              tankPressures: diveTankPressures ?? const {},
              sources: dataSources ?? const [],
            ),
        chunkSize: chunkSize,
        sites: sites,
        certificationCatalog: certificationCatalog,
        extras: extras,
        options: options,
      );

  /// Build the UDDF document for [dives] without delivering it anywhere.
  ///
  /// [loadDiveChunk] reads each run's samples, tank pressures and sources;
  /// without it they come from [dives], [diveTankPressures] and
  /// [dataSources].
  Future<String> generateDivesUddfContent(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, DiveTankPressureExport>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    CertificationCatalog? certificationCatalog,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
    UddfDiveChunkLoader? loadDiveChunk,
    int chunkSize = kUddfProfileChunkSize,
  }) => buildTextExport(
    _fileName(),
    _writer(
      dives,
      loadDiveChunk: loadDiveChunk,
      chunkSize: chunkSize,
      diveTankPressures: diveTankPressures,
      dataSources: dataSources,
      sites: sites,
      certificationCatalog: certificationCatalog,
      extras: extras,
      options: options,
    ),
    inMemory: (xml) async => xml,
    onFile: (file) => file.readAsString(),
  );

  String _fileName() =>
      'dives_export_${_dateFormat.format(DateTime.now())}.uddf';

  /// Export [dives] to UDDF and offer the file via the system share sheet.
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, DiveTankPressureExport>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    CertificationCatalog? certificationCatalog,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
    UddfDiveChunkLoader? loadDiveChunk,
    int chunkSize = kUddfProfileChunkSize,
  }) {
    final fileName = _fileName();
    return buildTextExport(
      fileName,
      _writer(
        dives,
        loadDiveChunk: loadDiveChunk,
        chunkSize: chunkSize,
        diveTankPressures: diveTankPressures,
        dataSources: dataSources,
        sites: sites,
        certificationCatalog: certificationCatalog,
        extras: extras,
        options: options,
      ),
      inMemory: (xml) => saveAndShareFile(xml, fileName, 'application/xml'),
      onFile: (file) =>
          saveAndShareExportFile(file, fileName, 'application/xml'),
    );
  }

  /// Export [dives] to UDDF and save to a user-selected location.
  ///
  /// Returns the chosen path, or null if the save dialog was cancelled.
  Future<String?> saveDivesToUddfFile(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, DiveTankPressureExport>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    CertificationCatalog? certificationCatalog,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
    UddfDiveChunkLoader? loadDiveChunk,
    int chunkSize = kUddfProfileChunkSize,
  }) {
    final fileName = _fileName();

    // The save dialog writes the bytes itself and takes no stream, so the
    // finished file is read back once; nothing else of the build is held.
    Future<String?> save(Uint8List bytes) async {
      DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.export);
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save UDDF File',
        fileName: fileName,
        type: FileType.custom,
        bytes: bytes,
        mimeType: 'application/xml',
      );
      if (result == null) return null;
      return savedFileLocation(result);
    }

    return buildTextExport(
      fileName,
      _writer(
        dives,
        loadDiveChunk: loadDiveChunk,
        chunkSize: chunkSize,
        diveTankPressures: diveTankPressures,
        dataSources: dataSources,
        sites: sites,
        certificationCatalog: certificationCatalog,
        extras: extras,
        options: options,
      ),
      inMemory: (xml) => save(Uint8List.fromList(utf8.encode(xml))),
      onFile: (file) async => save(await file.readAsBytes()),
    );
  }
}
