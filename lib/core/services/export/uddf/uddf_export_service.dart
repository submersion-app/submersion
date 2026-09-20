import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
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

/// Handles simple UDDF export of dives with optional site data.
class UddfExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Build the UDDF document for [dives] without delivering it anywhere.
  Future<String> generateDivesUddfContent(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    // Encoding happens before the XML build so the builders stay pure
    // synchronous functions, and bzip2 runs on a worker isolate rather than
    // whichever isolate called the export.
    final sources = options.includeRawData
        ? (dataSources ?? const <DiveSourceExport>[])
        : const <DiveSourceExport>[];
    final withBytes = sources.where((s) => s.hasDump).toList(growable: false);
    final encoded = await UddfDumpCodec.encodeAll(
      withBytes.map((s) => s.rawData!).toList(growable: false),
    );
    final encodedById = <String, String?>{
      for (var i = 0; i < withBytes.length; i++) withBytes[i].id: encoded[i],
    };

    // Sample pressures: the export actions load them into the extras; an
    // explicit map is for callers that assemble the document themselves.
    final pressuresByDive = diveTankPressures ?? extras.diveTankPressures;

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
          for (final row in rows) row.role.id,
        for (final dive in dives) ?dive.diverRoleId,
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

        // Diver section: an id-only owner hosting the computer declarations,
        // then the participants. Both trimmed, because this file is shared
        // with other people.
        if (computerIds.isNotEmpty || people.isNotEmpty) {
          builder.element(
            'diver',
            nest: () {
              if (computerIds.isNotEmpty) {
                builder.element(
                  'owner',
                  attributes: {'id': 'owner'},
                  nest: () {
                    UddfGearWriters.writeOwnerComputers(builder, dives);
                  },
                );
              }
              UddfParticipantWriters.writeBuddyDeclarations(
                builder,
                people,
                trimmed: true,
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
        builder.element(
          'gasdefinitions',
          nest: () {
            // Collect all unique gas mixes from dives
            final gasMixes = <String, GasMix>{};
            for (final dive in dives) {
              for (final tank in dive.tanks) {
                final key =
                    'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}';
                gasMixes[key] = tank.gasMix;
              }
            }
            // Add air as default
            gasMixes['mix_21_0'] = const GasMix();

            for (final entry in gasMixes.entries) {
              builder.element(
                'mix',
                attributes: {'id': entry.key},
                nest: () {
                  builder.element('name', nest: entry.value.name);
                  builder.element(
                    'o2',
                    nest: (entry.value.o2 / 100).toString(),
                  );
                  builder.element(
                    'n2',
                    nest: (entry.value.n2 / 100).toString(),
                  );
                  builder.element(
                    'he',
                    nest: (entry.value.he / 100).toString(),
                  );
                },
              );
            }
          },
        );

        // Profile data (repetition groups and dives)
        builder.element(
          'profiledata',
          nest: () {
            // Group dives by date for repetition groups
            final divesByDate = <String, List<Dive>>{};
            for (final dive in dives) {
              final dateKey = _dateFormat.format(dive.dateTime);
              divesByDate.putIfAbsent(dateKey, () => []);
              divesByDate[dateKey]!.add(dive);
            }

            for (final dateEntry in divesByDate.entries) {
              builder.element(
                'repetitiongroup',
                nest: () {
                  for (final dive in dateEntry.value) {
                    builder.element(
                      'dive',
                      attributes: {'id': 'dive_${dive.id}'},
                      nest: () {
                        builder.element(
                          'informationbeforedive',
                          nest: () {
                            builder.element(
                              'datetime',
                              nest: dive.dateTime.toIso8601String(),
                            );
                            if (dive.diveNumber != null) {
                              builder.element(
                                'divenumber',
                                nest: dive.diveNumber.toString(),
                              );
                            }
                            if (dive.airTemp != null) {
                              builder.element(
                                'airtemperature',
                                nest: (dive.airTemp! + 273.15).toString(),
                              ); // Kelvin
                            }
                            if (dive.surfacePressure != null) {
                              // UDDF stores pressure in Pascal (bar * 100000)
                              builder.element(
                                'atmosphericpressure',
                                nest: (dive.surfacePressure! * 100000)
                                    .toString(),
                              );
                            }
                            // Surface interval before dive
                            if (dive.surfaceInterval != null) {
                              builder.element(
                                'surfaceintervalbeforedive',
                                nest: () {
                                  builder.element(
                                    'passedtime',
                                    nest: dive.surfaceInterval!.inSeconds
                                        .toString(),
                                  );
                                },
                              );
                            }
                            if (dive.site != null) {
                              builder.element(
                                'link',
                                attributes: {'ref': 'site_${dive.site!.id}'},
                              );
                            }
                            if (options.includeParticipants) {
                              UddfParticipantWriters.writeLeaders(
                                builder,
                                dive,
                                diveBuddies[dive.id] ?? const [],
                              );
                            }
                            if (dive.diveCenter != null) {
                              builder.element(
                                'link',
                                attributes: {
                                  'ref': 'center_${dive.diveCenter!.id}',
                                },
                              );
                            }
                            // Dive type(s)
                            for (final typeId in dive.diveTypeIds) {
                              builder.element('divetype', nest: typeId);
                            }
                            // Entry method
                            if (dive.effectiveEntryMethod != null) {
                              builder.element(
                                'entrytype',
                                nest: dive.effectiveEntryMethod!.name,
                              );
                            }
                            UddfExportBuilders.buildDiverRole(builder, dive);
                            UddfExportBuilders.buildDiveGpsElements(
                              builder,
                              'entry',
                              dive.entryLocation,
                            );
                            if (options.includeParticipants) {
                              UddfParticipantWriters.writeLinks(
                                builder,
                                diveBuddies[dive.id] ?? const [],
                              );
                            }
                            if (options.includeGear) {
                              UddfGearWriters.writeEquipmentUsed(builder, dive);
                            }
                          },
                        );

                        // Samples: only what was recorded. <samples> is
                        // optional in UDDF 3.2.1, so a dive without a profile
                        // writes none rather than an invented one a restore
                        // would store (issue #1874).
                        if (dive.profile.isNotEmpty) {
                          builder.element(
                            'samples',
                            nest: () {
                              final startMix = UddfExportBuilders.startMixId(
                                dive,
                              );
                              for (final (index, point)
                                  in dive.profile.indexed) {
                                builder.element(
                                  'waypoint',
                                  nest: () {
                                    builder.element(
                                      'divetime',
                                      nest: point.timestamp.toString(),
                                    );
                                    builder.element(
                                      'depth',
                                      nest: point.depth.toString(),
                                    );
                                    // The starting mix rides on the first
                                    // recorded sample, as in the full backup.
                                    if (index == 0) {
                                      builder.element(
                                        'switchmix',
                                        attributes: {'ref': startMix},
                                      );
                                    }
                                    if (point.temperature != null) {
                                      builder.element(
                                        'temperature',
                                        nest: (point.temperature! + 273.15)
                                            .toString(),
                                      ); // Kelvin
                                    }
                                    // Tank pressure from tank_pressure_series,
                                    // naming the <tankdata> declared below.
                                    final divePressures =
                                        pressuresByDive[dive.id];
                                    if (divePressures != null) {
                                      for (final entry
                                          in divePressures.entries) {
                                        final pressure =
                                            UddfExportBuilders.findPressureAtTimestamp(
                                              entry.value,
                                              point.timestamp,
                                            );
                                        if (pressure != null) {
                                          builder.element(
                                            'tankpressure',
                                            attributes: {
                                              'ref': 'tank_${entry.key}',
                                            },
                                            nest: (pressure * 100000)
                                                .toString(),
                                          );
                                        }
                                      }
                                    }
                                  },
                                );
                              }
                            },
                          );
                        }

                        // The dive's cylinders, where the full backup
                        // declares them; their name and transmitter only
                        // travel with the gear.
                        UddfExportBuilders.writeTankData(
                          builder,
                          dive,
                          includeIdentity: options.includeGear,
                        );

                        builder.element(
                          'informationafterdive',
                          nest: () {
                            if (dive.maxDepth != null) {
                              builder.element(
                                'greatestdepth',
                                nest: dive.maxDepth.toString(),
                              );
                            }
                            if (dive.avgDepth != null) {
                              builder.element(
                                'averagedepth',
                                nest: dive.avgDepth.toString(),
                              );
                            }
                            if (dive.bottomTime != null) {
                              builder.element(
                                'diveduration',
                                nest: dive.bottomTime!.inSeconds.toString(),
                              );
                            }
                            if (dive.waterTemp != null) {
                              builder.element(
                                'lowesttemperature',
                                nest: (dive.waterTemp! + 273.15).toString(),
                              ); // Kelvin
                            }
                            if (UddfExportBuilders.visibilityForUddf(dive)
                                case final vis?) {
                              builder.element('visibility', nest: vis);
                            }
                            if (dive.rating != null) {
                              builder.element(
                                'rating',
                                nest: () {
                                  builder.element(
                                    'ratingvalue',
                                    nest: dive.rating.toString(),
                                  );
                                },
                              );
                            }
                            // Conditions
                            if (dive.effectiveWaterType != null) {
                              builder.element(
                                'watertype',
                                nest: dive.effectiveWaterType!.name,
                              );
                            }
                            if (dive.currentDirection != null) {
                              builder.element(
                                'currentdirection',
                                nest: dive.currentDirection!.name,
                              );
                            }
                            if (dive.currentStrength != null) {
                              builder.element(
                                'currentstrength',
                                nest: dive.currentStrength!.name,
                              );
                            }
                            if (dive.swellHeight != null) {
                              builder.element(
                                'swellheight',
                                nest: dive.swellHeight.toString(),
                              );
                            }
                            if (dive.exitMethod != null) {
                              builder.element(
                                'exittype',
                                nest: dive.exitMethod!.name,
                              );
                            }
                            UddfExportBuilders.buildDiveGpsElements(
                              builder,
                              'exit',
                              dive.exitLocation,
                            );
                            // Weight system
                            if (dive.weightAmount != null) {
                              builder.element(
                                'weightused',
                                nest: () {
                                  builder.element(
                                    'amount',
                                    nest: dive.weightAmount.toString(),
                                  );
                                  if (dive.weightType != null) {
                                    builder.element(
                                      'type',
                                      nest: dive.weightType!.name,
                                    );
                                  }
                                },
                              );
                            }
                            // Sightings
                            if (dive.sightings.isNotEmpty) {
                              builder.element(
                                'sightings',
                                nest: () {
                                  for (final sighting in dive.sightings) {
                                    builder.element(
                                      'sighting',
                                      attributes: {
                                        'speciesref':
                                            'species_${sighting.speciesId}',
                                        'count': sighting.count.toString(),
                                      },
                                      nest: () {
                                        if (sighting.notes.isNotEmpty) {
                                          builder.element(
                                            'notes',
                                            nest: sighting.notes,
                                          );
                                        }
                                      },
                                    );
                                  }
                                },
                              );
                            }
                            if (dive.notes.isNotEmpty) {
                              builder.element(
                                'notes',
                                nest: () {
                                  builder.element('para', nest: dive.notes);
                                },
                              );
                            }
                            if (options.includeParticipants) {
                              UddfParticipantWriters.writeInlineBuddies(
                                builder,
                                dive,
                                diveBuddies[dive.id] ?? const [],
                              );
                            }
                            if (dive.customFields.isNotEmpty) {
                              builder.element(
                                'applicationdata',
                                nest: () {
                                  builder.element('name', nest: 'Submersion');
                                  for (final field in dive.customFields) {
                                    builder.element(
                                      'customfield',
                                      attributes: {'key': field.key},
                                      nest: field.value,
                                    );
                                  }
                                },
                              );
                            }
                          },
                        );
                      },
                    );
                  }
                },
              );
            }
          },
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
          diveBuddies: diveBuddies,
          customDiveRoles: customRoles,
          dataSources: sources,
          dataSourceDumps: encodedById,
          // The definitions the sites' type and tag references need.
          tags: extras.siteTags,
          customSiteTypes: extras.customSiteTypes,
        );

        // Last section, per the UDDF specification. A dump links only to a
        // computer the owner block above declared, which it does only when
        // gear is included.
        UddfExportBuilders.buildDiveComputerControl(
          builder,
          sources,
          encodedById,
          declaredComputerIds: computerIds,
        );
      },
    );

    final xmlDoc = builder.buildDocument();
    return xmlDoc.toXmlString(pretty: true, indent: '  ');
  }

  String _fileName() =>
      'dives_export_${_dateFormat.format(DateTime.now())}.uddf';

  /// Export [dives] to UDDF and offer the file via the system share sheet.
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    final xmlString = await generateDivesUddfContent(
      dives,
      sites: sites,
      diveTankPressures: diveTankPressures,
      dataSources: dataSources,
      extras: extras,
      options: options,
    );
    return saveAndShareFile(xmlString, _fileName(), 'application/xml');
  }

  /// Export [dives] to UDDF and save to a user-selected location.
  ///
  /// Returns the chosen path, or null if the save dialog was cancelled.
  Future<String?> saveDivesToUddfFile(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfDivesExtras extras = const UddfDivesExtras.empty(),
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    final xmlString = await generateDivesUddfContent(
      dives,
      sites: sites,
      diveTankPressures: diveTankPressures,
      dataSources: dataSources,
      extras: extras,
      options: options,
    );

    final result = await FilePicker.saveFile(
      dialogTitle: 'Save UDDF File',
      fileName: _fileName(),
      type: FileType.custom,
      bytes: Uint8List.fromList(utf8.encode(xmlString)),
      mimeType: 'application/xml',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }
}
