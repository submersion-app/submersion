import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/models/currency_backup_data.dart';
import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/shared/export_text_spool.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_stream_writer.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_profiles.dart';
import 'package:submersion/core/services/export/uddf/uddf_gas_mix_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_streamed_sections.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Handles comprehensive UDDF export of all application data.
class UddfFullExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  /// The day a dive's `<repetitiongroup>` is for.
  String _dayOf(Dive dive) => _dateFormat.format(dive.dateTime);

  /// Writes the full backup into [out]: every dive, site, piece of gear,
  /// buddy, certification, dive center, species, service record, setting,
  /// trip, tag, dive type, dive computer, equipment set and course.
  ///
  /// [dives] is the dive list; each run of [chunkSize] of them gets its
  /// samples, tank pressures and data sources from [loadDiveChunk] as the
  /// run is written, and lets them go after (issue #4249). Everything else
  /// is small, so it is built as one XML tree, with a slot for each section
  /// the dives' recordings fill; see [UddfStreamedSections]. [spools] holds
  /// those sections until the tree around them is known.
  Future<void> _writeAllData({
    required ExportTextSink out,
    required ExportSpoolStore spools,
    required List<Dive> dives,
    required UddfDiveChunkLoader loadDiveChunk,
    required int chunkSize,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    CurrencyBackupData currency = const CurrencyBackupData(),
    CertificationCatalog? certificationCatalog,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    List<EquipmentObservation>? observations,
    List<CylinderFill>? fills,
    List<ServiceKind>? serviceKinds,
    Map<String, List<ServiceSchedule>> serviceSchedulesByItem = const {},
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    // Site types and site tags (issue #1765): the custom type definitions,
    // and each exported site's type slugs and tag ids.
    List<SiteTypeEntity>? customSiteTypes,
    Map<String, List<String>> siteTypeIdsBySite = const {},
    Map<String, List<String>> siteTagIdsBySite = const {},
    // Each exported site's own features (issue #2200).
    Map<String, List<SiteFeature>> siteFeaturesBySite = const {},
    // Each exported item's tag ids (issue #1942).
    Map<String, List<String>> equipmentTagIdsByItem = const {},
    List<DiveRole>? customDiveRoles,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<EquipmentComponent>? components,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    final sections = UddfStreamedSections(spools);

    // Which computers this document declares as <divecomputer id=...>: the
    // owner block below declares them from the same dives. Empty without an
    // owner, since the declarations live under it. A dump may only link to
    // an id in here.
    final declaredComputerIds = owner == null
        ? const <String>{}
        : UddfGearWriters.computerIds(dives);

    // The dives go first, so the O2 cells their samples name (issue #4178)
    // are known before the owner block that declares them is built. The raw
    // data box keeps or drops only the original bytes; the source rows go
    // either way, since without them a restore keeps one computer (#4180).
    final o2CellCount =
        await UddfDiveStreamWriter(
          sections: sections,
          dayOf: _dayOf,
          includeRawData: options.includeRawData,
          declaredComputerIds: declaredComputerIds,
          writeDive: (builder, dive, chunk, sources) =>
              UddfExportBuilders.buildDiveElement(
                builder,
                dive,
                buddies,
                diveBuddies?[dive.id] ?? const [],
                diveTags?[dive.id] ?? const [],
                diveProfileEvents?[dive.id] ?? const [],
                diveWeights?[dive.id] ?? const [],
                trips,
                diveGasSwitches?[dive.id] ?? const [],
                tankPressures: chunk.tankPressures[dive.id]?.displayedByTank,
                sources: sources,
              ),
        ).write(
          uddfDiveWriteOrder(dives, _dayOf),
          loadChunk: loadDiveChunk,
          chunkSize: chunkSize,
        );

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
            builder.element('version', nest: '1.0.0');
            builder.element('datetime', nest: DateTime.now().toIso8601String());
            builder.element(
              'manufacturer',
              nest: () {
                builder.element('name', nest: 'Submersion App');
              },
            );
          },
        );

        // Diver section with owner and buddy records (UDDF standard)
        if (owner != null ||
            o2CellCount > 0 ||
            (buddies != null && buddies.isNotEmpty)) {
          builder.element(
            'diver',
            nest: () {
              // Export owner (current diver) - UDDF standard <owner> element
              if (owner != null) {
                builder.element(
                  'owner',
                  attributes: {'id': 'owner_${owner.id}'},
                  nest: () {
                    builder.element(
                      'personal',
                      nest: () {
                        final nameParts = owner.name.split(' ');
                        builder.element('firstname', nest: nameParts.first);
                        if (nameParts.length > 1) {
                          builder.element(
                            'lastname',
                            nest: nameParts.sublist(1).join(' '),
                          );
                        }
                        if (owner.email != null && owner.email!.isNotEmpty) {
                          builder.element('email', nest: owner.email);
                        }
                        if (owner.phone != null && owner.phone!.isNotEmpty) {
                          builder.element('phone', nest: owner.phone);
                        }
                      },
                    );
                    // Export dive computers used in equipment section
                    UddfGearWriters.writeOwnerEquipment(
                      builder,
                      dives,
                      o2CellCount: o2CellCount,
                    );
                    // Certifications will be added in applicationdata section
                  },
                );
              } else if (o2CellCount > 0) {
                // No diver, but the cells still need their declaration.
                UddfGearWriters.writeIdOnlyOwner(
                  builder,
                  const [],
                  o2CellCount: o2CellCount,
                );
              }

              // Export buddies
              if (buddies != null) {
                UddfParticipantWriters.writeBuddyDeclarations(
                  builder,
                  buddies,
                  certificationCatalog: certificationCatalog,
                );
              }
            },
          );
        }

        // Dive sites
        final allSites =
            sites ??
            dives.map((d) => d.site).whereType<DiveSite>().toSet().toList();
        if (allSites.isNotEmpty) {
          builder.element(
            'divesite',
            nest: () {
              for (final site in allSites) {
                UddfExportBuilders.buildSiteElement(
                  builder,
                  site,
                  siteTypeIds: siteTypeIdsBySite[site.id] ?? const [],
                  tagIds: siteTagIdsBySite[site.id] ?? const [],
                  siteFeatures: siteFeaturesBySite[site.id] ?? const [],
                );
              }
            },
          );
        }

        // Dive trips (UDDF standard section)
        if (trips != null && trips.isNotEmpty) {
          for (final trip in trips) {
            builder.element(
              'divetrip',
              attributes: {'id': 'trip_${trip.id}'},
              nest: () {
                builder.element('name', nest: trip.name);
                builder.element(
                  'dateoftrip',
                  nest: () {
                    builder.element(
                      'startdate',
                      nest: () {
                        builder.element(
                          'datetime',
                          nest: trip.startDate.toIso8601String(),
                        );
                      },
                    );
                    builder.element(
                      'enddate',
                      nest: () {
                        builder.element(
                          'datetime',
                          nest: trip.endDate.toIso8601String(),
                        );
                      },
                    );
                  },
                );
                if (trip.location != null && trip.location!.isNotEmpty) {
                  builder.element(
                    'geography',
                    nest: () {
                      builder.element('location', nest: trip.location);
                    },
                  );
                }
                if (trip.notes.isNotEmpty) {
                  builder.element('notes', nest: trip.notes);
                }
              },
            );
          }
        }

        // Gas definitions
        UddfGasMixWriters.writeGasDefinitions(builder, dives);

        // Deco models (gradient factors)
        final uniqueGFs = <String, Map<String, int>>{};
        for (final dive in dives) {
          if (dive.gradientFactorLow != null &&
              dive.gradientFactorHigh != null) {
            final gfId =
                'gf_${dive.gradientFactorLow}_${dive.gradientFactorHigh}';
            uniqueGFs[gfId] = {
              'low': dive.gradientFactorLow!,
              'high': dive.gradientFactorHigh!,
            };
          }
        }
        if (uniqueGFs.isNotEmpty) {
          builder.element(
            'decomodel',
            nest: () {
              for (final entry in uniqueGFs.entries) {
                builder.element(
                  'buehlmann',
                  attributes: {'id': entry.key},
                  nest: () {
                    builder.element(
                      'gradientfactorlow',
                      nest: entry.value['low'].toString(),
                    );
                    builder.element(
                      'gradientfactorhigh',
                      nest: entry.value['high'].toString(),
                    );
                  },
                );
              }
            },
          );
        }

        // Profile data (dives), already written a run at a time.
        sections.writeSlot(builder, UddfStreamedSections.profileData);

        // Application data section for all non-standard data
        UddfExportBuilders.buildApplicationData(
          builder,
          backup: true,
          equipment: equipment,
          equipmentTagIdsByItem: equipmentTagIdsByItem,
          certifications: certifications,
          currency: currency,
          certificationCatalog: certificationCatalog,
          diveCenters: diveCenters,
          species: species,
          serviceRecords: serviceRecords,
          observations: observations,
          fills: fills,
          serviceKinds: serviceKinds,
          serviceSchedulesByItem: serviceSchedulesByItem,
          settings: settings,
          owner: owner,
          tags: tags,
          customDiveTypes: customDiveTypes,
          customSiteTypes: customSiteTypes,
          customDiveRoles: customDiveRoles,
          diveComputers: diveComputers,
          equipmentSets: equipmentSets,
          trips: trips,
          courses: courses,
          components: components,
          gearLinkDives: dives,
          diveBuddies: diveBuddies,
          visibilityRangeDives: dives,
          streamed: sections,
        );

        // The UDDF specification places <divecomputercontrol> last, so this
        // stays the final child of <uddf>.
        sections.writeSlot(builder, UddfStreamedSections.diveComputerControl);
      },
    );

    await sections.writeDocument(
      builder.buildDocument().toXmlString(pretty: true, indent: '  '),
      out,
    );
  }

  String get _fileName =>
      'submersion_backup_${_dateFormat.format(DateTime.now())}.uddf';

  /// The document this service would write, without delivering it anywhere.
  ///
  /// Visible for testing: the two public methods below both hand their XML
  /// straight to the filesystem or the share sheet, so this is how a test
  /// inspects the document itself.
  Future<String> generateAllDataXmlForTest({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<Tag>? tags,
    List<SiteTypeEntity>? customSiteTypes,
    Map<String, List<String>> siteTypeIdsBySite = const {},
    Map<String, List<String>> siteTagIdsBySite = const {},
    // Each exported site's own features (issue #2200).
    Map<String, List<SiteFeature>> siteFeaturesBySite = const {},
    // Each exported item's tag ids (issue #1942).
    Map<String, List<String>> equipmentTagIdsByItem = const {},
    Diver? owner,
    List<Buddy>? buddies,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    List<DiveRole>? customDiveRoles,
    List<EquipmentItem>? equipment,
    List<EquipmentSet>? equipmentSets,
    List<EquipmentComponent>? components,
    List<DiveSourceExport>? dataSources,
    List<EquipmentObservation>? observations,
    List<CylinderFill>? fills,
    List<ServiceKind>? serviceKinds,
    Map<String, List<ServiceSchedule>> serviceSchedulesByItem = const {},
    List<ServiceRecord>? serviceRecords,
    Map<String, List<Tag>>? diveTags,
    Map<String, List<DiveWeight>>? diveWeights,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, DiveTankPressureExport>? diveTankPressures,
    // A backup's certifications and the catalog naming their custom
    // agencies and levels (issue #690).
    List<Certification>? certifications,
    CertificationCatalog? certificationCatalog,
    // A backup's courses and their links (issue #2515).
    List<Course>? courses,
    UddfExportOptions options = const UddfExportOptions(),
    // Read each run's heavy data through this instead of from [dives],
    // [diveTankPressures] and [dataSources], as the settings export does.
    UddfDiveChunkLoader? loadDiveChunk,
    int chunkSize = kUddfProfileChunkSize,
  }) => buildTextExport(
    _fileName,
    (out, spools) => _writeAllData(
      out: out,
      spools: spools,
      loadDiveChunk:
          loadDiveChunk ??
          inMemoryUddfDiveChunks(
            tankPressures: diveTankPressures ?? const {},
            sources: dataSources ?? const [],
          ),
      chunkSize: chunkSize,
      dives: dives,
      certifications: certifications,
      courses: courses,
      certificationCatalog: certificationCatalog,
      sites: sites,
      tags: tags,
      customSiteTypes: customSiteTypes,
      siteTypeIdsBySite: siteTypeIdsBySite,
      siteTagIdsBySite: siteTagIdsBySite,
      siteFeaturesBySite: siteFeaturesBySite,
      equipmentTagIdsByItem: equipmentTagIdsByItem,
      owner: owner,
      buddies: buddies,
      diveBuddies: diveBuddies,
      customDiveRoles: customDiveRoles,
      equipment: equipment,
      equipmentSets: equipmentSets,
      components: components,
      observations: observations,
      fills: fills,
      serviceKinds: serviceKinds,
      serviceSchedulesByItem: serviceSchedulesByItem,
      serviceRecords: serviceRecords,
      diveTags: diveTags,
      diveWeights: diveWeights,
      diveGasSwitches: diveGasSwitches,
      diveProfileEvents: diveProfileEvents,
      options: options,
    ),
    inMemory: (xml) async => xml,
    onFile: (file) => file.readAsString(),
  );

  /// Export ALL application data to UDDF and share via the system share sheet.
  /// Returns the share result path.
  Future<String> exportAllDataToUddf({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    CurrencyBackupData currency = const CurrencyBackupData(),
    CertificationCatalog? certificationCatalog,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    List<EquipmentObservation>? observations,
    List<CylinderFill>? fills,
    List<ServiceKind>? serviceKinds,
    Map<String, List<ServiceSchedule>> serviceSchedulesByItem = const {},
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    // Site types and site tags (issue #1765): the custom type definitions,
    // and each exported site's type slugs and tag ids.
    List<SiteTypeEntity>? customSiteTypes,
    Map<String, List<String>> siteTypeIdsBySite = const {},
    Map<String, List<String>> siteTagIdsBySite = const {},
    // Each exported site's own features (issue #2200).
    Map<String, List<SiteFeature>> siteFeaturesBySite = const {},
    // Each exported item's tag ids (issue #1942).
    Map<String, List<String>> equipmentTagIdsByItem = const {},
    List<DiveRole>? customDiveRoles,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<EquipmentComponent>? components,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
    Map<String, DiveTankPressureExport>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
    UddfDiveChunkLoader? loadDiveChunk,
    int chunkSize = kUddfProfileChunkSize,
  }) async {
    Future<void> write(ExportTextSink out, ExportSpoolStore spools) =>
        _writeAllData(
          out: out,
          spools: spools,
          loadDiveChunk:
              loadDiveChunk ??
              inMemoryUddfDiveChunks(
                tankPressures: diveTankPressures ?? const {},
                sources: dataSources ?? const [],
              ),
          chunkSize: chunkSize,
          dives: dives,
          sites: sites,
          equipment: equipment,
          buddies: buddies,
          certifications: certifications,
          currency: currency,
          certificationCatalog: certificationCatalog,
          diveCenters: diveCenters,
          species: species,
          serviceRecords: serviceRecords,
          observations: observations,
          fills: fills,
          serviceKinds: serviceKinds,
          serviceSchedulesByItem: serviceSchedulesByItem,
          settings: settings,
          diveBuddies: diveBuddies,
          owner: owner,
          trips: trips,
          tags: tags,
          diveTags: diveTags,
          customDiveTypes: customDiveTypes,
          customSiteTypes: customSiteTypes,
          siteTypeIdsBySite: siteTypeIdsBySite,
          siteTagIdsBySite: siteTagIdsBySite,
          siteFeaturesBySite: siteFeaturesBySite,
          equipmentTagIdsByItem: equipmentTagIdsByItem,
          customDiveRoles: customDiveRoles,
          diveComputers: diveComputers,
          diveProfileEvents: diveProfileEvents,
          diveWeights: diveWeights,
          equipmentSets: equipmentSets,
          components: components,
          courses: courses,
          diveGasSwitches: diveGasSwitches,
          options: options,
        );
    final fileName = _fileName;
    return buildTextExport(
      fileName,
      write,
      inMemory: (xml) => saveAndShareFile(xml, fileName, 'application/xml'),
      onFile: (file) =>
          saveAndShareExportFile(file, fileName, 'application/xml'),
    );
  }

  /// Export ALL application data to UDDF and save to a user-selected file.
  /// Returns the file path, or null if cancelled.
  Future<String?> saveAllDataToUddfFile({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    CurrencyBackupData currency = const CurrencyBackupData(),
    CertificationCatalog? certificationCatalog,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    List<EquipmentObservation>? observations,
    List<CylinderFill>? fills,
    List<ServiceKind>? serviceKinds,
    Map<String, List<ServiceSchedule>> serviceSchedulesByItem = const {},
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    // Site types and site tags (issue #1765): the custom type definitions,
    // and each exported site's type slugs and tag ids.
    List<SiteTypeEntity>? customSiteTypes,
    Map<String, List<String>> siteTypeIdsBySite = const {},
    Map<String, List<String>> siteTagIdsBySite = const {},
    // Each exported site's own features (issue #2200).
    Map<String, List<SiteFeature>> siteFeaturesBySite = const {},
    // Each exported item's tag ids (issue #1942).
    Map<String, List<String>> equipmentTagIdsByItem = const {},
    List<DiveRole>? customDiveRoles,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<EquipmentComponent>? components,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
    Map<String, DiveTankPressureExport>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
    UddfDiveChunkLoader? loadDiveChunk,
    int chunkSize = kUddfProfileChunkSize,
  }) async {
    Future<void> write(ExportTextSink out, ExportSpoolStore spools) =>
        _writeAllData(
          out: out,
          spools: spools,
          loadDiveChunk:
              loadDiveChunk ??
              inMemoryUddfDiveChunks(
                tankPressures: diveTankPressures ?? const {},
                sources: dataSources ?? const [],
              ),
          chunkSize: chunkSize,
          dives: dives,
          sites: sites,
          equipment: equipment,
          buddies: buddies,
          certifications: certifications,
          currency: currency,
          certificationCatalog: certificationCatalog,
          diveCenters: diveCenters,
          species: species,
          serviceRecords: serviceRecords,
          observations: observations,
          fills: fills,
          serviceKinds: serviceKinds,
          serviceSchedulesByItem: serviceSchedulesByItem,
          settings: settings,
          diveBuddies: diveBuddies,
          owner: owner,
          trips: trips,
          tags: tags,
          diveTags: diveTags,
          customDiveTypes: customDiveTypes,
          customSiteTypes: customSiteTypes,
          siteTypeIdsBySite: siteTypeIdsBySite,
          siteTagIdsBySite: siteTagIdsBySite,
          siteFeaturesBySite: siteFeaturesBySite,
          equipmentTagIdsByItem: equipmentTagIdsByItem,
          customDiveRoles: customDiveRoles,
          diveComputers: diveComputers,
          diveProfileEvents: diveProfileEvents,
          diveWeights: diveWeights,
          equipmentSets: equipmentSets,
          components: components,
          courses: courses,
          diveGasSwitches: diveGasSwitches,
          options: options,
        );
    final fileName = _fileName;

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
      write,
      inMemory: (xml) => save(Uint8List.fromList(utf8.encode(xml))),
      onFile: (file) async => save(await file.readAsBytes()),
    );
  }
}
