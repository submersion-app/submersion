import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart' as enums;

/// Static parser methods for UDDF entity elements.
///
/// Used by [UddfFullImportService] to parse individual entity types
/// from UDDF XML elements into maps.
class UddfImportParsers {
  UddfImportParsers._();

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
      diveType['sortOrder'] = int.tryParse(sortOrder) ?? 0;
    }

    final isBuiltIn = getElementText(typeElement, 'isbuiltin');
    diveType['isBuiltIn'] = isBuiltIn?.toLowerCase() == 'true';

    return diveType;
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
      item['serviceIntervalDays'] = int.tryParse(serviceInterval);
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

    final serviceType = getElementText(recordElement, 'servicetype');
    if (serviceType != null) {
      record['serviceType'] = parseEnumValue(
        serviceType,
        enums.ServiceType.values,
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
