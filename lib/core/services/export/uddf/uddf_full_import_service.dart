import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Handles comprehensive UDDF import including all application data.
///
/// Orchestrates parsing of all entity types (dives, sites, buddies,
/// equipment, certifications, etc.) from a full Submersion UDDF export.
/// Delegates base parsing to [UddfImportService] and entity parsing
/// to [UddfImportParsers].
class UddfFullImportService {
  /// Import ALL application data from UDDF file.
  /// Returns [UddfImportResult] with all parsed data.
  Future<UddfImportResult> importAllDataFromUddf(String uddfContent) async {
    final document = XmlDocument.parse(uddfContent);
    // Use rootElement instead of findElements to handle XML namespaces properly
    final uddfElement = document.rootElement;
    if (uddfElement.name.local != 'uddf') {
      throw const FormatException(
        'Invalid UDDF file: missing uddf root element',
      );
    }

    // Parse full buddy records and owner from diver section
    final buddies = <Map<String, dynamic>>[];
    final buddyMap = <String, Map<String, dynamic>>{};
    Map<String, dynamic>? owner;
    final diverElement = uddfElement.findElements('diver').firstOrNull;
    if (diverElement != null) {
      // Parse owner (current diver)
      final ownerElement = diverElement.findElements('owner').firstOrNull;
      if (ownerElement != null) {
        owner = UddfImportParsers.parseOwner(ownerElement);
      }

      // Parse buddies
      for (final buddyElement in diverElement.findElements('buddy')) {
        final buddyData = UddfImportParsers.parseFullBuddy(buddyElement);
        if (buddyData.isNotEmpty) {
          final buddyId = buddyElement.getAttribute('id');
          if (buddyId != null) {
            buddyMap[buddyId] = buddyData;
          }
          buddies.add(buddyData);
        }
      }
    }

    // Parse dive sites with extended fields
    final sites = <Map<String, dynamic>>[];
    final siteMap = <String, Map<String, dynamic>>{};
    final divesiteElement = uddfElement.findElements('divesite').firstOrNull;
    if (divesiteElement != null) {
      for (final siteElement in divesiteElement.findElements('site')) {
        final siteData = _parseFullSite(siteElement);
        final siteId = siteElement.getAttribute('id');
        if (siteId != null) {
          siteData['uddfId'] = siteId;
          siteMap[siteId] = siteData;
        }
        sites.add(siteData);
      }
    }

    // Parse trips (UDDF standard divetrip elements)
    final trips = <Map<String, dynamic>>[];
    final tripMap = <String, Map<String, dynamic>>{};
    for (final tripElement in uddfElement.findElements('divetrip')) {
      final tripData = UddfImportParsers.parseTrip(tripElement);
      final tripId = tripElement.getAttribute('id');
      if (tripId != null) {
        tripData['uddfId'] = tripId;
        tripMap[tripId] = tripData;
      }
      trips.add(tripData);
    }

    // Parse gas definitions
    final gasMixes = <String, GasMix>{};
    final gasDefsElement = uddfElement
        .findElements('gasdefinitions')
        .firstOrNull;
    if (gasDefsElement != null) {
      for (final mixElement in gasDefsElement.findElements('mix')) {
        final mixId = mixElement.getAttribute('id');
        if (mixId != null) {
          gasMixes[mixId] = _parseUddfGasMix(mixElement);
        }
      }
    }

    // Parse deco models for gradient factors
    final decoModels = <String, Map<String, int>>{};
    final decoModelElement = uddfElement.findElements('decomodel').firstOrNull;
    if (decoModelElement != null) {
      for (final buehlmannElement in decoModelElement.findElements(
        'buehlmann',
      )) {
        final modelId = buehlmannElement.getAttribute('id');
        if (modelId != null) {
          final gfLowText = UddfImportParsers.getElementText(
            buehlmannElement,
            'gradientfactorlow',
          );
          final gfHighText = UddfImportParsers.getElementText(
            buehlmannElement,
            'gradientfactorhigh',
          );
          decoModels[modelId] = {
            'gfLow': gfLowText != null ? int.tryParse(gfLowText) ?? 0 : 0,
            'gfHigh': gfHighText != null ? int.tryParse(gfHighText) ?? 0 : 0,
          };
        }
      }
    }

    // Parse dive computers from diver/owner/equipment section
    final diveComputersMap = <String, Map<String, String>>{};
    if (diverElement != null) {
      final ownerElement = diverElement.findElements('owner').firstOrNull;
      if (ownerElement != null) {
        final equipmentElement = ownerElement
            .findElements('equipment')
            .firstOrNull;
        if (equipmentElement != null) {
          for (final computerElement in equipmentElement.findElements(
            'divecomputer',
          )) {
            final computerId = computerElement.getAttribute('id');
            if (computerId != null) {
              final model = UddfImportParsers.getElementText(
                computerElement,
                'model',
              );
              final serial = UddfImportParsers.getElementText(
                computerElement,
                'serialnumber',
              );
              final firmware = UddfImportParsers.getElementText(
                computerElement,
                'firmwareversion',
              );
              diveComputersMap[computerId] = {
                'model': model ?? '',
                'serial': serial ?? '',
                'firmware': firmware ?? '',
              };
            }
          }
        }
      }
    }

    // Parse dives with extended fields
    final dives = <Map<String, dynamic>>[];
    final sightings = <Map<String, dynamic>>[];
    final profileDataElement = uddfElement
        .findElements('profiledata')
        .firstOrNull;
    if (profileDataElement != null) {
      for (final repGroup in profileDataElement.findElements(
        'repetitiongroup',
      )) {
        for (final diveElement in repGroup.findElements('dive')) {
          final diveData = _parseFullDive(
            diveElement,
            siteMap,
            buddyMap,
            gasMixes,
            decoModels,
            diveComputersMap,
          );
          if (diveData.isNotEmpty) {
            dives.add(diveData);
            // Extract sightings from dive
            if (diveData.containsKey('sightings')) {
              final diveSightings =
                  diveData['sightings'] as List<Map<String, dynamic>>?;
              if (diveSightings != null) {
                for (final sighting in diveSightings) {
                  sighting['diveId'] =
                      diveData['id'] ?? diveElement.getAttribute('id');
                  sightings.add(sighting);
                }
              }
            }
          }
        }
      }
    }

    // Parse applicationdata section
    final equipment = <Map<String, dynamic>>[];
    final certifications = <Map<String, dynamic>>[];
    final diveCenters = <Map<String, dynamic>>[];
    final species = <Map<String, dynamic>>[];
    final serviceRecords = <Map<String, dynamic>>[];
    final settings = <String, String>{};
    final tags = <Map<String, dynamic>>[];
    final customDiveTypes = <Map<String, dynamic>>[];
    final diveComputers = <Map<String, dynamic>>[];
    final equipmentSets = <Map<String, dynamic>>[];
    final courses = <Map<String, dynamic>>[];

    final appDataElement = uddfElement
        .findElements('applicationdata')
        .firstOrNull;
    if (appDataElement != null) {
      final submersionElement = appDataElement
          .findElements('submersion')
          .firstOrNull;
      if (submersionElement != null) {
        // Parse equipment
        final equipmentSection = submersionElement
            .findElements('equipment')
            .firstOrNull;
        if (equipmentSection != null) {
          for (final itemElement in equipmentSection.findElements('item')) {
            final itemData = UddfImportParsers.parseEquipmentItem(itemElement);
            if (itemData.isNotEmpty) {
              equipment.add(itemData);
            }
          }
        }

        // Parse certifications
        final certsSection = submersionElement
            .findElements('certifications')
            .firstOrNull;
        if (certsSection != null) {
          for (final certElement in certsSection.findElements('cert')) {
            final certData = UddfImportParsers.parseCertification(certElement);
            if (certData.isNotEmpty) {
              certifications.add(certData);
            }
          }
        }

        // Parse dive centers
        final centersSection = submersionElement
            .findElements('divecenters')
            .firstOrNull;
        if (centersSection != null) {
          for (final centerElement in centersSection.findElements('center')) {
            final centerData = UddfImportParsers.parseDiveCenter(centerElement);
            if (centerData.isNotEmpty) {
              diveCenters.add(centerData);
            }
          }
        }

        // Parse species
        final speciesSection = submersionElement
            .findElements('species')
            .firstOrNull;
        if (speciesSection != null) {
          for (final specElement in speciesSection.findElements('spec')) {
            final specData = UddfImportParsers.parseSpecies(specElement);
            if (specData.isNotEmpty) {
              species.add(specData);
            }
          }
        }

        // Parse service records
        final serviceSection = submersionElement
            .findElements('servicerecords')
            .firstOrNull;
        if (serviceSection != null) {
          for (final recordElement in serviceSection.findElements('record')) {
            final recordData = UddfImportParsers.parseServiceRecord(
              recordElement,
            );
            if (recordData.isNotEmpty) {
              serviceRecords.add(recordData);
            }
          }
        }

        // Parse settings
        final settingsSection = submersionElement
            .findElements('settings')
            .firstOrNull;
        if (settingsSection != null) {
          for (final settingElement in settingsSection.findElements(
            'setting',
          )) {
            final key = settingElement.getAttribute('key');
            final value = settingElement.innerText.trim();
            if (key != null && value.isNotEmpty) {
              settings[key] = value;
            }
          }
        }

        // Parse tags
        final tagsSection = submersionElement.findElements('tags').firstOrNull;
        if (tagsSection != null) {
          for (final tagElement in tagsSection.findElements('tag')) {
            final tagData = UddfImportParsers.parseTag(tagElement);
            if (tagData.isNotEmpty) {
              tags.add(tagData);
            }
          }
        }

        // Parse custom dive types
        final diveTypesSection = submersionElement
            .findElements('divetypes')
            .firstOrNull;
        if (diveTypesSection != null) {
          for (final typeElement in diveTypesSection.findElements('divetype')) {
            final typeData = UddfImportParsers.parseDiveTypeElement(
              typeElement,
            );
            if (typeData.isNotEmpty) {
              customDiveTypes.add(typeData);
            }
          }
        }

        // Parse dive computers
        final computersSection = submersionElement
            .findElements('divecomputers')
            .firstOrNull;
        if (computersSection != null) {
          for (final computerElement in computersSection.findElements(
            'computer',
          )) {
            final computerData = UddfImportParsers.parseDiveComputer(
              computerElement,
            );
            if (computerData.isNotEmpty) {
              diveComputers.add(computerData);
            }
          }
        }

        // Parse equipment sets
        final setsSection = submersionElement
            .findElements('equipmentsets')
            .firstOrNull;
        if (setsSection != null) {
          for (final setElement in setsSection.findElements('set')) {
            final setData = UddfImportParsers.parseEquipmentSet(setElement);
            if (setData.isNotEmpty) {
              equipmentSets.add(setData);
            }
          }
        }

        // Parse courses
        final coursesSection = submersionElement
            .findElements('courses')
            .firstOrNull;
        if (coursesSection != null) {
          for (final courseElement in coursesSection.findElements('course')) {
            final courseData = UddfImportParsers.parseCourse(courseElement);
            if (courseData.isNotEmpty) {
              courses.add(courseData);
            }
          }
        }

        // Parse owner extended data (medical, emergency, insurance)
        final ownerExtSection = submersionElement
            .findElements('ownerextended')
            .firstOrNull;
        if (ownerExtSection != null && owner != null) {
          UddfImportParsers.parseOwnerExtended(ownerExtSection, owner);
        }

        // Parse trip extended data (resort/liveaboard names)
        final tripExtSection = submersionElement
            .findElements('tripextended')
            .firstOrNull;
        if (tripExtSection != null) {
          for (final tripExtElement in tripExtSection.findElements('trip')) {
            final tripRef = tripExtElement.getAttribute('tripref');
            if (tripRef != null && tripMap.containsKey(tripRef)) {
              UddfImportParsers.parseTripExtended(
                tripExtElement,
                tripMap[tripRef]!,
              );
            }
          }
        }
      }
    }

    return UddfImportResult(
      dives: dives,
      sites: sites,
      equipment: equipment,
      buddies: buddies,
      certifications: certifications,
      diveCenters: diveCenters,
      species: species,
      sightings: sightings,
      serviceRecords: serviceRecords,
      settings: settings,
      owner: owner,
      trips: trips,
      tags: tags,
      customDiveTypes: customDiveTypes,
      diveComputers: diveComputers,
      equipmentSets: equipmentSets,
      courses: courses,
    );
  }

