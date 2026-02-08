import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Handles simple UDDF dive import.
///
/// Parses standard UDDF elements (diver, divesite, gasdefinitions,
/// decomodel, profiledata) and returns dive and site maps.
class UddfImportService {
  Future<Map<String, List<Map<String, dynamic>>>> importDivesFromUddf(
    String uddfContent,
  ) async {
    final document = XmlDocument.parse(uddfContent);
    // Use rootElement instead of findElements to handle XML namespaces properly
    final uddfElement = document.rootElement;
    if (uddfElement.name.local != 'uddf') {
      throw const FormatException(
        'Invalid UDDF file: missing uddf root element',
      );
    }

    // Parse buddies from diver section
    final buddies = <String, Map<String, dynamic>>{};
    final diverElement = uddfElement.findElements('diver').firstOrNull;
    if (diverElement != null) {
      for (final buddyElement in diverElement.findElements('buddy')) {
        final buddyId = buddyElement.getAttribute('id');
        if (buddyId != null) {
          final personalElement = buddyElement
              .findElements('personal')
              .firstOrNull;
          if (personalElement != null) {
            final firstName = _getElementText(personalElement, 'firstname');
            final lastName = _getElementText(personalElement, 'lastname');
            final buddyName = [
              firstName,
              lastName,
            ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
            if (buddyName.isNotEmpty) {
              buddies[buddyId] = {'name': buddyName};
            }
          }
        }
      }
    }

    // Parse dive sites
    final sites = <String, Map<String, dynamic>>{};
    final divesiteElement = uddfElement.findElements('divesite').firstOrNull;
    if (divesiteElement != null) {
      for (final siteElement in divesiteElement.findElements('site')) {
        final siteId = siteElement.getAttribute('id');
        if (siteId != null) {
          final siteData = _parseUddfSite(siteElement);
          siteData['uddfId'] = siteId; // Keep track of original ID for linking
          sites[siteId] = siteData;
        }
      }
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
      // Check for Buhlmann model with gradient factors
      for (final buehlmannElement in decoModelElement.findElements(
        'buehlmann',
      )) {
        final modelId = buehlmannElement.getAttribute('id');
        if (modelId != null) {
          final gfLowText = _getElementText(
            buehlmannElement,
            'gradientfactorlow',
          );
          final gfHighText = _getElementText(
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
    final diveComputers = <String, Map<String, String>>{};
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
              final model = _getElementText(computerElement, 'model');
              final serial = _getElementText(computerElement, 'serialnumber');
              diveComputers[computerId] = {
                'model': model ?? '',
                'serial': serial ?? '',
              };
            }
          }
        }
      }
    }

    // Parse dives from profile data
    final dives = <Map<String, dynamic>>[];
    final profileDataElement = uddfElement
        .findElements('profiledata')
        .firstOrNull;
    if (profileDataElement != null) {
      for (final repGroup in profileDataElement.findElements(
        'repetitiongroup',
      )) {
        for (final diveElement in repGroup.findElements('dive')) {
          final diveData = _parseUddfDive(
            diveElement,
            sites,
            buddies,
            gasMixes,
            decoModels,
            diveComputers,
          );
          if (diveData.isNotEmpty) {
            dives.add(diveData);
          }
        }
      }
    }

    // Return both dives and unique sites
    return {'dives': dives, 'sites': sites.values.toList()};
  }

  Map<String, dynamic> _parseUddfSite(XmlElement siteElement) {
    final site = <String, dynamic>{};

    site['name'] = _getElementText(siteElement, 'name');

    final geoElement = siteElement.findElements('geography').firstOrNull;
    if (geoElement != null) {
      final lat = _getElementText(geoElement, 'latitude');
      final lon = _getElementText(geoElement, 'longitude');
      if (lat != null && lon != null) {
        site['latitude'] = double.tryParse(lat);
        site['longitude'] = double.tryParse(lon);
      }
    }

    site['country'] = _getElementText(siteElement, 'country');
    site['region'] = _getElementText(siteElement, 'state');
    final minDepth = _getElementText(siteElement, 'minimumdepth');
    if (minDepth != null) {
      site['minDepth'] = double.tryParse(minDepth);
    }
    final maxDepth = _getElementText(siteElement, 'maximumdepth');
    if (maxDepth != null) {
      site['maxDepth'] = double.tryParse(maxDepth);
    }
    site['description'] = _getElementText(siteElement, 'notes');

    return site;
  }

