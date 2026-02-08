import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Handles simple UDDF export of dives with optional site data.
class UddfExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
  }) async {
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
                            if (dive.diveMaster != null &&
                                dive.diveMaster!.isNotEmpty) {
                              builder.element(
                                'divemaster',
                                nest: dive.diveMaster,
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
                            // Dive type
                            builder.element('divetype', nest: dive.diveTypeId);
                            // Entry method
                            if (dive.entryMethod != null) {
                              builder.element(
                                'entrytype',
                                nest: dive.entryMethod!.name,
                              );
                            }
                          },
                        );

                        // Samples (dive profile)
                        builder.element(
                          'samples',
                          nest: () {
                            final tank = dive.tanks.isNotEmpty
                                ? dive.tanks.first
                                : null;
                            final mixId = tank != null
                                ? 'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}'
                                : 'mix_21_0';

                            // Add tank switch at start
                            builder.element(
                              'waypoint',
                              nest: () {
                                builder.element('divetime', nest: '0');
                                builder.element('depth', nest: '0');
                                builder.element(
                                  'switchmix',
                                  attributes: {'ref': mixId},
                                );
                              },
                            );

                            if (dive.profile.isNotEmpty) {
                              // Use actual profile data
                              for (final point in dive.profile) {
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
                                    if (point.temperature != null) {
                                      builder.element(
                                        'temperature',
                                        nest: (point.temperature! + 273.15)
                                            .toString(),
                                      ); // Kelvin
                                    }
                                    if (point.pressure != null) {
                                      builder.element(
                                        'tankpressure',
                                        nest: (point.pressure! * 100000)
                                            .toString(),
                                      ); // Pascal
                                    }
                                  },
                                );
                              }
                            } else {
                              // Generate basic profile from dive data
                              final durationSecs =
                                  dive.duration?.inSeconds ?? 0;
                              if (dive.maxDepth != null && durationSecs > 0) {
                                // Descent to max depth (assume 1/5 of dive)
                                final descentTime = (durationSecs * 0.2)
                                    .toInt();
                                builder.element(
                                  'waypoint',
                                  nest: () {
                                    builder.element(
                                      'divetime',
                                      nest: descentTime.toString(),
                                    );
                                    builder.element(
                                      'depth',
                                      nest: dive.maxDepth.toString(),
                                    );
                                    if (dive.waterTemp != null) {
                                      builder.element(
                                        'temperature',
                                        nest: (dive.waterTemp! + 273.15)
                                            .toString(),
                                      );
                                    }
                                  },
                                );

                                // Bottom time at avg depth (3/5 of dive)
                                final bottomTime = (durationSecs * 0.8).toInt();
                                builder.element(
                                  'waypoint',
                                  nest: () {
                                    builder.element(
                                      'divetime',
                                      nest: bottomTime.toString(),
                                    );
                                    builder.element(
                                      'depth',
                                      nest:
                                          (dive.avgDepth ??
                                                  dive.maxDepth! * 0.7)
                                              .toString(),
                                    );
                                  },
                                );

                                // Ascent to surface
                                builder.element(
                                  'waypoint',
                                  nest: () {
                                    builder.element(
                                      'divetime',
                                      nest: durationSecs.toString(),
                                    );
                                    builder.element('depth', nest: '0');
                                  },
                                );
                              }
                            }
                          },
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
                            if (dive.duration != null) {
                              builder.element(
                                'diveduration',
                                nest: dive.duration!.inSeconds.toString(),
                              );
                            }
                            if (dive.waterTemp != null) {
                              builder.element(
                                'lowesttemperature',
                                nest: (dive.waterTemp! + 273.15).toString(),
                              ); // Kelvin
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
                                  builder.element(
                                    'ratingvalue',
                                    nest: dive.rating.toString(),
                                  );
                                },
                              );
                            }
                            // Conditions
                            if (dive.waterType != null) {
                              builder.element(
                                'watertype',
                                nest: dive.waterType!.name,
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
                            if (dive.buddy != null && dive.buddy!.isNotEmpty) {
                              builder.element(
                                'buddy',
                                nest: () {
                                  builder.element(
                                    'personal',
                                    nest: () {
                                      builder.element(
                                        'firstname',
                                        nest: dive.buddy,
                                      );
                                    },
                                  );
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
      },
    );

    final xmlDoc = builder.buildDocument();
    final xmlString = xmlDoc.toXmlString(pretty: true, indent: '  ');
    final fileName = 'dives_export_${_dateFormat.format(DateTime.now())}.uddf';
    return saveAndShareFile(xmlString, fileName, 'application/xml');
  }

  String _visibilityToUddf(enums.Visibility visibility) {
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