  Map<String, dynamic> _parseFullSite(XmlElement siteElement) {
    // Parse base site fields using simple import service
    final baseSite = _parseUddfSite(siteElement);
    return UddfImportParsers.parseFullSite(siteElement, baseSite);
  }

  Map<String, dynamic> _parseUddfSite(XmlElement siteElement) {
    final site = <String, dynamic>{};

    site['name'] = UddfImportParsers.getElementText(siteElement, 'name');

    final geoElement = siteElement.findElements('geography').firstOrNull;
    if (geoElement != null) {
      final lat = UddfImportParsers.getElementText(geoElement, 'latitude');
      final lon = UddfImportParsers.getElementText(geoElement, 'longitude');
      if (lat != null && lon != null) {
        site['latitude'] = double.tryParse(lat);
        site['longitude'] = double.tryParse(lon);
      }
    }

    site['country'] = UddfImportParsers.getElementText(siteElement, 'country');
    site['region'] = UddfImportParsers.getElementText(siteElement, 'state');
    final minDepth = UddfImportParsers.getElementText(
      siteElement,
      'minimumdepth',
    );
    if (minDepth != null) {
      site['minDepth'] = double.tryParse(minDepth);
    }
    final maxDepth = UddfImportParsers.getElementText(
      siteElement,
      'maximumdepth',
    );
    if (maxDepth != null) {
      site['maxDepth'] = double.tryParse(maxDepth);
    }
    site['description'] = UddfImportParsers.getElementText(
      siteElement,
      'notes',
    );

    return site;
  }