  GasMix _parseUddfGasMix(XmlElement mixElement) {
    final o2Text = _getElementText(mixElement, 'o2');
    final heText = _getElementText(mixElement, 'he');

    // UDDF stores as fractions (0.21 for 21%)
    final o2 = o2Text != null ? (double.tryParse(o2Text) ?? 0.21) * 100 : 21.0;
    final he = heText != null ? (double.tryParse(heText) ?? 0.0) * 100 : 0.0;

    return GasMix(o2: o2, he: he);
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
      final dateTimeText = _getElementText(beforeElement, 'datetime');
      if (dateTimeText != null) {
        diveData['dateTime'] = DateTime.tryParse(dateTimeText);
      }

      final diveNumText = _getElementText(beforeElement, 'divenumber');
      if (diveNumText != null) {
        diveData['diveNumber'] = int.tryParse(diveNumText);
      }

      final airTempText = _getElementText(beforeElement, 'airtemperature');
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
      var atmPressureText = _getElementText(
        beforeElement,
        'atmosphericpressure',
      );
      atmPressureText ??= _getElementText(beforeElement, 'surfacepressure');
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
        final passedTimeText = _getElementText(
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
        final leadText = _getElementText(equipmentElement, 'leadquantity');
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
      final volumeText = _getElementText(tankDataElement, 'tankvolume');
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
      final startPressureText = _getElementText(
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

      final endPressureText = _getElementText(
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
      final tankName = _getElementText(tankDataElement, 'tankname');
      if (tankName != null && tankName.isNotEmpty) {
        tankInfo['name'] = tankName;
      }

      // Get working pressure
      final workingPressureText = _getElementText(
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
      final tankRole = _getElementText(tankDataElement, 'tankrole');
      if (tankRole != null && tankRole.isNotEmpty) {
        tankInfo['role'] = tankRole;
      }

      // Get tank material
      final tankMaterial = _getElementText(tankDataElement, 'tankmaterial');
      if (tankMaterial != null && tankMaterial.isNotEmpty) {
        tankInfo['material'] = tankMaterial;
      }

      // Get tank order
      final tankOrder = _getElementText(tankDataElement, 'tankorder');
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

        final timeText = _getElementText(waypoint, 'divetime');
        if (timeText != null) {
          point['timestamp'] = int.tryParse(timeText) ?? 0;
        }

        final depthText = _getElementText(waypoint, 'depth');
        if (depthText != null) {
          point['depth'] = double.tryParse(depthText) ?? 0.0;
        }

        final tempText = _getElementText(waypoint, 'temperature');
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
        final heartRateText = _getElementText(waypoint, 'heartrate');
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
      final maxDepthText = _getElementText(afterElement, 'greatestdepth');
      if (maxDepthText != null) {
        diveData['maxDepth'] = double.tryParse(maxDepthText);
      }

      final avgDepthText = _getElementText(afterElement, 'averagedepth');
      if (avgDepthText != null) {
        diveData['avgDepth'] = double.tryParse(avgDepthText);
      }

      // UDDF diveduration is total dive time (runtime), not bottom time
      final durationText = _getElementText(afterElement, 'diveduration');
      if (durationText != null) {
        final seconds = int.tryParse(durationText);
        if (seconds != null) {
          diveData['runtime'] = Duration(seconds: seconds);
        }
      }

      final waterTempText = _getElementText(afterElement, 'lowesttemperature');
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

      final visibilityText = _getElementText(afterElement, 'visibility');
      if (visibilityText != null) {
        diveData['visibility'] = _parseUddfVisibility(visibilityText);
      }

      // Parse rating
      final ratingElement = afterElement.findElements('rating').firstOrNull;
      if (ratingElement != null) {
        final ratingValue = _getElementText(ratingElement, 'ratingvalue');
        if (ratingValue != null) {
          diveData['rating'] = int.tryParse(ratingValue);
        }
      }

      // Parse notes (try nested <para> first, then direct text content)
      final notesElement = afterElement.findElements('notes').firstOrNull;
      if (notesElement != null) {
        final para = _getElementText(notesElement, 'para');
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
            final firstName = _getElementText(personalElement, 'firstname');
            final lastName = _getElementText(personalElement, 'lastname');
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

  String? _getElementText(XmlElement parent, String elementName) {
    final element = parent.findElements(elementName).firstOrNull;
    return element?.innerText.trim().isEmpty == true
        ? null
        : element?.innerText.trim();
  }
}
