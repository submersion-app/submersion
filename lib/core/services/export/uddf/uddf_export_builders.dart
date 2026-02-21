import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' hide Visibility;
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/services/export/models/export_service_record.dart';
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

/// Static XML builder methods for comprehensive UDDF export.
///
/// These methods build individual XML elements for sites, dives,
/// and application data sections of the UDDF document.
class UddfExportBuilders {
  static void buildSiteElement(XmlBuilder builder, DiveSite site) {
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
        if (site.minDepth != null) {
          builder.element('minimumdepth', nest: site.minDepth.toString());
        }
        if (site.maxDepth != null) {
          builder.element('maximumdepth', nest: site.maxDepth.toString());
        }
        if (site.difficulty != null) {
          builder.element('difficulty', nest: site.difficulty!.name);
        }
        if (site.rating != null) {
          builder.element('siterating', nest: site.rating.toString());
        }
        if (site.altitude != null) {
          builder.element('sitealtitude', nest: site.altitude.toString());
        }
        if (site.hazards != null && site.hazards!.isNotEmpty) {
          builder.element('hazards', nest: site.hazards);
        }
        if (site.accessNotes != null && site.accessNotes!.isNotEmpty) {
          builder.element('accessnotes', nest: site.accessNotes);
        }
        if (site.mooringNumber != null && site.mooringNumber!.isNotEmpty) {
          builder.element('mooringnumber', nest: site.mooringNumber);
        }
        if (site.parkingInfo != null && site.parkingInfo!.isNotEmpty) {
          builder.element('parkinginfo', nest: site.parkingInfo);
        }
        if (site.description.isNotEmpty) {
          builder.element('notes', nest: site.description);
        }
        if (site.notes.isNotEmpty && site.notes != site.description) {
          builder.element('sitenotesadditional', nest: site.notes);
        }
      },
    );
  }

  static void buildDiveElement(
    XmlBuilder builder,
    Dive dive,
    List<Buddy>? buddies,
    List<BuddyWithRole> diveBuddyList,
    List<Tag> diveTags,
    List<ProfileEvent> profileEvents,
    List<DiveWeight> diveWeights,
    List<Trip>? trips,
    List<GasSwitchWithTank> gasSwitches,
  ) {
    // Separate buddies by role for UDDF export
    final regularBuddies = diveBuddyList
        .where((b) => b.role == BuddyRole.buddy || b.role == BuddyRole.student)
        .toList();
    final guidesAndDivemasters = diveBuddyList
        .where(
          (b) =>
              b.role == BuddyRole.diveGuide ||
              b.role == BuddyRole.diveMaster ||
              b.role == BuddyRole.instructor,
        )
        .toList();

    // Find the trip this dive belongs to
    Trip? diveTrip;
    if (trips != null && dive.tripId != null) {
      diveTrip = trips.cast<Trip?>().firstWhere(
        (t) => t?.id == dive.tripId,
        orElse: () => null,
      );
    }

    builder.element(
      'dive',
      attributes: {'id': 'dive_${dive.id}'},
      nest: () {
        // Information before dive
        builder.element(
          'informationbeforedive',
          nest: () {
            builder.element('datetime', nest: dive.dateTime.toIso8601String());
            if (dive.diveNumber != null) {
              builder.element('divenumber', nest: dive.diveNumber.toString());
            }
            if (dive.entryTime != null) {
              builder.element(
                'entrytime',
                nest: dive.entryTime!.toIso8601String(),
              );
            }
            if (dive.airTemp != null) {
              builder.element(
                'airtemperature',
                nest: (dive.airTemp! + 273.15).toString(),
              );
            }
            if (dive.altitude != null) {
              builder.element('altitude', nest: dive.altitude.toString());
            }
            if (dive.surfacePressure != null) {
              // UDDF stores pressure in Pascal (bar * 100000)
              builder.element(
                'atmosphericpressure',
                nest: (dive.surfacePressure! * 100000).toString(),
              );
            }
            // Surface interval before dive
            if (dive.surfaceInterval != null) {
              builder.element(
                'surfaceintervalbeforedive',
                nest: () {
                  builder.element(
                    'passedtime',
                    nest: dive.surfaceInterval!.inSeconds.toString(),
                  );
                },
              );
            }
            // Link to gradient factors decomodel if set
            if (dive.gradientFactorLow != null &&
                dive.gradientFactorHigh != null) {
              builder.element(
                'link',
                attributes: {
                  'ref':
                      'gf_${dive.gradientFactorLow}_${dive.gradientFactorHigh}',
                },
              );
            }
            if (dive.site != null) {
              builder.element(
                'link',
                attributes: {'ref': 'site_${dive.site!.id}'},
              );
            }
            // Link to trip
            if (diveTrip != null) {
              builder.element(
                'link',
                attributes: {'ref': 'trip_${diveTrip.id}'},
              );
            }
            // Export guides/divemasters/instructors in the divemaster field
            if (guidesAndDivemasters.isNotEmpty) {
              final names = guidesAndDivemasters
                  .map((b) => b.buddy.name)
                  .join(', ');
              builder.element('divemaster', nest: names);
            } else if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty) {
              // Fallback to legacy field if no linked buddies
              builder.element('divemaster', nest: dive.diveMaster);
            }
            if (dive.diveCenter != null) {
              builder.element(
                'link',
                attributes: {'ref': 'center_${dive.diveCenter!.id}'},
              );
            }
            builder.element('divetype', nest: dive.diveTypeId);
            // Dive mode (oc, ccr, scr)
            if (dive.diveMode != DiveMode.oc) {
              builder.element('divemode', nest: dive.diveMode.name);
            }
            // Planned dive flag
            if (dive.isPlanned) {
              builder.element('isplanned', nest: 'true');
            }
            // Course association
            if (dive.courseId != null) {
              builder.element(
                'link',
                attributes: {'ref': 'course_${dive.courseId}'},
              );
            }
            if (dive.entryMethod != null) {
              builder.element('entrytype', nest: dive.entryMethod!.name);
            }
            // Link to buddy records in diver section
            for (final buddyWithRole in diveBuddyList) {
              builder.element(
                'link',
                attributes: {'ref': 'buddy_${buddyWithRole.buddy.id}'},
              );
            }
            // Equipment used on this dive (including dive computer)
            if (dive.equipment.isNotEmpty ||
                (dive.diveComputerModel != null &&
                    dive.diveComputerModel!.isNotEmpty)) {
              builder.element(
                'equipmentused',
                nest: () {
                  for (final item in dive.equipment) {
                    builder.element('equipmentref', nest: 'equip_${item.id}');
                  }
                  // Link to dive computer
                  if (dive.diveComputerModel != null &&
                      dive.diveComputerModel!.isNotEmpty) {
                    final computerId =
                        'dc_${dive.diveComputerModel!.replaceAll(' ', '_')}_${dive.diveComputerSerial ?? 'unknown'}';
                    builder.element('link', attributes: {'ref': computerId});
                  }
                },
              );
            }
          },
        );

        // Samples (dive profile)
        builder.element(
          'samples',
          nest: () {
            final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
            final mixId = tank != null
                ? 'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}'
                : 'mix_21_0';

            builder.element(
              'waypoint',
              nest: () {
                builder.element('divetime', nest: '0');
                builder.element('depth', nest: '0');
                builder.element('switchmix', attributes: {'ref': mixId});
              },
            );

            if (dive.profile.isNotEmpty) {
              for (final point in dive.profile) {
                builder.element(
                  'waypoint',
                  nest: () {
                    builder.element(
                      'divetime',
                      nest: point.timestamp.toString(),
                    );
                    builder.element('depth', nest: point.depth.toString());
                    if (point.temperature != null) {
                      builder.element(
                        'temperature',
                        nest: (point.temperature! + 273.15).toString(),
                      );
                    }
                    if (point.pressure != null) {
                      builder.element(
                        'tankpressure',
                        nest: (point.pressure! * 100000).toString(),
                      );
                    }
                    if (point.heartRate != null) {
                      builder.element(
                        'heartrate',
                        nest: point.heartRate.toString(),
                      );
                    }
                    // CCR/SCR sensor readings
                    if (point.setpoint != null) {
                      builder.element(
                        'setpoint',
                        nest: point.setpoint.toString(),
                      );
                    }
                    if (point.ppO2 != null) {
                      builder.element('ppo2', nest: point.ppO2.toString());
                    }
                  },
                );
              }
            } else {
              final durationSecs = dive.duration?.inSeconds ?? 0;
              if (dive.maxDepth != null && durationSecs > 0) {
                final descentTime = (durationSecs * 0.2).toInt();
                builder.element(
                  'waypoint',
                  nest: () {
                    builder.element('divetime', nest: descentTime.toString());
                    builder.element('depth', nest: dive.maxDepth.toString());
                    if (dive.waterTemp != null) {
                      builder.element(
                        'temperature',
                        nest: (dive.waterTemp! + 273.15).toString(),
                      );
                    }
                  },
                );

                final bottomTime = (durationSecs * 0.8).toInt();
                builder.element(
                  'waypoint',
                  nest: () {
                    builder.element('divetime', nest: bottomTime.toString());
                    builder.element(
                      'depth',
                      nest: (dive.avgDepth ?? dive.maxDepth! * 0.7).toString(),
                    );
                  },
                );

                builder.element(
                  'waypoint',
                  nest: () {
                    builder.element('divetime', nest: durationSecs.toString());
                    builder.element('depth', nest: '0');
                  },
                );
              }
            }
          },
        );

        // Tank data (complete tank information)
        if (dive.tanks.isNotEmpty) {
          for (final tank in dive.tanks) {
            builder.element(
              'tankdata',
              nest: () {
                // Link to gas mix
                final mixId =
                    'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}';
                builder.element('link', attributes: {'ref': mixId});
                // Tank name
                if (tank.name != null && tank.name!.isNotEmpty) {
                  builder.element('tankname', nest: tank.name);
                }
                // Volume in liters
                if (tank.volume != null) {
                  builder.element('tankvolume', nest: tank.volume.toString());
                }
                // Working pressure in Pascal (UDDF standard)
                if (tank.workingPressure != null) {
                  builder.element(
                    'tankworkingpressure',
                    nest: (tank.workingPressure! * 100000).toString(),
                  );
                }
                // Start pressure in Pascal
                if (tank.startPressure != null) {
                  builder.element(
                    'tankpressurebegin',
                    nest: (tank.startPressure! * 100000).toString(),
                  );
                }
                // End pressure in Pascal
                if (tank.endPressure != null) {
                  builder.element(
                    'tankpressureend',
                    nest: (tank.endPressure! * 100000).toString(),
                  );
                }
                // Tank role (app-specific)
                builder.element('tankrole', nest: tank.role.name);
                // Tank material
                if (tank.material != null) {
                  builder.element('tankmaterial', nest: tank.material!.name);
                }
                // Tank order (for multi-tank configurations)
                builder.element('tankorder', nest: tank.order.toString());
              },
            );
          }
        }

        // Rebreather configuration (CCR/SCR data)
        if (dive.diveMode != DiveMode.oc) {
          builder.element(
            'rebreather',
            nest: () {
              builder.element('divemode', nest: dive.diveMode.name);
              // CCR Setpoints
              if (dive.setpointLow != null) {
                builder.element(
                  'setpointlow',
                  nest: dive.setpointLow.toString(),
                );
              }
              if (dive.setpointHigh != null) {
                builder.element(
                  'setpointhigh',
                  nest: dive.setpointHigh.toString(),
                );
              }
              if (dive.setpointDeco != null) {
                builder.element(
                  'setpointdeco',
                  nest: dive.setpointDeco.toString(),
                );
              }
              // SCR Configuration
              if (dive.scrType != null) {
                builder.element('scrtype', nest: dive.scrType!.name);
              }
              if (dive.scrInjectionRate != null) {
                builder.element(
                  'scrinjectionrate',
                  nest: dive.scrInjectionRate.toString(),
                );
              }
              if (dive.scrAdditionRatio != null) {
                builder.element(
                  'scradditionratio',
                  nest: dive.scrAdditionRatio.toString(),
                );
              }
              if (dive.scrOrificeSize != null) {
                builder.element('scrorificesize', nest: dive.scrOrificeSize);
              }
              if (dive.assumedVo2 != null) {
                builder.element('assumedvo2', nest: dive.assumedVo2.toString());
              }
              // Diluent gas
              if (dive.diluentGas != null) {
                builder.element(
                  'diluento2',
                  nest: dive.diluentGas!.o2.toString(),
                );
                builder.element(
                  'diluenthe',
                  nest: dive.diluentGas!.he.toString(),
                );
              }
              // Loop FO2 measurements
              if (dive.loopO2Min != null) {
                builder.element('loopo2min', nest: dive.loopO2Min.toString());
              }
              if (dive.loopO2Max != null) {
                builder.element('loopo2max', nest: dive.loopO2Max.toString());
              }
              if (dive.loopO2Avg != null) {
                builder.element('loopo2avg', nest: dive.loopO2Avg.toString());
              }
              // Scrubber and loop info
              if (dive.loopVolume != null) {
                builder.element('loopvolume', nest: dive.loopVolume.toString());
              }
              if (dive.scrubber != null) {
                builder.element('scrubbertype', nest: dive.scrubber!.type);
                if (dive.scrubber!.ratedMinutes != null) {
                  builder.element(
                    'scrubberdurationminutes',
                    nest: dive.scrubber!.ratedMinutes.toString(),
                  );
                }
                if (dive.scrubber!.remainingMinutes != null) {
                  builder.element(
                    'scrubberremainingminutes',
                    nest: dive.scrubber!.remainingMinutes.toString(),
                  );
                }
              }
            },
          );
        }

        // Information after dive
        builder.element(
          'informationafterdive',
          nest: () {
            if (dive.exitTime != null) {
              builder.element(
                'exittime',
                nest: dive.exitTime!.toIso8601String(),
              );
            }
            if (dive.maxDepth != null) {
              builder.element('greatestdepth', nest: dive.maxDepth.toString());
            }
            if (dive.avgDepth != null) {
              builder.element('averagedepth', nest: dive.avgDepth.toString());
            }
            if (dive.duration != null) {
              builder.element(
                'diveduration',
                nest: dive.duration!.inSeconds.toString(),
              );
            }
            if (dive.runtime != null) {
              builder.element(
                'runtime',
                nest: dive.runtime!.inSeconds.toString(),
              );
            }
            if (dive.waterTemp != null) {
              builder.element(
                'lowesttemperature',
                nest: (dive.waterTemp! + 273.15).toString(),
              );
            }
            if (dive.visibility != null) {
              builder.element(
                'visibility',
                nest: _visibilityToUddf(dive.visibility!),
              );
            }
            if (dive.rating != null) {
              builder.element(
                'rating',
                nest: () {
                  builder.element('ratingvalue', nest: dive.rating.toString());
                },
              );
            }
            // Conditions
            if (dive.waterType != null) {
              builder.element('watertype', nest: dive.waterType!.name);
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
              builder.element('swellheight', nest: dive.swellHeight.toString());
            }
            if (dive.exitMethod != null) {
              builder.element('exittype', nest: dive.exitMethod!.name);
            }
            // Weight system
            if (dive.weightAmount != null) {
              builder.element(
                'weightused',
                nest: () {
                  builder.element('amount', nest: dive.weightAmount.toString());
                  if (dive.weightType != null) {
                    builder.element('type', nest: dive.weightType!.name);
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
                        'speciesref': 'species_${sighting.speciesId}',
                        'count': sighting.count.toString(),
                      },
                      nest: () {
                        if (sighting.notes.isNotEmpty) {
                          builder.element('notes', nest: sighting.notes);
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
            // App-specific dive metadata
            if (dive.isFavorite) {
              builder.element('isfavorite', nest: 'true');
            }
            if (dive.photoIds.isNotEmpty) {
              builder.element(
                'photos',
                nest: () {
                  for (final photoId in dive.photoIds) {
                    builder.element('photoref', nest: photoId);
                  }
                },
              );
            }
            // Export regular buddies in the buddy field for compatibility
            if (regularBuddies.isNotEmpty) {
              for (final buddyWithRole in regularBuddies) {
                builder.element(
                  'buddy',
                  nest: () {
                    builder.element(
                      'personal',
                      nest: () {
                        final nameParts = buddyWithRole.buddy.name.split(' ');
                        builder.element('firstname', nest: nameParts.first);
                        if (nameParts.length > 1) {
                          builder.element(
                            'lastname',
                            nest: nameParts.sublist(1).join(' '),
                          );
                        }
                      },
                    );
                  },
                );
              }
            } else if (dive.buddy != null && dive.buddy!.isNotEmpty) {
              // Fallback to legacy field if no linked buddies
              builder.element(
                'buddy',
                nest: () {
                  builder.element(
                    'personal',
                    nest: () {
                      builder.element('firstname', nest: dive.buddy);
                    },
                  );
                },
              );
            }
            // Export additional weights (app-specific, beyond single weight)
            if (diveWeights.isNotEmpty) {
              builder.element(
                'weights',
                nest: () {
                  for (final weight in diveWeights) {
                    builder.element(
                      'weight',
                      nest: () {
                        builder.element(
                          'amount',
                          nest: weight.amountKg.toString(),
                        );
                        builder.element('type', nest: weight.weightType.name);
                        if (weight.notes.isNotEmpty) {
                          builder.element('notes', nest: weight.notes);
                        }
                      },
                    );
                  }
                },
              );
            }
            // Export tags (app-specific)
            if (diveTags.isNotEmpty) {
              builder.element(
                'tags',
                nest: () {
                  for (final tag in diveTags) {
                    builder.element('tagref', nest: 'tag_${tag.id}');
                  }
                },
              );
            }
            // Export profile events (app-specific)
            if (profileEvents.isNotEmpty) {
              builder.element(
                'profileevents',
                nest: () {
                  for (final event in profileEvents) {
                    builder.element(
                      'event',
                      nest: () {
                        builder.element(
                          'time',
                          nest: event.timestamp.toString(),
                        );
                        builder.element(
                          'eventtype',
                          nest: event.eventType.name,
                        );
                        builder.element('severity', nest: event.severity.name);
                        if (event.depth != null) {
                          builder.element(
                            'depth',
                            nest: event.depth.toString(),
                          );
                        }
                        if (event.value != null) {
                          builder.element(
                            'value',
                            nest: event.value.toString(),
                          );
                        }
                        if (event.description != null) {
                          builder.element(
                            'description',
                            nest: event.description,
                          );
                        }
                        if (event.tankId != null) {
                          builder.element('tankref', nest: event.tankId);
                        }
                      },
                    );
                  }
                },
              );
            }
            // Export gas switches (source data from dive computers)
            if (gasSwitches.isNotEmpty) {
              builder.element(
                'gasswitches',
                nest: () {
                  for (final gs in gasSwitches) {
                    builder.element(
                      'gasswitch',
                      nest: () {
                        builder.element('time', nest: gs.timestamp.toString());
                        if (gs.depth != null) {
                          builder.element('depth', nest: gs.depth.toString());
                        }
                        builder.element('tankref', nest: gs.tankId);
                        builder.element('gasmix', nest: gs.gasMix);
                        builder.element(
                          'o2fraction',
                          nest: gs.o2Fraction.toString(),
                        );
                        if (gs.heFraction > 0) {
                          builder.element(
                            'hefraction',
                            nest: gs.heFraction.toString(),
                          );
                        }
                      },
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

  static void buildApplicationData(
    XmlBuilder builder, {
    List<EquipmentItem>? equipment,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    Diver? owner,
    List<Tag>? tags,
    List<DiveTypeEntity>? customDiveTypes,
    List<DiveComputer>? diveComputers,
    List<EquipmentSet>? equipmentSets,
    List<Trip>? trips,
    List<Course>? courses,
  }) {
    final hasData =
        (equipment?.isNotEmpty ?? false) ||
        (certifications?.isNotEmpty ?? false) ||
        (diveCenters?.isNotEmpty ?? false) ||
        (species?.isNotEmpty ?? false) ||
        (serviceRecords?.isNotEmpty ?? false) ||
        (settings?.isNotEmpty ?? false) ||
        owner != null ||
        (tags?.isNotEmpty ?? false) ||
        (customDiveTypes?.isNotEmpty ?? false) ||
        (diveComputers?.isNotEmpty ?? false) ||
        (equipmentSets?.isNotEmpty ?? false) ||
        (trips?.isNotEmpty ?? false) ||
        (courses?.isNotEmpty ?? false);

    if (!hasData) return;

    builder.element(
      'applicationdata',
      nest: () {
        builder.element(
          'submersion',
          attributes: {'version': '1.0'},
          nest: () {
            // Equipment
            if (equipment != null && equipment.isNotEmpty) {
              builder.element(
                'equipment',
                nest: () {
                  for (final item in equipment) {
                    builder.element(
                      'item',
                      attributes: {'id': 'equip_${item.id}'},
                      nest: () {
                        builder.element('name', nest: item.name);
                        builder.element('type', nest: item.type.name);
                        if (item.brand != null) {
                          builder.element('brand', nest: item.brand);
                        }
                        if (item.model != null) {
                          builder.element('model', nest: item.model);
                        }
                        if (item.serialNumber != null) {
                          builder.element(
                            'serialnumber',
                            nest: item.serialNumber,
                          );
                        }
                        if (item.size != null) {
                          builder.element('size', nest: item.size);
                        }
                        builder.element('status', nest: item.status.name);
                        if (item.purchaseDate != null) {
                          builder.element(
                            'purchasedate',
                            nest: item.purchaseDate!.toIso8601String(),
                          );
                        }
                        if (item.purchasePrice != null) {
                          builder.element(
                            'purchaseprice',
                            nest: item.purchasePrice.toString(),
                          );
                          builder.element(
                            'purchasecurrency',
                            nest: item.purchaseCurrency,
                          );
                        }
                        if (item.lastServiceDate != null) {
                          builder.element(
                            'lastservicedate',
                            nest: item.lastServiceDate!.toIso8601String(),
                          );
                        }
                        if (item.serviceIntervalDays != null) {
                          builder.element(
                            'serviceintervaldays',
                            nest: item.serviceIntervalDays.toString(),
                          );
                        }
                        builder.element(
                          'isactive',
                          nest: item.isActive.toString(),
                        );
                        if (item.notes.isNotEmpty) {
                          builder.element('notes', nest: item.notes);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Certifications
            if (certifications != null && certifications.isNotEmpty) {
              builder.element(
                'certifications',
                nest: () {
                  for (final cert in certifications) {
                    builder.element(
                      'cert',
                      attributes: {'id': 'cert_${cert.id}'},
                      nest: () {
                        builder.element('name', nest: cert.name);
                        builder.element('agency', nest: cert.agency.name);
                        if (cert.level != null) {
                          builder.element('level', nest: cert.level!.name);
                        }
                        if (cert.cardNumber != null) {
                          builder.element('cardnumber', nest: cert.cardNumber);
                        }
                        if (cert.issueDate != null) {
                          builder.element(
                            'issuedate',
                            nest: cert.issueDate!.toIso8601String(),
                          );
                        }
                        if (cert.expiryDate != null) {
                          builder.element(
                            'expirydate',
                            nest: cert.expiryDate!.toIso8601String(),
                          );
                        }
                        if (cert.instructorName != null) {
                          builder.element(
                            'instructorname',
                            nest: cert.instructorName,
                          );
                        }
                        if (cert.instructorNumber != null) {
                          builder.element(
                            'instructornumber',
                            nest: cert.instructorNumber,
                          );
                        }
                        if (cert.notes.isNotEmpty) {
                          builder.element('notes', nest: cert.notes);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Dive Centers
            if (diveCenters != null && diveCenters.isNotEmpty) {
              builder.element(
                'divecenters',
                nest: () {
                  for (final center in diveCenters) {
                    builder.element(
                      'center',
                      attributes: {'id': 'center_${center.id}'},
                      nest: () {
                        builder.element('name', nest: center.name);
                        if (center.street != null) {
                          builder.element('street', nest: center.street);
                        }
                        if (center.city != null) {
                          builder.element('city', nest: center.city);
                        }
                        if (center.stateProvince != null) {
                          builder.element(
                            'stateprovince',
                            nest: center.stateProvince,
                          );
                        }
                        if (center.postalCode != null) {
                          builder.element(
                            'postalcode',
                            nest: center.postalCode,
                          );
                        }
                        if (center.latitude != null &&
                            center.longitude != null) {
                          builder.element(
                            'latitude',
                            nest: center.latitude.toString(),
                          );
                          builder.element(
                            'longitude',
                            nest: center.longitude.toString(),
                          );
                        }
                        if (center.country != null) {
                          builder.element('country', nest: center.country);
                        }
                        if (center.phone != null) {
                          builder.element('phone', nest: center.phone);
                        }
                        if (center.email != null) {
                          builder.element('email', nest: center.email);
                        }
                        if (center.website != null) {
                          builder.element('website', nest: center.website);
                        }
                        if (center.affiliations.isNotEmpty) {
                          builder.element(
                            'affiliations',
                            nest: center.affiliations.join(','),
                          );
                        }
                        if (center.rating != null) {
                          builder.element(
                            'rating',
                            nest: center.rating.toString(),
                          );
                        }
                        if (center.notes.isNotEmpty) {
                          builder.element('notes', nest: center.notes);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Species
            if (species != null && species.isNotEmpty) {
              builder.element(
                'species',
                nest: () {
                  for (final spec in species) {
                    builder.element(
                      'spec',
                      attributes: {'id': 'species_${spec.id}'},
                      nest: () {
                        builder.element('commonname', nest: spec.commonName);
                        if (spec.scientificName != null) {
                          builder.element(
                            'scientificname',
                            nest: spec.scientificName,
                          );
                        }
                        builder.element('category', nest: spec.category.name);
                        if (spec.description != null) {
                          builder.element(
                            'description',
                            nest: spec.description,
                          );
                        }
                      },
                    );
                  }
                },
              );
            }

            // Service Records
            if (serviceRecords != null && serviceRecords.isNotEmpty) {
              builder.element(
                'servicerecords',
                nest: () {
                  for (final record in serviceRecords) {
                    builder.element(
                      'record',
                      attributes: {'id': 'service_${record.id}'},
                      nest: () {
                        builder.element(
                          'equipmentref',
                          nest: 'equip_${record.equipmentId}',
                        );
                        builder.element(
                          'servicetype',
                          nest: record.serviceType.name,
                        );
                        builder.element(
                          'servicedate',
                          nest: record.serviceDate.toIso8601String(),
                        );
                        if (record.provider != null) {
                          builder.element('provider', nest: record.provider);
                        }
                        if (record.cost != null) {
                          builder.element('cost', nest: record.cost.toString());
                          builder.element('currency', nest: record.currency);
                        }
                        if (record.nextServiceDue != null) {
                          builder.element(
                            'nextservicedue',
                            nest: record.nextServiceDue!.toIso8601String(),
                          );
                        }
                        if (record.notes.isNotEmpty) {
                          builder.element('notes', nest: record.notes);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Settings
            if (settings != null && settings.isNotEmpty) {
              builder.element(
                'settings',
                nest: () {
                  for (final entry in settings.entries) {
                    builder.element(
                      'setting',
                      attributes: {'key': entry.key},
                      nest: entry.value,
                    );
                  }
                },
              );
            }

            // Tags (no UDDF equivalent)
            if (tags != null && tags.isNotEmpty) {
              builder.element(
                'tags',
                nest: () {
                  for (final tag in tags) {
                    builder.element(
                      'tag',
                      attributes: {'id': 'tag_${tag.id}'},
                      nest: () {
                        builder.element('name', nest: tag.name);
                        if (tag.colorHex != null) {
                          builder.element('color', nest: tag.colorHex);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Custom Dive Types (no UDDF equivalent - UDDF has fixed types)
            if (customDiveTypes != null && customDiveTypes.isNotEmpty) {
              builder.element(
                'divetypes',
                nest: () {
                  for (final diveType in customDiveTypes) {
                    builder.element(
                      'divetype',
                      attributes: {'id': diveType.id},
                      nest: () {
                        builder.element('name', nest: diveType.name);
                        builder.element(
                          'sortorder',
                          nest: diveType.sortOrder.toString(),
                        );
                        builder.element(
                          'isbuiltin',
                          nest: diveType.isBuiltIn.toString(),
                        );
                      },
                    );
                  }
                },
              );
            }

            // Dive Computers (no UDDF equivalent)
            if (diveComputers != null && diveComputers.isNotEmpty) {
              builder.element(
                'divecomputers',
                nest: () {
                  for (final computer in diveComputers) {
                    builder.element(
                      'computer',
                      attributes: {'id': 'computer_${computer.id}'},
                      nest: () {
                        builder.element('name', nest: computer.name);
                        if (computer.manufacturer != null) {
                          builder.element(
                            'manufacturer',
                            nest: computer.manufacturer,
                          );
                        }
                        if (computer.model != null) {
                          builder.element('model', nest: computer.model);
                        }
                        if (computer.serialNumber != null) {
                          builder.element(
                            'serialnumber',
                            nest: computer.serialNumber,
                          );
                        }
                        if (computer.firmwareVersion != null) {
                          builder.element(
                            'firmwareversion',
                            nest: computer.firmwareVersion,
                          );
                        }
                        if (computer.connectionType != null) {
                          builder.element(
                            'connectiontype',
                            nest: computer.connectionType,
                          );
                        }
                        if (computer.bluetoothAddress != null) {
                          builder.element(
                            'bluetoothaddress',
                            nest: computer.bluetoothAddress,
                          );
                        }
                        builder.element(
                          'isfavorite',
                          nest: computer.isFavorite.toString(),
                        );
                        if (computer.notes.isNotEmpty) {
                          builder.element('notes', nest: computer.notes);
                        }
                      },
                    );
                  }
                },
              );
            }

            // Equipment Sets (no UDDF equivalent)
            if (equipmentSets != null && equipmentSets.isNotEmpty) {
              builder.element(
                'equipmentsets',
                nest: () {
                  for (final set in equipmentSets) {
                    builder.element(
                      'set',
                      attributes: {'id': 'set_${set.id}'},
                      nest: () {
                        builder.element('name', nest: set.name);
                        if (set.description.isNotEmpty) {
                          builder.element('description', nest: set.description);
                        }
                        if (set.equipmentIds.isNotEmpty) {
                          builder.element(
                            'items',
                            nest: () {
                              for (final itemId in set.equipmentIds) {
                                builder.element(
                                  'itemref',
                                  nest: 'equip_$itemId',
                                );
                              }
                            },
                          );
                        }
                      },
                    );
                  }
                },
              );
            }

            // Courses (no UDDF equivalent)
            if (courses != null && courses.isNotEmpty) {
              builder.element(
                'courses',
                nest: () {
                  for (final course in courses) {
                    builder.element(
                      'course',
                      attributes: {'id': 'course_${course.id}'},
                      nest: () {
                        builder.element('name', nest: course.name);
                        builder.element('agency', nest: course.agency.name);
                        builder.element(
                          'startdate',
                          nest: course.startDate.toIso8601String(),
                        );
                        if (course.completionDate != null) {
                          builder.element(
                            'completiondate',
                            nest: course.completionDate!.toIso8601String(),
                          );
                        }
                        if (course.instructorName != null) {
                          builder.element(
                            'instructorname',
                            nest: course.instructorName,
                          );
                        }
                        if (course.instructorNumber != null) {
                          builder.element(
                            'instructornumber',
                            nest: course.instructorNumber,
                          );
                        }
                        if (course.location != null) {
                          builder.element('location', nest: course.location);
                        }
                        if (course.notes.isNotEmpty) {
                          builder.element('notes', nest: course.notes);
                        }
                        // Link to certification earned
                        if (course.certificationId != null) {
                          builder.element(
                            'link',
                            attributes: {
                              'ref': 'cert_${course.certificationId}',
                            },
                          );
                        }
                        // Link to instructor buddy record
                        if (course.instructorId != null) {
                          builder.element(
                            'link',
                            attributes: {'ref': 'buddy_${course.instructorId}'},
                          );
                        }
                      },
                    );
                  }
                },
              );
            }

            // Owner extended data (medical, emergency, insurance - not in UDDF standard)
            if (owner != null) {
              builder.element(
                'ownerextended',
                nest: () {
                  if (owner.medicalNotes.isNotEmpty) {
                    builder.element('medicalnotes', nest: owner.medicalNotes);
                  }
                  if (owner.bloodType != null) {
                    builder.element('bloodtype', nest: owner.bloodType);
                  }
                  if (owner.allergies != null) {
                    builder.element('allergies', nest: owner.allergies);
                  }
                  if (owner.medications != null) {
                    builder.element('medications', nest: owner.medications);
                  }
                  if (owner.medicalClearanceExpiryDate != null) {
                    builder.element(
                      'medicalclearanceexpirydate',
                      nest: owner.medicalClearanceExpiryDate!.toIso8601String(),
                    );
                  }
                  if (owner.emergencyContact.isComplete) {
                    builder.element(
                      'emergencycontact',
                      nest: () {
                        if (owner.emergencyContact.name != null) {
                          builder.element(
                            'name',
                            nest: owner.emergencyContact.name,
                          );
                        }
                        if (owner.emergencyContact.phone != null) {
                          builder.element(
                            'phone',
                            nest: owner.emergencyContact.phone,
                          );
                        }
                        if (owner.emergencyContact.relation != null) {
                          builder.element(
                            'relationship',
                            nest: owner.emergencyContact.relation,
                          );
                        }
                      },
                    );
                  }
                  if (owner.emergencyContact2.isComplete) {
                    builder.element(
                      'emergencycontact2',
                      nest: () {
                        if (owner.emergencyContact2.name != null) {
                          builder.element(
                            'name',
                            nest: owner.emergencyContact2.name,
                          );
                        }
                        if (owner.emergencyContact2.phone != null) {
                          builder.element(
                            'phone',
                            nest: owner.emergencyContact2.phone,
                          );
                        }
                        if (owner.emergencyContact2.relation != null) {
                          builder.element(
                            'relationship',
                            nest: owner.emergencyContact2.relation,
                          );
                        }
                      },
                    );
                  }
                  if (owner.insurance.provider != null) {
                    builder.element(
                      'insurance',
                      nest: () {
                        builder.element(
                          'provider',
                          nest: owner.insurance.provider,
                        );
                        if (owner.insurance.policyNumber != null) {
                          builder.element(
                            'policynumber',
                            nest: owner.insurance.policyNumber,
                          );
                        }
                        if (owner.insurance.expiryDate != null) {
                          builder.element(
                            'expirydate',
                            nest: owner.insurance.expiryDate!.toIso8601String(),
                          );
                        }
                      },
                    );
                  }
                  if (owner.notes.isNotEmpty) {
                    builder.element('notes', nest: owner.notes);
                  }
                },
              );
            }

            // Trip extended data (resort/liveaboard names - not in UDDF standard)
            if (trips != null && trips.isNotEmpty) {
              final tripsWithExtendedData = trips.where(
                (t) =>
                    t.resortName != null && t.resortName!.isNotEmpty ||
                    t.liveaboardName != null && t.liveaboardName!.isNotEmpty,
              );
              if (tripsWithExtendedData.isNotEmpty) {
                builder.element(
                  'tripextended',
                  nest: () {
                    for (final trip in tripsWithExtendedData) {
                      builder.element(
                        'trip',
                        attributes: {'tripref': 'trip_${trip.id}'},
                        nest: () {
                          if (trip.resortName != null &&
                              trip.resortName!.isNotEmpty) {
                            builder.element(
                              'resortname',
                              nest: trip.resortName,
                            );
                          }
                          if (trip.liveaboardName != null &&
                              trip.liveaboardName!.isNotEmpty) {
                            builder.element(
                              'liveaboardname',
                              nest: trip.liveaboardName,
                            );
                          }
                        },
                      );
                    }
                  },
                );
              }
            }
          },
        );
      },
    );
  }

  static String _visibilityToUddf(enums.Visibility visibility) {
    switch (visibility) {
      case enums.Visibility.excellent:
        return '30'; // meters
      case enums.Visibility.good:
        return '20';
      case enums.Visibility.moderate:
        return '10';
      case enums.Visibility.poor:
        return '5';
      case enums.Visibility.unknown:
        return '0';
    }
  }
}
