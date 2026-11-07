import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' show DiveMode;
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_custom_fields.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_durations.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_logistics.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_gear_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_rebreather_writers.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// The `<dive>` element of the dives-only UDDF export, a file shared with
/// other people: the participants and gear go in only as [options] allows.
///
/// The full backup writes its dives with
/// [UddfExportBuilders.buildDiveElement] instead.
abstract final class UddfSharedDiveWriter {
  /// Writes [dive] into [builder]: [buddies] are its participant rows,
  /// [tankPressures] the readings its samples carry, one curve per tank,
  /// [gasSwitches] its gas switches and [sources] its data source rows.
  static void write(
    XmlBuilder builder,
    Dive dive, {
    required UddfExportOptions options,
    List<BuddyWithRole> buddies = const [],
    Map<String, List<TankPressurePoint>>? tankPressures,
    List<GasSwitchWithTank> gasSwitches = const [],
    List<DiveSourceExport> sources = const [],
  }) {
    builder.element(
      'dive',
      attributes: {'id': 'dive_${dive.id}'},
      nest: () {
        builder.element(
          'informationbeforedive',
          nest: () {
            builder.element('datetime', nest: dive.dateTime.toIso8601String());
            if (dive.diveNumber != null) {
              builder.element('divenumber', nest: dive.diveNumber.toString());
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
            if (dive.site != null) {
              builder.element(
                'link',
                attributes: {'ref': 'site_${dive.site!.id}'},
              );
            }
            if (options.includeParticipants) {
              UddfParticipantWriters.writeLeaders(builder, dive, buddies);
            }
            if (dive.diveCenter != null) {
              builder.element(
                'link',
                attributes: {'ref': 'center_${dive.diveCenter!.id}'},
              );
            }
            // Dive type(s)
            for (final typeId in dive.diveTypeIds) {
              builder.element('divetype', nest: typeId);
            }
            // Dive mode (ccr, scr), as in the full backup.
            // Without it a rebreather dive imports as open
            // circuit (issue #4178).
            if (dive.diveMode != DiveMode.oc) {
              builder.element('divemode', nest: dive.diveMode.name);
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
              UddfParticipantWriters.writeLinks(builder, buddies);
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
              final startMix = UddfExportBuilders.startMixId(dive);
              // One curve per cylinder, the one the app
              // draws; the <tankpressureseries> block keeps
              // what this cannot (issues #2492, #3917).
              final divePressures = tankPressures;
              for (final (index, point) in dive.profile.indexed) {
                builder.element(
                  'waypoint',
                  nest: () {
                    builder.element(
                      'divetime',
                      nest: point.timestamp.toString(),
                    );
                    builder.element('depth', nest: point.depth.toString());
                    // The starting mix rides on the first
                    // recorded sample, as in the full backup.
                    if (index == 0 && startMix != null) {
                      builder.element(
                        'switchmix',
                        attributes: {'ref': startMix},
                      );
                    }
                    if (point.temperature != null) {
                      builder.element(
                        'temperature',
                        nest: (point.temperature! + 273.15).toString(),
                      ); // Kelvin
                    }
                    // Tank pressure from tank_pressure_series,
                    // naming the <tankdata> declared below.
                    if (divePressures != null) {
                      for (final entry in divePressures.entries) {
                        final pressure =
                            UddfSourceAttribution.findPressureAtTimestamp(
                              entry.value,
                              point.timestamp,
                            );
                        if (pressure != null) {
                          builder.element(
                            'tankpressure',
                            attributes: {'ref': 'tank_${entry.key}'},
                            nest: (pressure * 100000).toString(),
                          );
                        }
                      }
                    }
                    // CCR/SCR setpoint, loop ppO2 and cell
                    // readings, as in the full backup.
                    UddfRebreatherWriters.writeSample(builder, point);
                    // Computer-reported GF99, as Shearwater
                    // Cloud writes it, so a round trip keeps
                    // the recorded value.
                    if (point.gf99 != null) {
                      builder.element(
                        'gradientfactor',
                        nest: point.gf99.toString(),
                      );
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

        // Rebreather settings, as in the full backup.
        UddfRebreatherWriters.writeConfiguration(builder, dive);

        builder.element(
          'informationafterdive',
          nest: () {
            if (dive.maxDepth != null) {
              builder.element('greatestdepth', nest: dive.maxDepth.toString());
            }
            if (dive.avgDepth != null) {
              builder.element('averagedepth', nest: dive.avgDepth.toString());
            }
            UddfDiveDurations.write(builder, dive);
            if (dive.waterTemp != null) {
              builder.element(
                'lowesttemperature',
                nest: (dive.waterTemp! + 273.15).toString(),
              ); // Kelvin
            }
            if (UddfExportBuilders.visibilityForUddf(dive) case final vis?) {
              builder.element('visibility', nest: vis);
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
            if (dive.effectiveWaterType != null) {
              builder.element('watertype', nest: dive.effectiveWaterType!.name);
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
            UddfDiveLogistics.write(builder, dive);
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
            if (options.includeParticipants) {
              UddfParticipantWriters.writeInlineBuddies(builder, dive, buddies);
            }
            UddfDiveCustomFields.write(builder, dive);
            UddfExportBuilders.buildGasSwitches(builder, gasSwitches, sources);
          },
        );
      },
    );
  }
}
