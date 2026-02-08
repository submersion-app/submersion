import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Handles comprehensive UDDF export of all application data.
class UddfFullExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Export ALL application data to UDDF format.
  /// This includes: dives, sites, equipment, buddies, certifications,
  /// dive centers, species, service records, settings, trips, tags,
  /// dive types, dive computers, equipment sets, and courses.
  /// Generate comprehensive UDDF XML content as a string.
  ///
  /// Shared by both the share and save-to-file export paths.
  String _generateAllDataXml({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
  }) {
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
        if (owner != null || (buddies != null && buddies.isNotEmpty)) {
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
                    // Collect unique dive computers from all dives
                    final uniqueComputers = <String, Map<String, String>>{};
                    for (final dive in dives) {
                      if (dive.diveComputerModel != null &&
                          dive.diveComputerModel!.isNotEmpty) {
                        final computerId =
                            'dc_${dive.diveComputerModel!.replaceAll(' ', '_')}_${dive.diveComputerSerial ?? 'unknown'}';
                        uniqueComputers[computerId] = {
                          'model': dive.diveComputerModel!,
                          'serial': dive.diveComputerSerial ?? '',
                        };
                      }
                    }
                    if (uniqueComputers.isNotEmpty) {
                      builder.element(
                        'equipment',
                        nest: () {
                          for (final entry in uniqueComputers.entries) {
                            builder.element(
                              'divecomputer',
                              attributes: {'id': entry.key},
                              nest: () {
                                builder.element(
                                  'model',
                                  nest: entry.value['model'],
                                );
                                if (entry.value['serial']!.isNotEmpty) {
                                  builder.element(
                                    'serialnumber',
                                    nest: entry.value['serial'],
                                  );
                                }
                              },
                            );
                          }
                        },
                      );
                    }
                    // Certifications will be added in applicationdata section
                  },
                );
              }

              // Export buddies
              if (buddies != null) {
                for (final buddy in buddies) {
                  builder.element(
                    'buddy',
                    attributes: {'id': 'buddy_${buddy.id}'},
                    nest: () {
                      builder.element(
                        'personal',
                        nest: () {
                          // Split name into first/last
                          final nameParts = buddy.name.split(' ');
                          builder.element('firstname', nest: nameParts.first);
                          if (nameParts.length > 1) {
                            builder.element(
                              'lastname',
                              nest: nameParts.sublist(1).join(' '),
                            );
                          }
                          if (buddy.email != null && buddy.email!.isNotEmpty) {
                            builder.element('email', nest: buddy.email);
                          }
                          if (buddy.phone != null && buddy.phone!.isNotEmpty) {
                            builder.element('phone', nest: buddy.phone);
                          }
                        },
                      );
                      if (buddy.certificationLevel != null ||
                          buddy.certificationAgency != null) {
                        builder.element(
                          'certification',
                          nest: () {
                            if (buddy.certificationLevel != null) {
                              builder.element(
                                'level',
                                nest: buddy.certificationLevel!.name,
                              );
                            }
                            if (buddy.certificationAgency != null) {
                              builder.element(
                                'agency',
                                nest: buddy.certificationAgency!.name,
                              );
                            }
                          },
                        );
                      }
                      if (buddy.notes.isNotEmpty) {
                        builder.element('notes', nest: buddy.notes);
                      }
                    },
                  );
                }
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
                UddfExportBuilders.buildSiteElement(builder, site);
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
        builder.element(
          'gasdefinitions',
          nest: () {
            final gasMixes = <String, GasMix>{};
            for (final dive in dives) {
              for (final tank in dive.tanks) {
                final key =
                    'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}';
                gasMixes[key] = tank.gasMix;
              }
            }
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

        // Profile data (dives)
        if (dives.isNotEmpty) {
          builder.element(
            'profiledata',
            nest: () {
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
                      final diveBuddyList = diveBuddies?[dive.id] ?? [];
                      final diveTagList = diveTags?[dive.id] ?? [];
                      final profileEventList =
                          diveProfileEvents?[dive.id] ?? [];
                      final weightList = diveWeights?[dive.id] ?? [];
                      final gasSwitchList = diveGasSwitches?[dive.id] ?? [];
                      UddfExportBuilders.buildDiveElement(
                        builder,
                        dive,
                        buddies,
                        diveBuddyList,
                        diveTagList,
                        profileEventList,
                        weightList,
                        trips,
                        gasSwitchList,
                      );
                    }
                  },
                );
              }
            },
          );
        }

        // Application data section for all non-standard data
        UddfExportBuilders.buildApplicationData(
          builder,
          equipment: equipment,
          certifications: certifications,
          diveCenters: diveCenters,
          species: species,
          serviceRecords: serviceRecords,
          settings: settings,
          owner: owner,
          tags: tags,
          customDiveTypes: customDiveTypes,
          diveComputers: diveComputers,
          equipmentSets: equipmentSets,
          trips: trips,
          courses: courses,
        );
      },
    );

    final xmlDoc = builder.buildDocument();
    return xmlDoc.toXmlString(pretty: true, indent: '  ');
  }

  /// Export ALL application data to UDDF and share via the system share sheet.
  /// Returns the share result path.
  Future<String> exportAllDataToUddf({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
  }) {
    final xmlString = _generateAllDataXml(
      dives: dives,
      sites: sites,
      equipment: equipment,
      buddies: buddies,
      certifications: certifications,
      diveCenters: diveCenters,
      species: species,
      serviceRecords: serviceRecords,
      settings: settings,
      diveBuddies: diveBuddies,
      owner: owner,
      trips: trips,
      tags: tags,
      diveTags: diveTags,
      customDiveTypes: customDiveTypes,
      diveComputers: diveComputers,
      diveProfileEvents: diveProfileEvents,
      diveWeights: diveWeights,
      equipmentSets: equipmentSets,
      courses: courses,
      diveGasSwitches: diveGasSwitches,
    );
    final fileName =
        'submersion_backup_${_dateFormat.format(DateTime.now())}.uddf';
    return saveAndShareFile(xmlString, fileName, 'application/xml');
  }

  /// Export ALL application data to UDDF and save to a user-selected file.
  /// Returns the file path, or null if cancelled.
  Future<String?> saveAllDataToUddfFile({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    Map<String, List<BuddyWithRole>>? diveBuddies,
    Diver? owner,
    List<Trip>? trips,
    List<Tag>? tags,
    Map<String, List<Tag>>? diveTags,
    List<DiveTypeEntity>? customDiveTypes,
    List<DiveComputer>? diveComputers,
    Map<String, List<ProfileEvent>>? diveProfileEvents,
    Map<String, List<DiveWeight>>? diveWeights,
    List<EquipmentSet>? equipmentSets,
    List<Course>? courses,
    Map<String, List<GasSwitchWithTank>>? diveGasSwitches,
  }) async {
    final xmlString = _generateAllDataXml(
      dives: dives,
      sites: sites,
      equipment: equipment,
      buddies: buddies,
      certifications: certifications,
      diveCenters: diveCenters,
      species: species,
      serviceRecords: serviceRecords,
      settings: settings,
      diveBuddies: diveBuddies,
      owner: owner,
      trips: trips,
      tags: tags,
      diveTags: diveTags,
      customDiveTypes: customDiveTypes,
      diveComputers: diveComputers,
      diveProfileEvents: diveProfileEvents,
      diveWeights: diveWeights,
      equipmentSets: equipmentSets,
      courses: courses,
      diveGasSwitches: diveGasSwitches,
    );
    final fileName =
        'submersion_backup_${_dateFormat.format(DateTime.now())}.uddf';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save UDDF File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['uddf', 'xml'],
      bytes: Uint8List.fromList(utf8.encode(xmlString)),
    );

    if (result == null) return null;

    if (!Platform.isAndroid) {
      final file = File(result);
      await file.writeAsString(xmlString);
    }

    return result;
  }
}