  GasMix _parseUddfGasMix(XmlElement mixElement) {
    final o2Text = UddfImportParsers.getElementText(mixElement, 'o2');
    final heText = UddfImportParsers.getElementText(mixElement, 'he');

    // UDDF stores as fractions (0.21 for 21%)
    final o2 = o2Text != null ? (double.tryParse(o2Text) ?? 0.21) * 100 : 21.0;
    final he = heText != null ? (double.tryParse(heText) ?? 0.0) * 100 : 0.0;

    return GasMix(o2: o2, he: he);
  }

  Map<String, dynamic> _parseFullDive(
    XmlElement diveElement,
    Map<String, Map<String, dynamic>> sites,
    Map<String, Map<String, dynamic>> buddies,
    Map<String, GasMix> gasMixes,
    Map<String, Map<String, int>> decoModels,
    Map<String, Map<String, String>> diveComputers,
  ) {
    // Start with base dive parse (same logic as simple import)
    final diveData = _parseUddfDive(
      diveElement,
      sites,
      buddies,
      gasMixes,
      decoModels,
      diveComputers,
    );

    // Parse additional fields from informationbeforedive
    final beforeElement = diveElement
        .findElements('informationbeforedive')
        .firstOrNull;
    if (beforeElement != null) {
      diveData['diveMaster'] = UddfImportParsers.getElementText(
        beforeElement,
        'divemaster',
      );

      final diveType = UddfImportParsers.getElementText(
        beforeElement,
        'divetype',
      );
      if (diveType != null) {
        diveData['diveType'] = _parseDiveType(diveType);
      }

      final entryType = UddfImportParsers.getElementText(
        beforeElement,
        'entrytype',
      );
      if (entryType != null) {
        diveData['entryMethod'] = UddfImportParsers.parseEnumValue(
          entryType,
          enums.EntryMethod.values,
        );
      }

      // Parse dive mode
      final diveModeStr = UddfImportParsers.getElementText(
        beforeElement,
        'divemode',
      );
      if (diveModeStr != null) {
        diveData['diveMode'] = UddfImportParsers.parseEnumValue(
          diveModeStr,
          enums.DiveMode.values,
        );
      }

      // Parse planned dive flag
      final isPlanned = UddfImportParsers.getElementText(
        beforeElement,
        'isplanned',
      );
      if (isPlanned?.toLowerCase() == 'true') {
        diveData['isPlanned'] = true;
      }

      // Parse entry time
      final entryTime = UddfImportParsers.getElementText(
        beforeElement,
        'entrytime',
      );
      if (entryTime != null) {
        diveData['entryTime'] = DateTime.tryParse(entryTime);
      }

      // Parse altitude for altitude diving
      final altitudeText = UddfImportParsers.getElementText(
        beforeElement,
        'altitude',
      );
      if (altitudeText != null) {
        final altitudeMeters = double.tryParse(altitudeText);
        if (altitudeMeters != null && altitudeMeters > 0) {
          diveData['altitude'] = altitudeMeters;
        }
      }

      // Extract link references for trip, dive center, and buddies
      final buddyRefs = <String>[];
      final unmatchedBuddyNames = <String>[];
      for (final linkElement in beforeElement.findElements('link')) {
        final ref = linkElement.getAttribute('ref');
        if (ref != null) {
          if (ref.startsWith('trip_')) {
            diveData['tripRef'] = ref;
          } else if (ref.startsWith('center_')) {
            diveData['diveCenterRef'] = ref;
          } else if (ref.startsWith('course_')) {
            diveData['courseRef'] = ref;
          } else if (ref.startsWith('buddy_') || buddies.containsKey(ref)) {
            // Handle both our format (buddy_xxx) and other formats (e.g., Subsurface idp...)
            buddyRefs.add(ref);
          }
        }
      }

      // Also parse inline buddy elements in informationbeforedive
      for (final buddyElement in beforeElement.findElements('buddy')) {
        final personalElement = buddyElement
            .findElements('personal')
            .firstOrNull;
        if (personalElement != null) {
          final firstName = UddfImportParsers.getElementText(
            personalElement,
            'firstname',
          );
          final lastName = UddfImportParsers.getElementText(
            personalElement,
            'lastname',
          );
          final buddyName = [
            firstName,
            lastName,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
          if (buddyName.isNotEmpty) {
            // Find matching buddy record by name
            bool found = false;
            for (final entry in buddies.entries) {
              final recordName = entry.value['name'] as String?;
              if (recordName != null &&
                  recordName.toLowerCase() == buddyName.toLowerCase() &&
                  !buddyRefs.contains(entry.key)) {
                buddyRefs.add(entry.key);
                found = true;
                break;
              }
            }
            // Track unmatched names to create buddies during import
            if (!found && !unmatchedBuddyNames.contains(buddyName)) {
              unmatchedBuddyNames.add(buddyName);
            }
          }
        }
      }

      if (buddyRefs.isNotEmpty) {
        diveData['buddyRefs'] = buddyRefs;
      }
      if (unmatchedBuddyNames.isNotEmpty) {
        diveData['unmatchedBuddyNames'] = unmatchedBuddyNames;
      }
    }

    // Parse additional fields from informationafterdive
    final afterElement = diveElement
        .findElements('informationafterdive')
        .firstOrNull;
    if (afterElement != null) {
      final waterType = UddfImportParsers.getElementText(
        afterElement,
        'watertype',
      );
      if (waterType != null) {
        diveData['waterType'] = UddfImportParsers.parseEnumValue(
          waterType,
          enums.WaterType.values,
        );
      }

      final currentDir = UddfImportParsers.getElementText(
        afterElement,
        'currentdirection',
      );
      if (currentDir != null) {
        diveData['currentDirection'] = UddfImportParsers.parseEnumValue(
          currentDir,
          enums.CurrentDirection.values,
        );
      }

      final currentStrength = UddfImportParsers.getElementText(
        afterElement,
        'currentstrength',
      );
      if (currentStrength != null) {
        diveData['currentStrength'] = UddfImportParsers.parseEnumValue(
          currentStrength,
          enums.CurrentStrength.values,
        );
      }

      final swellHeight = UddfImportParsers.getElementText(
        afterElement,
        'swellheight',
      );
      if (swellHeight != null) {
        diveData['swellHeight'] = double.tryParse(swellHeight);
      }

      final exitType = UddfImportParsers.getElementText(
        afterElement,
        'exittype',
      );
      if (exitType != null) {
        diveData['exitMethod'] = UddfImportParsers.parseEnumValue(
          exitType,
          enums.EntryMethod.values,
        );
      }

      // Parse weight used
      final weightElement = afterElement.findElements('weightused').firstOrNull;
      if (weightElement != null) {
        final amount = UddfImportParsers.getElementText(
          weightElement,
          'amount',
        );
        if (amount != null) {
          diveData['weightAmount'] = double.tryParse(amount);
        }
        final weightType = UddfImportParsers.getElementText(
          weightElement,
          'type',
        );
        if (weightType != null) {
          diveData['weightType'] = UddfImportParsers.parseEnumValue(
            weightType,
            enums.WeightType.values,
          );
        }
      }

      // Parse sightings
      final sightingsElement = afterElement
          .findElements('sightings')
          .firstOrNull;
      if (sightingsElement != null) {
        final sightingsList = <Map<String, dynamic>>[];
        for (final sightingElement in sightingsElement.findElements(
          'sighting',
        )) {
          final sighting = <String, dynamic>{};
          sighting['speciesRef'] = sightingElement.getAttribute('speciesref');
          final countStr = sightingElement.getAttribute('count');
          sighting['count'] = countStr != null
              ? int.tryParse(countStr) ?? 1
              : 1;
          sighting['notes'] =
              UddfImportParsers.getElementText(sightingElement, 'notes') ?? '';
          sightingsList.add(sighting);
        }
        if (sightingsList.isNotEmpty) {
          diveData['sightings'] = sightingsList;
        }
      }

      // Parse tag references
      final tagsElement = afterElement.findElements('tags').firstOrNull;
      if (tagsElement != null) {
        final tagRefs = <String>[];
        for (final tagRefElement in tagsElement.findElements('tagref')) {
          final tagRef = tagRefElement.innerText.trim();
          if (tagRef.isNotEmpty) {
            tagRefs.add(tagRef);
          }
        }
        if (tagRefs.isNotEmpty) {
          diveData['tagRefs'] = tagRefs;
        }
      }

      // Parse inline buddy elements and match to buddy records
      // This handles dive computer exports that embed buddy info directly
      final existingBuddyRefs = (diveData['buddyRefs'] as List<String>?) ?? [];
      final existingUnmatched =
          (diveData['unmatchedBuddyNames'] as List<String>?) ?? [];
      final buddyRefs = List<String>.from(existingBuddyRefs);
      final unmatchedBuddyNames = List<String>.from(existingUnmatched);
      for (final buddyElement in afterElement.findElements('buddy')) {
        final personalElement = buddyElement
            .findElements('personal')
            .firstOrNull;
        if (personalElement != null) {
          final firstName = UddfImportParsers.getElementText(
            personalElement,
            'firstname',
          );
          final lastName = UddfImportParsers.getElementText(
            personalElement,
            'lastname',
          );
          final buddyName = [
            firstName,
            lastName,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
          if (buddyName.isNotEmpty) {
            // Find matching buddy record by name
            bool found = false;
            for (final entry in buddies.entries) {
              final recordName = entry.value['name'] as String?;
              if (recordName != null &&
                  recordName.toLowerCase() == buddyName.toLowerCase() &&
                  !buddyRefs.contains(entry.key)) {
                buddyRefs.add(entry.key);
                found = true;
                break;
              }
            }
            // Track unmatched names to create buddies during import
            if (!found && !unmatchedBuddyNames.contains(buddyName)) {
              unmatchedBuddyNames.add(buddyName);
            }
          }
        }
      }
      if (buddyRefs.isNotEmpty) {
        diveData['buddyRefs'] = buddyRefs;
      }
      if (unmatchedBuddyNames.isNotEmpty) {
        diveData['unmatchedBuddyNames'] = unmatchedBuddyNames;
      }

      // Parse isFavorite
      final isFavorite = UddfImportParsers.getElementText(
        afterElement,
        'isfavorite',
      );
      if (isFavorite?.toLowerCase() == 'true') {
        diveData['isFavorite'] = true;
      }

      // Parse additional weights (app-specific, beyond single weight)
      final weightsElement = afterElement.findElements('weights').firstOrNull;
      if (weightsElement != null) {
        final weightsList = <Map<String, dynamic>>[];
        for (final weightElement in weightsElement.findElements('weight')) {
          final weight = <String, dynamic>{};
          final amount = UddfImportParsers.getElementText(
            weightElement,
            'amount',
          );
          if (amount != null) {
            weight['amount'] = double.tryParse(amount);
          }
          final type = UddfImportParsers.getElementText(weightElement, 'type');
          if (type != null) {
            weight['type'] = UddfImportParsers.parseEnumValue(
              type,
              enums.WeightType.values,
            );
          }
          weight['notes'] =
              UddfImportParsers.getElementText(weightElement, 'notes') ?? '';
          weightsList.add(weight);
        }
        if (weightsList.isNotEmpty) {
          diveData['weights'] = weightsList;
        }
      }

      // Parse profile events (app-specific)
      final eventsElement = afterElement
          .findElements('profileevents')
          .firstOrNull;
      if (eventsElement != null) {
        final eventsList = <Map<String, dynamic>>[];
        for (final eventElement in eventsElement.findElements('event')) {
          final event = <String, dynamic>{};
          final time = UddfImportParsers.getElementText(eventElement, 'time');
          if (time != null) {
            event['timestamp'] = int.tryParse(time);
          }
          final eventType = UddfImportParsers.getElementText(
            eventElement,
            'eventtype',
          );
          if (eventType != null) {
            event['eventType'] = eventType;
          }
          final severity = UddfImportParsers.getElementText(
            eventElement,
            'severity',
          );
          if (severity != null) {
            event['severity'] = severity;
          }
          final depth = UddfImportParsers.getElementText(eventElement, 'depth');
          if (depth != null) {
            event['depth'] = double.tryParse(depth);
          }
          final value = UddfImportParsers.getElementText(eventElement, 'value');
          if (value != null) {
            event['value'] = double.tryParse(value);
          }
          event['description'] = UddfImportParsers.getElementText(
            eventElement,
            'description',
          );
          event['tankRef'] = UddfImportParsers.getElementText(
            eventElement,
            'tankref',
          );
          eventsList.add(event);
        }
        if (eventsList.isNotEmpty) {
          diveData['profileEvents'] = eventsList;
        }
      }

      // Parse gas switches
      final switchesElement = afterElement
          .findElements('gasswitches')
          .firstOrNull;
      if (switchesElement != null) {
        final switchesList = <Map<String, dynamic>>[];
        for (final gsElement in switchesElement.findElements('gasswitch')) {
          final gs = <String, dynamic>{};
          final time = UddfImportParsers.getElementText(gsElement, 'time');
          if (time != null) {
            gs['timestamp'] = int.tryParse(time);
          }
          final depth = UddfImportParsers.getElementText(gsElement, 'depth');
          if (depth != null) {
            gs['depth'] = double.tryParse(depth);
          }
          gs['tankRef'] = UddfImportParsers.getElementText(
            gsElement,
            'tankref',
          );
          gs['gasMix'] = UddfImportParsers.getElementText(gsElement, 'gasmix');
          final o2 = UddfImportParsers.getElementText(gsElement, 'o2fraction');
          if (o2 != null) {
            gs['o2Fraction'] = double.tryParse(o2);
          }
          final he = UddfImportParsers.getElementText(gsElement, 'hefraction');
          if (he != null) {
            gs['heFraction'] = double.tryParse(he);
          }
          switchesList.add(gs);
        }
        if (switchesList.isNotEmpty) {
          diveData['gasSwitches'] = switchesList;
        }
      }
    }

    // Parse rebreather section
    final rebreatherElement = diveElement
        .findElements('rebreather')
        .firstOrNull;
    if (rebreatherElement != null) {
      final diveMode = UddfImportParsers.getElementText(
        rebreatherElement,
        'divemode',
      );
      if (diveMode != null) {
        diveData['diveMode'] = UddfImportParsers.parseEnumValue(
          diveMode,
          enums.DiveMode.values,
        );
      }
      // CCR setpoints
      final spLow = UddfImportParsers.getElementText(
        rebreatherElement,
        'setpointlow',
      );
      if (spLow != null) diveData['setpointLow'] = double.tryParse(spLow);
      final spHigh = UddfImportParsers.getElementText(
        rebreatherElement,
        'setpointhigh',
      );
      if (spHigh != null) diveData['setpointHigh'] = double.tryParse(spHigh);
      final spDeco = UddfImportParsers.getElementText(
        rebreatherElement,
        'setpointdeco',
      );
      if (spDeco != null) diveData['setpointDeco'] = double.tryParse(spDeco);
      // SCR config
      final scrType = UddfImportParsers.getElementText(
        rebreatherElement,
        'scrtype',
      );
      if (scrType != null) {
        diveData['scrType'] = UddfImportParsers.parseEnumValue(
          scrType,
          enums.ScrType.values,
        );
      }
      final injRate = UddfImportParsers.getElementText(
        rebreatherElement,
        'scrinjectionrate',
      );
      if (injRate != null) {
        diveData['scrInjectionRate'] = double.tryParse(injRate);
      }
      final addRatio = UddfImportParsers.getElementText(
        rebreatherElement,
        'scradditionratio',
      );
      if (addRatio != null) {
        diveData['scrAdditionRatio'] = double.tryParse(addRatio);
      }
      diveData['scrOrificeSize'] = UddfImportParsers.getElementText(
        rebreatherElement,
        'scrorificesize',
      );
      final vo2 = UddfImportParsers.getElementText(
        rebreatherElement,
        'assumedvo2',
      );
      if (vo2 != null) diveData['assumedVo2'] = double.tryParse(vo2);
      // Diluent
      final dilO2 = UddfImportParsers.getElementText(
        rebreatherElement,
        'diluento2',
      );
      if (dilO2 != null) diveData['diluentO2'] = double.tryParse(dilO2);
      final dilHe = UddfImportParsers.getElementText(
        rebreatherElement,
        'diluenthe',
      );
      if (dilHe != null) diveData['diluentHe'] = double.tryParse(dilHe);
      // Loop FO2
      final loopMin = UddfImportParsers.getElementText(
        rebreatherElement,
        'loopo2min',
      );
      if (loopMin != null) diveData['loopO2Min'] = double.tryParse(loopMin);
      final loopMax = UddfImportParsers.getElementText(
        rebreatherElement,
        'loopo2max',
      );
      if (loopMax != null) diveData['loopO2Max'] = double.tryParse(loopMax);
      final loopAvg = UddfImportParsers.getElementText(
        rebreatherElement,
        'loopo2avg',
      );
      if (loopAvg != null) diveData['loopO2Avg'] = double.tryParse(loopAvg);
      // Loop/scrubber
      final loopVol = UddfImportParsers.getElementText(
        rebreatherElement,
        'loopvolume',
      );
      if (loopVol != null) diveData['loopVolume'] = double.tryParse(loopVol);
      diveData['scrubberType'] = UddfImportParsers.getElementText(
        rebreatherElement,
        'scrubbertype',
      );
      final scrubDur = UddfImportParsers.getElementText(
        rebreatherElement,
        'scrubberdurationminutes',
      );
      if (scrubDur != null) {
        diveData['scrubberDurationMinutes'] = int.tryParse(scrubDur);
      }
      final scrubRem = UddfImportParsers.getElementText(
        rebreatherElement,
        'scrubberremainingminutes',
      );
      if (scrubRem != null) {
        diveData['scrubberRemainingMinutes'] = int.tryParse(scrubRem);
      }
    }

    // Parse setpoint and ppO2 from waypoints (sensor readings)
    final samplesElement = diveElement.findElements('samples').firstOrNull;
    if (samplesElement != null) {
      final existingProfile =
          diveData['profile'] as List<Map<String, dynamic>>?;
      if (existingProfile != null) {
        // Enrich existing profile points with setpoint/ppO2
        int idx = 0;
        for (final waypoint in samplesElement.findElements('waypoint')) {
          final sp = UddfImportParsers.getElementText(waypoint, 'setpoint');
          final ppo2 = UddfImportParsers.getElementText(waypoint, 'ppo2');
          if ((sp != null || ppo2 != null) && idx < existingProfile.length) {
            if (sp != null) {
              existingProfile[idx]['setpoint'] = double.tryParse(sp);
            }
            if (ppo2 != null) {
              existingProfile[idx]['ppO2'] = double.tryParse(ppo2);
            }
          }
          idx++;
        }
      }
    }

    return diveData;
  }

  Map<String, dynamic> _parseUddfDive(
    XmlElement diveElement,
    Map<String, Map<String, dynamic>> sites,
    Map<String, Map<String, dynamic>> buddies,
    Map<String, GasMix> gasMixes,
    Map<String, Map<String, int>> decoModels,
    Map<String, Map<String, String>> diveComputers,
  ) {
    final diveData = <String, dynamic>{};
    final buddyNames = <String>[];

    // Parse information before dive
    final beforeElement = diveElement
        .findElements('informationbeforedive')
        .firstOrNull;
    if (beforeElement != null) {
      final dateTimeText = UddfImportParsers.getElementText(
        beforeElement,
        'datetime',
      );
      if (dateTimeText != null) {
        diveData['dateTime'] = DateTime.tryParse(dateTimeText);
      }

      final diveNumText = UddfImportParsers.getElementText(
        beforeElement,
        'divenumber',
      );
      if (diveNumText != null) {
        diveData['diveNumber'] = int.tryParse(diveNumText);
      }

      final airTempText = UddfImportParsers.getElementText(
        beforeElement,
        'airtemperature',
      );
      if (airTempText != null) {
        // UDDF stores temps in Kelvin
        final kelvin = double.tryParse(airTempText);
        if (kelvin != null) {
          final celsius = kelvin - 273.15;
          // Validate reasonable air temperature range (-40C to 50C)
          // Shearwater may incorrectly encode Fahrenheit as Kelvin (adding 273.15 to F instead of C)
          if (celsius >= -40 && celsius <= 50) {
            diveData['airTemp'] = celsius;
          }
        }
      }

      // Check for atmospheric/surface pressure (standard UDDF uses 'atmosphericpressure', Shearwater uses 'surfacepressure')
      var atmPressureText = UddfImportParsers.getElementText(
        beforeElement,
        'atmosphericpressure',
      );
      atmPressureText ??= UddfImportParsers.getElementText(
        beforeElement,
        'surfacepressure',
      );
      if (atmPressureText != null) {
        // UDDF stores pressure in Pascal, convert to bar
        final pascal = double.tryParse(atmPressureText);
        if (pascal != null) {
          diveData['surfacePressure'] = pascal / 100000;
        }
      }

      // Parse surface interval before dive
      final surfaceIntervalElement = beforeElement
          .findElements('surfaceintervalbeforedive')
          .firstOrNull;
      if (surfaceIntervalElement != null) {
        final passedTimeText = UddfImportParsers.getElementText(
          surfaceIntervalElement,
          'passedtime',
        );
        if (passedTimeText != null) {
          final seconds = int.tryParse(passedTimeText);
          if (seconds != null && seconds > 0) {
            diveData['surfaceInterval'] = Duration(seconds: seconds);
          }
        }
      }

      // Parse equipment used (e.g., lead weight, dive computer, equipment refs)
      final equipmentElement = beforeElement
          .findElements('equipmentused')
          .firstOrNull;
      if (equipmentElement != null) {
        final leadText = UddfImportParsers.getElementText(
          equipmentElement,
          'leadquantity',
        );
        if (leadText != null) {
          final leadKg = double.tryParse(leadText);
          if (leadKg != null) {
            diveData['weightUsed'] = leadKg;
          }
        }

        // Parse equipment references
        final equipmentRefs = <String>[];
        for (final equipRef in equipmentElement.findElements('equipmentref')) {
          final ref = equipRef.innerText.trim();
          if (ref.isNotEmpty) {
            equipmentRefs.add(ref);
          }
        }
        if (equipmentRefs.isNotEmpty) {
          diveData['equipmentRefs'] = equipmentRefs;
        }
      }

      // Get all linked references (can be sites, buddies, decomodels, or dive computers)
      for (final linkElement in beforeElement.findElements('link')) {
        final ref = linkElement.getAttribute('ref');
        if (ref != null) {
          // Check if it's a site reference
          if (sites.containsKey(ref)) {
            diveData['site'] = sites[ref];
          }
          // Check if it's a buddy reference
          else if (buddies.containsKey(ref)) {
            final buddyName = buddies[ref]?['name'] as String?;
            if (buddyName != null && buddyName.isNotEmpty) {
              buddyNames.add(buddyName);
            }
          }
          // Check if it's a deco model reference (gradient factors)
          else if (decoModels.containsKey(ref)) {
            final model = decoModels[ref]!;
            if (model['gfLow'] != null && model['gfLow']! > 0) {
              diveData['gradientFactorLow'] = model['gfLow'];
            }
            if (model['gfHigh'] != null && model['gfHigh']! > 0) {
              diveData['gradientFactorHigh'] = model['gfHigh'];
            }
          }
          // Check if it's a dive computer reference
          else if (diveComputers.containsKey(ref)) {
            final computer = diveComputers[ref]!;
            if (computer['model']?.isNotEmpty == true) {
              diveData['diveComputerModel'] = computer['model'];
            }
            if (computer['serial']?.isNotEmpty == true) {
              diveData['diveComputerSerial'] = computer['serial'];
            }
            if (computer['firmware']?.isNotEmpty == true) {
              diveData['diveComputerFirmware'] = computer['firmware'];
            }
          }
        }
      }

      // Also check equipmentused for dive computer links (Shearwater style)
      if (equipmentElement != null) {
        for (final linkElement in equipmentElement.findElements('link')) {
          final ref = linkElement.getAttribute('ref');
          if (ref != null && diveComputers.containsKey(ref)) {
            final computer = diveComputers[ref]!;
            if (computer['model']?.isNotEmpty == true) {
              diveData['diveComputerModel'] = computer['model'];
            }
            if (computer['serial']?.isNotEmpty == true) {
              diveData['diveComputerSerial'] = computer['serial'];
            }
            if (computer['firmware']?.isNotEmpty == true) {
              diveData['diveComputerFirmware'] = computer['firmware'];
            }
          }
        }
      }
    }

    // Parse tank data
    final tanks = <Map<String, dynamic>>[];
    for (final tankDataElement in diveElement.findElements('tankdata')) {
      final tankInfo = <String, dynamic>{};

      // Capture tank ID for reference mapping (used by waypoint tankpressure refs)
      final tankId = tankDataElement.getAttribute('id');
      if (tankId != null) {
        tankInfo['uddfTankId'] = tankId;
      }

      // Get tank volume (in liters)
      final volumeText = UddfImportParsers.getElementText(
        tankDataElement,
        'tankvolume',
      );
      if (volumeText != null) {
        tankInfo['volume'] = double.tryParse(volumeText);
      }

      // Get linked gas mix
      final mixLink = tankDataElement.findElements('link').firstOrNull;
      if (mixLink != null) {
        final mixRef = mixLink.getAttribute('ref');
        if (mixRef != null && gasMixes.containsKey(mixRef)) {
          tankInfo['gasMix'] = gasMixes[mixRef];
        }
      }

      // Get start/end pressure if available
      final startPressureText = UddfImportParsers.getElementText(
        tankDataElement,
        'tankpressurebegin',
      );
      if (startPressureText != null) {
        // UDDF stores in Pascal, convert to bar
        final pascal = double.tryParse(startPressureText);
        if (pascal != null) {
          tankInfo['startPressure'] = (pascal / 100000).round();
        }
      }

      final endPressureText = UddfImportParsers.getElementText(
        tankDataElement,
        'tankpressureend',
      );
      if (endPressureText != null) {
        final pascal = double.tryParse(endPressureText);
        if (pascal != null) {
          tankInfo['endPressure'] = (pascal / 100000).round();
        }
      }

      // Get tank name
      final tankName = UddfImportParsers.getElementText(
        tankDataElement,
        'tankname',
      );
      if (tankName != null && tankName.isNotEmpty) {
        tankInfo['name'] = tankName;
      }

      // Get working pressure
      final workingPressureText = UddfImportParsers.getElementText(
        tankDataElement,
        'tankworkingpressure',
      );
      if (workingPressureText != null) {
        final pascal = double.tryParse(workingPressureText);
        if (pascal != null) {
          tankInfo['workingPressure'] = (pascal / 100000).round();
        }
      }

      // Get tank role
      final tankRole = UddfImportParsers.getElementText(
        tankDataElement,
        'tankrole',
      );
      if (tankRole != null && tankRole.isNotEmpty) {
        tankInfo['role'] = tankRole;
      }

      // Get tank material
      final tankMaterial = UddfImportParsers.getElementText(
        tankDataElement,
        'tankmaterial',
      );
      if (tankMaterial != null && tankMaterial.isNotEmpty) {
        tankInfo['material'] = tankMaterial;
      }

      // Get tank order
      final tankOrder = UddfImportParsers.getElementText(
        tankDataElement,
        'tankorder',
      );
      if (tankOrder != null) {
        tankInfo['order'] = int.tryParse(tankOrder) ?? 0;
      }

      // Validate tank data before adding
      final startPressure = tankInfo['startPressure'] as int?;
      final endPressure = tankInfo['endPressure'] as int?;
      final volume = tankInfo['volume'] as double?;
      final workingPressure = tankInfo['workingPressure'] as int?;

      // Check if pressure data is valid (not both zero or nonsensical)
      final hasValidPressure =
          startPressure != null &&
          endPressure != null &&
          startPressure > 10 && // Minimum reasonable start pressure (10 bar)
          startPressure >= endPressure; // Start should be >= end

      // Only add tank if it has meaningful and valid data:
      // - Has valid pressure data (tank was actually used with realistic values)
      // - Or has volume with working pressure (physical tank specification)
      // - Or has a UDDF ID (might be referenced by waypoint pressure data)
      // Tanks with zero pressures or only gas mix references are often
      // placeholders from dive computers and should be skipped
      final hasUddfId = tankInfo['uddfTankId'] != null;
      final hasMeaningfulData =
          hasValidPressure ||
          (volume != null && volume > 0) ||
          (workingPressure != null && workingPressure > 0) ||
          hasUddfId; // Tank might be referenced by waypoint pressures

      // Skip tanks with both pressures at 0 or very low (unusable data)
      // But keep tanks with UDDF IDs as they may have waypoint pressure data
      final hasBadPressureData =
          !hasUddfId &&
          startPressure != null &&
          endPressure != null &&
          startPressure <= 10 &&
          endPressure <= 10;

      if (hasMeaningfulData && !hasBadPressureData) {
        tanks.add(tankInfo);
      }
    }

    // If no tanks with meaningful data found, create a default tank from first gas mix
    if (tanks.isEmpty) {
      for (final tankDataElement in diveElement.findElements('tankdata')) {
        final mixLink = tankDataElement.findElements('link').firstOrNull;
        if (mixLink != null) {
          final mixRef = mixLink.getAttribute('ref');
          if (mixRef != null && gasMixes.containsKey(mixRef)) {
            tanks.add({'gasMix': gasMixes[mixRef]});
            break;
          }
        }
      }
    }

    // Build mapping from UDDF tank ref IDs to final tank indices
    // (after filtering, so indices match the actual tanks list order)
    final tankRefToIndex = <String, int>{};
    for (var i = 0; i < tanks.length; i++) {
      final uddfTankId = tanks[i]['uddfTankId'] as String?;
      if (uddfTankId != null) {
        tankRefToIndex[uddfTankId] = i;
      }
    }

    if (tanks.isNotEmpty) {
      diveData['tanks'] = tanks;
    }

    // Parse samples (dive profile)
    final samplesElement = diveElement.findElements('samples').firstOrNull;
    if (samplesElement != null) {
      final profile = <Map<String, dynamic>>[];
      GasMix? currentMix;

      for (final waypoint in samplesElement.findElements('waypoint')) {
        final point = <String, dynamic>{};

        final timeText = UddfImportParsers.getElementText(waypoint, 'divetime');
        if (timeText != null) {
          point['timestamp'] = int.tryParse(timeText) ?? 0;
        }

        final depthText = UddfImportParsers.getElementText(waypoint, 'depth');
        if (depthText != null) {
          point['depth'] = double.tryParse(depthText) ?? 0.0;
        }

        final tempText = UddfImportParsers.getElementText(
          waypoint,
          'temperature',
        );
        if (tempText != null) {
          final kelvin = double.tryParse(tempText);
          if (kelvin != null) {
            final celsius = kelvin - 273.15;
            // Validate reasonable water temperature range (-2C to 40C)
            if (celsius >= -2 && celsius <= 40) {
              point['temperature'] = celsius;
            }
          }
        }

        // Parse tank pressure(s) with optional tank reference for multi-tank support
        // UDDF can have multiple tankpressure elements per waypoint (one per tank)
        final tankPressureElements = waypoint.findElements('tankpressure');
        final allTankPressures = <Map<String, dynamic>>[];

        for (final tankPressureElement in tankPressureElements) {
          final pressureText = tankPressureElement.descendants
              .whereType<XmlText>()
              .map((node) => node.value)
              .join()
              .trim();
          // UDDF stores pressure in Pascal, convert to bar
          final pascal = double.tryParse(pressureText);
          if (pascal != null) {
            final pressure = pascal / 100000;

            // Extract tank reference to determine which tank this pressure belongs to
            final tankRef = tankPressureElement.getAttribute('ref');
            int tankIdx;
            if (tankRef != null && tankRefToIndex.containsKey(tankRef)) {
              tankIdx = tankRefToIndex[tankRef]!;
            } else {
              // Default to primary tank (index 0) when no ref attribute
              tankIdx = 0;
            }

            allTankPressures.add({'pressure': pressure, 'tankIndex': tankIdx});

            // Store first tank's pressure in legacy fields for backward compatibility
            if (!point.containsKey('pressure')) {
              point['pressure'] = pressure;
              point['tankIndex'] = tankIdx;
            }
          }
        }

        // Store all tank pressures for visualization and analysis
        if (allTankPressures.isNotEmpty) {
          point['allTankPressures'] = allTankPressures;
        }

        // Get heart rate
        final heartRateText = UddfImportParsers.getElementText(
          waypoint,
          'heartrate',
        );
        if (heartRateText != null) {
          point['heartRate'] = int.tryParse(heartRateText);
        }

        // Check for gas switch
        final switchMix = waypoint.findElements('switchmix').firstOrNull;
        if (switchMix != null) {
          final mixRef = switchMix.getAttribute('ref');
          if (mixRef != null && gasMixes.containsKey(mixRef)) {
            currentMix = gasMixes[mixRef];
          }
        }

        if (point.containsKey('timestamp') && point.containsKey('depth')) {
          profile.add(point);
        }
      }

      // Interpolate sparse temperature data (common in Subsurface exports)
      // Some dive software only records temperature at certain intervals or at dive start
      if (profile.isNotEmpty) {
        _interpolateProfileTemperatures(profile);
      }

      if (profile.isNotEmpty) {
        diveData['profile'] = profile;
      }
      // Use gas mix from samples if no tank data was found
      if (currentMix != null && !diveData.containsKey('tanks')) {
        diveData['gasMix'] = currentMix;
      }
    }

    // Parse information after dive
    final afterElement = diveElement
        .findElements('informationafterdive')
        .firstOrNull;
    if (afterElement != null) {
      final maxDepthText = UddfImportParsers.getElementText(
        afterElement,
        'greatestdepth',
      );
      if (maxDepthText != null) {
        diveData['maxDepth'] = double.tryParse(maxDepthText);
      }

      final avgDepthText = UddfImportParsers.getElementText(
        afterElement,
        'averagedepth',
      );
      if (avgDepthText != null) {
        diveData['avgDepth'] = double.tryParse(avgDepthText);
      }

      // UDDF diveduration is total dive time (runtime), not bottom time
      final durationText = UddfImportParsers.getElementText(
        afterElement,
        'diveduration',
      );
      if (durationText != null) {
        final seconds = int.tryParse(durationText);
        if (seconds != null) {
          diveData['runtime'] = Duration(seconds: seconds);
        }
      }

      final waterTempText = UddfImportParsers.getElementText(
        afterElement,
        'lowesttemperature',
      );
      if (waterTempText != null) {
        final kelvin = double.tryParse(waterTempText);
        if (kelvin != null) {
          final celsius = kelvin - 273.15;
          // Validate reasonable water temperature range (-2C to 40C)
          if (celsius >= -2 && celsius <= 40) {
            diveData['waterTemp'] = celsius;
          }
        }
      }

      // Fallback: extract water temp from profile if not found in lowesttemperature
      // Some dive log software (like Subsurface) only stores temp in waypoints
      if (!diveData.containsKey('waterTemp')) {
        final profile = diveData['profile'] as List<Map<String, dynamic>>?;
        if (profile != null && profile.isNotEmpty) {
          // Find the lowest temperature in the profile (water temp at depth)
          double? minTemp;
          for (final point in profile) {
            final temp = point['temperature'] as double?;
            // Validate reasonable water temperature range (-2C to 40C)
            if (temp != null &&
                temp >= -2 &&
                temp <= 40 &&
                (minTemp == null || temp < minTemp)) {
              minTemp = temp;
            }
          }
          if (minTemp != null) {
            diveData['waterTemp'] = minTemp;
          }
        }
      }

      final visibilityText = UddfImportParsers.getElementText(
        afterElement,
        'visibility',
      );
      if (visibilityText != null) {
        diveData['visibility'] = _parseUddfVisibility(visibilityText);
      }

      // Parse rating
      final ratingElement = afterElement.findElements('rating').firstOrNull;
      if (ratingElement != null) {
        final ratingValue = UddfImportParsers.getElementText(
          ratingElement,
          'ratingvalue',
        );
        if (ratingValue != null) {
          diveData['rating'] = int.tryParse(ratingValue);
        }
      }

      // Parse notes (try nested <para> first, then direct text content)
      final notesElement = afterElement.findElements('notes').firstOrNull;
      if (notesElement != null) {
        final para = UddfImportParsers.getElementText(notesElement, 'para');
        if (para != null) {
          diveData['notes'] = para;
        } else {
          // Fallback: read direct text content if no <para> child
          final directText = notesElement.innerText.trim();
          if (directText.isNotEmpty) {
            diveData['notes'] = directText;
          }
        }
      }

      // Parse buddy from informationafterdive (backup if not found in links)
      if (buddyNames.isEmpty) {
        final buddyElement = afterElement.findElements('buddy').firstOrNull;
        if (buddyElement != null) {
          final personalElement = buddyElement
              .findElements('personal')
              .firstOrNull;
          if (personalElement != null) {
            final firstName = UddfImportParsers.getElementText(
              personalElement,
              'firstname',
            );
            final lastName = UddfImportParsers.getElementText(
              personalElement,
              'lastname',
            );
            final buddyName = [
              firstName,
              lastName,
            ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
            if (buddyName.isNotEmpty) {
              buddyNames.add(buddyName);
            }
          }
        }
      }
    }

    // Final fallback: extract water temp from profile if still not set
    // This handles cases where there's no informationafterdive element
    if (!diveData.containsKey('waterTemp')) {
      final profile = diveData['profile'] as List<Map<String, dynamic>>?;
      if (profile != null && profile.isNotEmpty) {
        double? minTemp;
        for (final point in profile) {
          final temp = point['temperature'] as double?;
          // Validate reasonable water temperature range (-2C to 40C)
          if (temp != null &&
              temp >= -2 &&
              temp <= 40 &&
              (minTemp == null || temp < minTemp)) {
            minTemp = temp;
          }
        }
        if (minTemp != null) {
          diveData['waterTemp'] = minTemp;
        }
      }
    }

    // Set buddy names (join multiple buddies with comma)
    if (buddyNames.isNotEmpty) {
      diveData['buddy'] = buddyNames.join(', ');
    }

    return diveData;
  }

  enums.Visibility _parseUddfVisibility(String value) {
    final meters = double.tryParse(value) ?? 0;
    if (meters >= 30) {
      return enums.Visibility.excellent;
    } else if (meters >= 15) {
      return enums.Visibility.good;
    } else if (meters >= 5) {
      return enums.Visibility.moderate;
    } else if (meters > 0) {
      return enums.Visibility.poor;
    }
    return enums.Visibility.unknown;
  }

  /// Interpolates sparse temperature data across profile points.
  ///
  /// Some dive software (e.g., Subsurface) only records temperature at the start
  /// of the dive or at sparse intervals. This method fills in missing temperature
  /// values by interpolating between known readings, or forward-filling if there's
  /// only one reading.
  ///
  /// This is done in-place on the profile list.
  void _interpolateProfileTemperatures(List<Map<String, dynamic>> profile) {
    // Find all points with temperature data
    final tempPoints = <int, double>{};
    for (var i = 0; i < profile.length; i++) {
      final temp = profile[i]['temperature'] as double?;
      if (temp != null) {
        tempPoints[i] = temp;
      }
    }

    // No temperature data at all - nothing to do
    if (tempPoints.isEmpty) return;

    // Only one temperature point - forward-fill to all points
    if (tempPoints.length == 1) {
      final singleTemp = tempPoints.values.first;
      for (var i = 0; i < profile.length; i++) {
        profile[i]['temperature'] = singleTemp;
      }
      return;
    }

    // Multiple temperature points - interpolate between them
    final sortedIndices = tempPoints.keys.toList()..sort();

    for (var i = 0; i < profile.length; i++) {
      if (tempPoints.containsKey(i)) continue; // Already has temperature

      // Find surrounding temperature points
      int? beforeIdx;
      int? afterIdx;

      for (final idx in sortedIndices) {
        if (idx < i) {
          beforeIdx = idx;
        } else if (idx > i) {
          afterIdx = idx;
          break;
        }
      }

      if (beforeIdx != null && afterIdx != null) {
        // Interpolate between two known points
        final beforeTemp = tempPoints[beforeIdx]!;
        final afterTemp = tempPoints[afterIdx]!;
        final beforeTimestamp = profile[beforeIdx]['timestamp'] as int;
        final afterTimestamp = profile[afterIdx]['timestamp'] as int;
        final currentTimestamp = profile[i]['timestamp'] as int;

        // Linear interpolation based on timestamp
        final ratio =
            (currentTimestamp - beforeTimestamp) /
            (afterTimestamp - beforeTimestamp);
        final interpolatedTemp = beforeTemp + (afterTemp - beforeTemp) * ratio;
        profile[i]['temperature'] = interpolatedTemp;
      } else if (beforeIdx != null) {
        // After last known temp - forward-fill
        profile[i]['temperature'] = tempPoints[beforeIdx]!;
      } else if (afterIdx != null) {
        // Before first known temp - backward-fill
        profile[i]['temperature'] = tempPoints[afterIdx]!;
      }
    }
  }

  String _parseDiveType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('training') || lower.contains('course')) {
      return 'training';
    } else if (lower.contains('night')) {
      return 'night';
    } else if (lower.contains('deep')) {
      return 'deep';
    } else if (lower.contains('wreck')) {
      return 'wreck';
    } else if (lower.contains('drift')) {
      return 'drift';
    } else if (lower.contains('cave') || lower.contains('cavern')) {
      return 'cave';
    } else if (lower.contains('tech')) {
      return 'technical';
    } else if (lower.contains('free')) {
      return 'freedive';
    } else if (lower.contains('ice')) {
      return 'ice';
    } else if (lower.contains('altitude')) {
      return 'altitude';
    } else if (lower.contains('shore')) {
      return 'shore';
    } else if (lower.contains('boat')) {
      return 'boat';
    } else if (lower.contains('liveaboard')) {
      return 'liveaboard';
    }
    return 'recreational';
  }
}
