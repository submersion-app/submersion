import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Normalizes a raw UDDF `<tankvolume>` value to liters (#158).
///
/// UDDF 3.2.3 defines tankvolume in CUBIC METERS, but exporters disagree:
/// spec-conformant tools write 0.0111 for an 11.1 L tank, Diving Log 6.x
/// writes 0.111 (10x off), and legacy Submersion exports wrote plain liters.
/// A plausibility ladder keyed to real tank sizes (roughly 1-45 L water
/// capacity) disambiguates the three conventions; implausible values are
/// stored unchanged rather than guessed at.
///
/// The ladder cannot be exact for every input: 0.045 < raw <= 0.45 is
/// genuinely ambiguous between a Diving Log 4.5-45 L tank and a
/// spec-conformant 45-450 L one, and it resolves toward Diving Log because
/// small cylinders are far more common than 45 L+ single-tank records.
/// Exports that declare their unit never hit that ambiguity: they set
/// [strictCubicMeters] and are converted exactly. Submersion exports made
/// BEFORE the unit was declared wrote liters, carry no declaration, and so
/// fall through to the ladder, which reads them correctly.
double normalizeUddfTankVolumeToLiters(
  double raw, {
  bool strictCubicMeters = false,
}) {
  if (raw <= 0) return raw;
  // A file that DECLARES its unit needs no guessing, so any volume
  // round-trips exactly -- including tanks above the ladder's range. The
  // >= 1 guard is a backstop against a mislabelled file: 1 m3 is 1000 L,
  // which is not a tank, so such a value is liters whatever the label says.
  if (strictCubicMeters && raw < 1.0) return raw * 1000;
  if (raw <= 0.045) return raw * 1000; // spec cubic meters
  if (raw <= 0.45) return raw * 100; // Diving Log 10x-off quirk
  if (raw <= 45) return raw; // legacy liter exports
  return raw;
}

/// Static parser methods for UDDF entity elements.
///
/// Used by [UddfFullImportService] to parse individual entity types
/// from UDDF XML elements into maps.
class UddfImportParsers {
  UddfImportParsers._();

  // An integer followed by a fractional part of nothing but zeros, e.g.
  // "15.0" or "15.000". Captures the integer so it can be parsed exactly.
  static final RegExp _zeroFractionPattern = RegExp(r'^([+-]?\d+)\.0*$');

  /// Parses a UDDF integer-semantics value, tolerating the float
  /// serialization several exporters emit.
  ///
  /// UDDF types fields like `<divetime>` and `<diveduration>` as integers,
  /// but exporters built on JavaScript runtimes write them as floats
  /// (Oceanic Plus emits `<divetime>15.0</divetime>`; MacDive emits
  /// `<diveduration>60.00</diveduration>`), because 15 and 15.0 are the
  /// same value there. [int.tryParse] rejects any decimal point, so those
  /// fields silently fell back to 0 or were dropped entirely -- a profile
  /// imported from Oceanic Plus had every waypoint stamped at t=0.
  ///
  /// Parsing leniently here fixes the whole class of defect without
  /// requiring the file to be attributed to a known vendor first, which
  /// matters because vendor fingerprints fail silently: Oceanic Plus omits
  /// `<generator><name>`, leaving only a locale-dependent homepage URL to
  /// match on.
  ///
  /// Returns null when [text] is null, blank, non-numeric, or non-finite.
  /// Genuinely fractional input is rounded to nearest.
  static int? parseUddfInt(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;

    // Strip a fractional part that is nothing but zeros, so the value keeps
    // exact integer semantics. Going through a double would lose precision
    // above 2^53 ("9007199254740993.0" comes back as ...992) for values Dart
    // ints represent exactly. Anything with a real fraction, an exponent or
    // stray characters falls through to the double path below.
    final zeroFraction = _zeroFractionPattern.firstMatch(trimmed);
    if (zeroFraction != null) {
      final exact = int.tryParse(zeroFraction.group(1)!);
      if (exact != null) return exact;
    }

    final asDouble = double.tryParse(trimmed);
    // double.tryParse succeeds on "NaN" and "Infinity", and calling round()
    // on either throws UnsupportedError. Guarding here keeps one malformed
    // element from aborting the entire import.
    if (asDouble == null || !asDouble.isFinite) return null;
    return asDouble.round();
  }

  /// Parses a UDDF decimal value, rejecting non-finite input.
  ///
  /// [double.tryParse] succeeds on "NaN", "Infinity" and "-Infinity", so a
  /// value that is only null-checked reaches the database intact. NaN is the
  /// dangerous one: it compares false against everything including itself,
  /// so it silently poisons totals, averages and range checks downstream
  /// rather than failing where it was introduced.
  ///
  /// Returns null when [text] is null, blank, non-numeric or non-finite.
  static double? parseUddfDouble(String? text) {
    if (text == null) return null;
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite) return null;
    return value;
  }

  static void assignGasMixToTankIfMissing({
    required List<Map<String, dynamic>> tanks,
    required int tankIndex,
    required GasMix gasMix,
  }) {
    if (tankIndex < 0 || tankIndex >= tanks.length) {
      return;
    }

    tanks[tankIndex].putIfAbsent('gasMix', () => gasMix);
  }

  static T? parseEnumValue<T extends Enum>(String value, List<T> values) {
    final lowerValue = value.toLowerCase();
    for (final v in values) {
      if (v.name.toLowerCase() == lowerValue) {
        return v;
      }
    }
    return null;
  }

  static String? getElementText(XmlElement parent, String elementName) {
    final element = parent.findElements(elementName).firstOrNull;
    return element?.innerText.trim().isEmpty == true
        ? null
        : element?.innerText.trim();
  }

  /// Reads a dive computer's vendor from a `<divecomputer>` element.
  ///
  /// UDDF nests the vendor as `<manufacturer><name>`, alongside optional
  /// address and contact children, so the nested `<name>` is read first.
  ///
  /// The bare-text fallback keeps exporters that write
  /// `<manufacturer>Shearwater</manufacturer>` working, but applies only when
  /// the element has no child elements at all: `innerText` walks the whole
  /// subtree, so a `<manufacturer>` carrying only an address would otherwise
  /// yield a vendor of "VancouverCanada".
  static String? getManufacturerName(XmlElement computerElement) {
    final manufacturer = computerElement
        .findElements('manufacturer')
        .firstOrNull;
    if (manufacturer == null) return null;
    final named = getElementText(manufacturer, 'name');
    if (named != null) return named;
    if (manufacturer.childElements.isNotEmpty) return null;
    final text = manufacturer.innerText.trim();
    return text.isEmpty ? null : text;
  }

  /// Maximum O2 cells the profile schema can hold (o2Sensor1..o2Sensor6).
  static const int maxO2Sensors = 6;

  /// Reads the dive mode from a `<divemode>` child of [parent].
  ///
  /// UDDF's own form is an empty element carrying the circuit in a `type`
  /// attribute (`<divemode type="closedcircuit" />`), while our exporter
  /// writes the enum name as inner text. Both appear at dive level, on
  /// `<rebreather>` and on waypoints, so both are read wherever the element
  /// occurs.
  static enums.DiveMode? parseDiveModeIn(XmlElement parent) {
    final element = parent.findElements('divemode').firstOrNull;
    if (element == null) return null;

    return parseUddfDiveMode(element.innerText) ??
        parseUddfDiveMode(element.getAttribute('type'));
  }

  /// Resolves a UDDF circuit name to a dive mode.
  ///
  /// UDDF spells the circuit out (`closedcircuit`), while our own exporter
  /// writes the enum name (`ccr`), so both are accepted. Apnea has no
  /// equivalent mode and stays unresolved rather than being forced to gauge.
  static enums.DiveMode? parseUddfDiveMode(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    return switch (normalized) {
      'closedcircuit' => enums.DiveMode.ccr,
      'semiclosedcircuit' => enums.DiveMode.scr,
      'opencircuit' => enums.DiveMode.oc,
      _ => parseEnumValue(normalized, enums.DiveMode.values),
    };
  }

  /// Parses a UDDF partial pressure into bar.
  ///
  /// The spec mandates Pascal (`1.27e5` for 1.27 bar), but exporters are
  /// inconsistent: Shearwater Cloud writes plain bar (`0.849999964`), and our
  /// own exporter has always written bar. The two differ by 10^5, so the
  /// magnitude decides the unit. No breathable partial pressure reaches 100
  /// bar, and 100 Pa (0.001 bar) is not a plausible reading either, so
  /// anything above the threshold is Pascal.
  static double? parsePartialPressureBar(String? text) {
    if (text == null) return null;
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value > 100 ? value / 100000 : value;
  }

  /// Ordered O2 cell ids declared in the document.
  ///
  /// AP Diving declares them under `diver/owner/equipment/rebreather`, but the
  /// lookup is document-wide so an exporter that puts them elsewhere still
  /// resolves. Per-waypoint cell readings reference these ids, so declaration
  /// order — not the order the readings appear in a waypoint — determines
  /// which cell a reading belongs to.
  static List<String> parseO2SensorOrder(XmlDocument document) {
    return document
        .findAllElements('o2sensor')
        .map((sensor) => sensor.getAttribute('id')?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Reads per-cell O2 readings from a waypoint, in bar, indexed by cell.
  ///
  /// Handles both the published `<measuredpo2 ref="...">` form and the
  /// unpublished 3.3.0 draft `<ppo2 ref="...">` rename that AP Diving's
  /// DiveSight emits. Readings whose `ref` matches no declared sensor fall
  /// back to the order they appear in the waypoint, so an export that omits
  /// the `<rebreather>` block still yields usable curves.
  static Map<int, double> parseO2SensorReadings(
    XmlElement waypoint,
    List<String> sensorOrder,
  ) {
    final readings = <int, double>{};
    final unresolved = <double>[];

    for (final element in [
      ...waypoint.findElements('measuredpo2'),
      ...waypoint.findElements('ppo2'),
    ]) {
      final ref = element.getAttribute('ref')?.trim();
      // A bare <ppo2> with no ref is our own exporter's aggregate value,
      // not a cell reading.
      if (ref == null || ref.isEmpty) continue;

      final value = parsePartialPressureBar(element.innerText);
      if (value == null) continue;

      final index = sensorOrder.indexOf(ref);
      if (index >= 0) {
        if (index < maxO2Sensors) readings[index] = value;
      } else {
        unresolved.add(value);
      }
    }

    for (final value in unresolved) {
      var slot = 0;
      while (readings.containsKey(slot)) {
        slot++;
      }
      if (slot >= maxO2Sensors) break;
      readings[slot] = value;
    }

    return readings;
  }

  static GasMix parseGasMix(XmlElement mixElement) {
    final o2Text = getElementText(mixElement, 'o2');
    final heText = getElementText(mixElement, 'he');

    // UDDF stores gas values as fractions (0.21 for 21%).
    final o2 = o2Text != null ? (double.tryParse(o2Text) ?? 0.21) * 100 : 21.0;
    final he = heText != null ? (double.tryParse(heText) ?? 0.0) * 100 : 0.0;

    return GasMix(o2: o2, he: he);
  }

  /// Parse a UDDF datetime string using the wall-clock-as-UTC convention.
  ///
  /// UDDF dive datetimes represent the wall-clock reading from the dive
  /// computer (e.g. "2024-06-15T08:42:00"). Any timezone suffix is ignored
  /// and the date/time components are stored verbatim as a UTC DateTime so
  /// that they survive a DB round-trip unchanged.
  static DateTime? parseDiveDateTime(String? text) {
    if (text == null || text.isEmpty) return null;
    // Strip any trailing timezone info (Z, +HH:MM, -HH:MM, etc.)
    final bare = text.split(RegExp(r'[Z+\-](?=\d{2}:\d{2}$)|Z$')).first;
    final dt = DateTime.tryParse(bare);
    if (dt == null) return null;
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    );
  }

  static Map<String, dynamic> parseOwner(XmlElement ownerElement) {
    final owner = <String, dynamic>{};
    final ownerId = ownerElement.getAttribute('id');
    if (ownerId != null) {
      owner['uddfId'] = ownerId;
    }

    final personalElement = ownerElement.findElements('personal').firstOrNull;
    if (personalElement != null) {
      final firstName = getElementText(personalElement, 'firstname');
      final lastName = getElementText(personalElement, 'lastname');
      final name = [
        firstName,
        lastName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
      if (name.isNotEmpty) {
        owner['name'] = name;
      }
      owner['email'] = getElementText(personalElement, 'email');
      owner['phone'] = getElementText(personalElement, 'phone');
    }

    return owner;
  }

  static void parseOwnerExtended(
    XmlElement ownerExtElement,
    Map<String, dynamic> owner,
  ) {
    owner['medicalNotes'] =
        getElementText(ownerExtElement, 'medicalnotes') ?? '';
    owner['bloodType'] = getElementText(ownerExtElement, 'bloodtype');
    owner['allergies'] = getElementText(ownerExtElement, 'allergies');
    owner['medications'] = getElementText(ownerExtElement, 'medications');
    owner['notes'] = getElementText(ownerExtElement, 'notes') ?? '';

    final medClearanceDate = getElementText(
      ownerExtElement,
      'medicalclearanceexpirydate',
    );
    if (medClearanceDate != null) {
      owner['medicalClearanceExpiryDate'] = DateTime.tryParse(medClearanceDate);
    }

    // Parse emergency contact
    final emergencyElement = ownerExtElement
        .findElements('emergencycontact')
        .firstOrNull;
    if (emergencyElement != null) {
      owner['emergencyContactName'] = getElementText(emergencyElement, 'name');
      owner['emergencyContactPhone'] = getElementText(
        emergencyElement,
        'phone',
      );
      owner['emergencyContactRelation'] = getElementText(
        emergencyElement,
        'relationship',
      );
    }

    // Parse secondary emergency contact
    final emergency2Element = ownerExtElement
        .findElements('emergencycontact2')
        .firstOrNull;
    if (emergency2Element != null) {
      owner['emergencyContact2Name'] = getElementText(
        emergency2Element,
        'name',
      );
      owner['emergencyContact2Phone'] = getElementText(
        emergency2Element,
        'phone',
      );
      owner['emergencyContact2Relation'] = getElementText(
        emergency2Element,
        'relationship',
      );
    }

    // Parse insurance
    final insuranceElement = ownerExtElement
        .findElements('insurance')
        .firstOrNull;
    if (insuranceElement != null) {
      owner['insuranceProvider'] = getElementText(insuranceElement, 'provider');
      owner['insurancePolicyNumber'] = getElementText(
        insuranceElement,
        'policynumber',
      );
      final expiryDate = getElementText(insuranceElement, 'expirydate');
      if (expiryDate != null) {
        owner['insuranceExpiryDate'] = DateTime.tryParse(expiryDate);
      }
    }
  }

  static Map<String, dynamic> parseTrip(XmlElement tripElement) {
    final trip = <String, dynamic>{};

    trip['name'] = getElementText(tripElement, 'name') ?? '';
    trip['notes'] = getElementText(tripElement, 'notes') ?? '';

    // Parse date range
    final dateOfTrip = tripElement.findElements('dateoftrip').firstOrNull;
    if (dateOfTrip != null) {
      final startDateElement = dateOfTrip.findElements('startdate').firstOrNull;
      if (startDateElement != null) {
        final startDateTime = getElementText(startDateElement, 'datetime');
        if (startDateTime != null) {
          trip['startDate'] = DateTime.tryParse(startDateTime);
        }
      }
      final endDateElement = dateOfTrip.findElements('enddate').firstOrNull;
      if (endDateElement != null) {
        final endDateTime = getElementText(endDateElement, 'datetime');
        if (endDateTime != null) {
          trip['endDate'] = DateTime.tryParse(endDateTime);
        }
      }
    }

    // Parse geography
    final geographyElement = tripElement.findElements('geography').firstOrNull;
    if (geographyElement != null) {
      trip['location'] = getElementText(geographyElement, 'location');
    }

    return trip;
  }

  static void parseTripExtended(
    XmlElement tripExtElement,
    Map<String, dynamic> trip,
  ) {
    trip['resortName'] = getElementText(tripExtElement, 'resortname');
    trip['liveaboardName'] = getElementText(tripExtElement, 'liveaboardname');
    final tripType = getElementText(tripExtElement, 'triptype');
    if (tripType != null) {
      trip['tripType'] = tripType;
    }
  }

  static Map<String, dynamic> parseTag(XmlElement tagElement) {
    final tag = <String, dynamic>{};
    final tagId = tagElement.getAttribute('id');
    if (tagId != null) {
      tag['uddfId'] = tagId;
    }

    tag['name'] = getElementText(tagElement, 'name') ?? '';
    tag['colorHex'] = getElementText(tagElement, 'color');

    return tag;
  }

  static Map<String, dynamic> parseDiveTypeElement(XmlElement typeElement) {
    final diveType = <String, dynamic>{};
    final typeId = typeElement.getAttribute('id');
    if (typeId != null) {
      diveType['id'] = typeId;
    }

    diveType['name'] = getElementText(typeElement, 'name') ?? '';

    final sortOrder = getElementText(typeElement, 'sortorder');
    if (sortOrder != null) {
      diveType['sortOrder'] = parseUddfInt(sortOrder) ?? 0;
    }

    final isBuiltIn = getElementText(typeElement, 'isbuiltin');
    diveType['isBuiltIn'] = isBuiltIn?.toLowerCase() == 'true';

    return diveType;
  }

  static Map<String, dynamic> parseDiveRoleElement(XmlElement roleElement) {
    final diveRole = <String, dynamic>{};
    final roleId = roleElement.getAttribute('id');
    if (roleId != null) {
      diveRole['id'] = roleId;
    }

    diveRole['name'] = getElementText(roleElement, 'name') ?? '';

    final sortOrder = getElementText(roleElement, 'sortorder');
    if (sortOrder != null) {
      diveRole['sortOrder'] = parseUddfInt(sortOrder) ?? 0;
    }

    final isBuiltIn = getElementText(roleElement, 'isbuiltin');
    diveRole['isBuiltIn'] = isBuiltIn?.toLowerCase() == 'true';

    return diveRole;
  }

  static Map<String, dynamic> parseDiveComputer(XmlElement computerElement) {
    final computer = <String, dynamic>{};
    final computerId = computerElement.getAttribute('id');
    if (computerId != null) {
      computer['uddfId'] = computerId;
    }

    computer['name'] = getElementText(computerElement, 'name') ?? '';
    computer['manufacturer'] = getElementText(computerElement, 'manufacturer');
    computer['model'] = getElementText(computerElement, 'model');
    computer['serialNumber'] = getElementText(computerElement, 'serialnumber');
    computer['firmwareVersion'] = getElementText(
      computerElement,
      'firmwareversion',
    );
    computer['connectionType'] = getElementText(
      computerElement,
      'connectiontype',
    );
    computer['bluetoothAddress'] = getElementText(
      computerElement,
      'bluetoothaddress',
    );

    final isFavorite = getElementText(computerElement, 'isfavorite');
    computer['isFavorite'] = isFavorite?.toLowerCase() == 'true';

    computer['notes'] = getElementText(computerElement, 'notes') ?? '';

    return computer;
  }

  static Map<String, dynamic> parseCourse(XmlElement courseElement) {
    final course = <String, dynamic>{};
    final courseId = courseElement.getAttribute('id');
    if (courseId != null) {
      course['uddfId'] = courseId;
    }

    course['name'] = getElementText(courseElement, 'name') ?? '';
    course['agency'] = getElementText(courseElement, 'agency');

    final startDate = getElementText(courseElement, 'startdate');
    if (startDate != null) {
      course['startDate'] = DateTime.tryParse(startDate);
    }
    final completionDate = getElementText(courseElement, 'completiondate');
    if (completionDate != null) {
      course['completionDate'] = DateTime.tryParse(completionDate);
    }

    course['instructorName'] = getElementText(courseElement, 'instructorname');
    course['instructorNumber'] = getElementText(
      courseElement,
      'instructornumber',
    );
    course['location'] = getElementText(courseElement, 'location');
    course['notes'] = getElementText(courseElement, 'notes') ?? '';

    // Parse link refs for certification and instructor buddy
    for (final linkElement in courseElement.findElements('link')) {
      final ref = linkElement.getAttribute('ref');
      if (ref != null) {
        if (ref.startsWith('cert_')) {
          course['certificationRef'] = ref;
        } else if (ref.startsWith('buddy_')) {
          course['instructorRef'] = ref;
        }
      }
    }

    return course;
  }

  static Map<String, dynamic> parseEquipmentSet(XmlElement setElement) {
    final equipmentSet = <String, dynamic>{};
    final setId = setElement.getAttribute('id');
    if (setId != null) {
      equipmentSet['uddfId'] = setId;
    }

    equipmentSet['name'] = getElementText(setElement, 'name') ?? '';
    equipmentSet['description'] =
        getElementText(setElement, 'description') ?? '';

    // Parse equipment item references
    final itemsElement = setElement.findElements('items').firstOrNull;
    if (itemsElement != null) {
      final itemRefs = <String>[];
      for (final itemRef in itemsElement.findElements('itemref')) {
        final ref = itemRef.innerText.trim();
        if (ref.isNotEmpty) {
          itemRefs.add(ref);
        }
      }
      equipmentSet['equipmentRefs'] = itemRefs;
    }

    return equipmentSet;
  }

  static Map<String, dynamic> parseFullBuddy(XmlElement buddyElement) {
    final buddy = <String, dynamic>{};
    final buddyId = buddyElement.getAttribute('id');
    if (buddyId != null) {
      buddy['uddfId'] = buddyId;
    }

    final personalElement = buddyElement.findElements('personal').firstOrNull;
    if (personalElement != null) {
      final firstName = getElementText(personalElement, 'firstname');
      final lastName = getElementText(personalElement, 'lastname');
      final name = [
        firstName,
        lastName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
      if (name.isNotEmpty) {
        buddy['name'] = name;
      }
      buddy['email'] = getElementText(personalElement, 'email');
      buddy['phone'] = getElementText(personalElement, 'phone');
    }

    final certElement = buddyElement.findElements('certification').firstOrNull;
    if (certElement != null) {
      final level = getElementText(certElement, 'level');
      if (level != null) {
        buddy['certificationLevel'] = parseEnumValue(
          level,
          enums.CertificationLevel.values,
        );
      }
      final agency = getElementText(certElement, 'agency');
      if (agency != null) {
        buddy['certificationAgency'] = parseEnumValue(
          agency,
          enums.CertificationAgency.values,
        );
      }
    }

    buddy['notes'] = getElementText(buddyElement, 'notes') ?? '';

    return buddy;
  }

  static Map<String, dynamic> parseFullSite(
    XmlElement siteElement,
    Map<String, dynamic> baseSite,
  ) {
    final site = Map<String, dynamic>.from(baseSite);

    // Parse additional fields
    final rating = getElementText(siteElement, 'siterating');
    if (rating != null) {
      site['rating'] = double.tryParse(rating);
    }

    site['difficulty'] = getElementText(siteElement, 'difficulty');

    final siteAltitude = getElementText(siteElement, 'sitealtitude');
    if (siteAltitude != null) {
      site['altitude'] = double.tryParse(siteAltitude);
    }

    site['hazards'] = getElementText(siteElement, 'hazards');
    site['accessNotes'] = getElementText(siteElement, 'accessnotes');
    site['mooringNumber'] = getElementText(siteElement, 'mooringnumber');
    site['parkingInfo'] = getElementText(siteElement, 'parkinginfo');

    final additionalNotes = getElementText(siteElement, 'sitenotesadditional');
    if (additionalNotes != null) {
      site['notes'] = additionalNotes;
    }

    return site;
  }

  static Map<String, dynamic> parseEquipmentItem(XmlElement itemElement) {
    final item = <String, dynamic>{};
    final itemId = itemElement.getAttribute('id');
    if (itemId != null) {
      item['uddfId'] = itemId;
    }

    item['name'] = getElementText(itemElement, 'name');

    final typeStr = getElementText(itemElement, 'type');
    if (typeStr != null) {
      item['type'] = parseEnumValue(typeStr, enums.EquipmentType.values);
    }

    item['brand'] = getElementText(itemElement, 'brand');
    item['model'] = getElementText(itemElement, 'model');
    item['serialNumber'] = getElementText(itemElement, 'serialnumber');
    item['size'] = getElementText(itemElement, 'size');

    final statusStr = getElementText(itemElement, 'status');
    if (statusStr != null) {
      item['status'] = parseEnumValue(statusStr, enums.EquipmentStatus.values);
    }

    final purchaseDate = getElementText(itemElement, 'purchasedate');
    if (purchaseDate != null) {
      item['purchaseDate'] = DateTime.tryParse(purchaseDate);
    }

    final purchasePrice = getElementText(itemElement, 'purchaseprice');
    if (purchasePrice != null) {
      item['purchasePrice'] = double.tryParse(purchasePrice);
    }

    item['purchaseCurrency'] =
        getElementText(itemElement, 'purchasecurrency') ?? 'USD';

    final lastServiceDate = getElementText(itemElement, 'lastservicedate');
    if (lastServiceDate != null) {
      item['lastServiceDate'] = DateTime.tryParse(lastServiceDate);
    }

    final serviceInterval = getElementText(itemElement, 'serviceintervaldays');
    if (serviceInterval != null) {
      item['serviceIntervalDays'] = parseUddfInt(serviceInterval);
    }

    final isActive = getElementText(itemElement, 'isactive');
    item['isActive'] = isActive?.toLowerCase() != 'false';

    item['notes'] = getElementText(itemElement, 'notes') ?? '';

    return item;
  }

  static Map<String, dynamic> parseCertification(XmlElement certElement) {
    final cert = <String, dynamic>{};
    final certId = certElement.getAttribute('id');
    if (certId != null) {
      cert['uddfId'] = certId;
    }

    cert['name'] = getElementText(certElement, 'name');

    final agencyStr = getElementText(certElement, 'agency');
    if (agencyStr != null) {
      cert['agency'] = parseEnumValue(
        agencyStr,
        enums.CertificationAgency.values,
      );
    }

    final levelStr = getElementText(certElement, 'level');
    if (levelStr != null) {
      cert['level'] = parseEnumValue(levelStr, enums.CertificationLevel.values);
    }

    cert['cardNumber'] = getElementText(certElement, 'cardnumber');

    final issueDate = getElementText(certElement, 'issuedate');
    if (issueDate != null) {
      cert['issueDate'] = DateTime.tryParse(issueDate);
    }

    final expiryDate = getElementText(certElement, 'expirydate');
    if (expiryDate != null) {
      cert['expiryDate'] = DateTime.tryParse(expiryDate);
    }

    cert['instructorName'] = getElementText(certElement, 'instructorname');
    cert['instructorNumber'] = getElementText(certElement, 'instructornumber');
    cert['notes'] = getElementText(certElement, 'notes') ?? '';

    return cert;
  }

  static Map<String, dynamic> parseDiveCenter(XmlElement centerElement) {
    final center = <String, dynamic>{};
    final centerId = centerElement.getAttribute('id');
    if (centerId != null) {
      center['uddfId'] = centerId;
    }

    center['name'] = getElementText(centerElement, 'name');
    center['street'] = getElementText(centerElement, 'street');
    // Read city from <city> first, fallback to <location> for backward compat
    center['city'] =
        getElementText(centerElement, 'city') ??
        getElementText(centerElement, 'location');
    center['stateProvince'] = getElementText(centerElement, 'stateprovince');
    center['postalCode'] = getElementText(centerElement, 'postalcode');

    final lat = getElementText(centerElement, 'latitude');
    final lon = getElementText(centerElement, 'longitude');
    if (lat != null) {
      center['latitude'] = double.tryParse(lat);
    }
    if (lon != null) {
      center['longitude'] = double.tryParse(lon);
    }

    center['country'] = getElementText(centerElement, 'country');
    center['phone'] = getElementText(centerElement, 'phone');
    center['email'] = getElementText(centerElement, 'email');
    center['website'] = getElementText(centerElement, 'website');

    final affiliations = getElementText(centerElement, 'affiliations');
    if (affiliations != null && affiliations.isNotEmpty) {
      center['affiliations'] = affiliations
          .split(',')
          .map((s) => s.trim())
          .toList();
    }

    final rating = getElementText(centerElement, 'rating');
    if (rating != null) {
      center['rating'] = double.tryParse(rating);
    }

    center['notes'] = getElementText(centerElement, 'notes') ?? '';

    return center;
  }

  static Map<String, dynamic> parseSpecies(XmlElement specElement) {
    final spec = <String, dynamic>{};
    final specId = specElement.getAttribute('id');
    if (specId != null) {
      spec['uddfId'] = specId;
    }

    spec['commonName'] = getElementText(specElement, 'commonname');
    spec['scientificName'] = getElementText(specElement, 'scientificname');

    final categoryStr = getElementText(specElement, 'category');
    if (categoryStr != null) {
      spec['category'] = parseEnumValue(
        categoryStr,
        enums.SpeciesCategory.values,
      );
    }

    spec['description'] = getElementText(specElement, 'description');

    return spec;
  }

  static Map<String, dynamic> parseServiceRecord(XmlElement recordElement) {
    final record = <String, dynamic>{};
    final recordId = recordElement.getAttribute('id');
    if (recordId != null) {
      record['uddfId'] = recordId;
    }

    record['equipmentRef'] = getElementText(recordElement, 'equipmentref');

    // Files exported before v160 spell this 'servicetype'. UDDF files have no
    // version handshake and live on disk indefinitely, so both spellings are
    // read forever rather than behind a version gate.
    final serviceCategory =
        getElementText(recordElement, 'servicecategory') ??
        getElementText(recordElement, 'servicetype');
    if (serviceCategory != null) {
      record['serviceCategory'] = parseEnumValue(
        serviceCategory,
        enums.ServiceCategory.values,
      );
    }

    final serviceDate = getElementText(recordElement, 'servicedate');
    if (serviceDate != null) {
      record['serviceDate'] = DateTime.tryParse(serviceDate);
    }

    record['provider'] = getElementText(recordElement, 'provider');

    final cost = getElementText(recordElement, 'cost');
    if (cost != null) {
      record['cost'] = double.tryParse(cost);
    }

    record['currency'] = getElementText(recordElement, 'currency') ?? 'USD';

    final nextDue = getElementText(recordElement, 'nextservicedue');
    if (nextDue != null) {
      record['nextServiceDue'] = DateTime.tryParse(nextDue);
    }

    record['notes'] = getElementText(recordElement, 'notes') ?? '';

    return record;
  }
}
