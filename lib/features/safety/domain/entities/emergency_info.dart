import 'package:equatable/equatable.dart';

/// A diver-emergency hotline region (DAN/DES).
class EmergencyRegion extends Equatable {
  final String id;
  final String name;
  final String phone;

  /// ISO 3166-1 alpha-2 codes served by this hotline. Empty = worldwide
  /// fallback.
  final List<String> countries;

  const EmergencyRegion({
    required this.id,
    required this.name,
    required this.phone,
    required this.countries,
  });

  factory EmergencyRegion.fromJson(Map<String, dynamic> json) {
    return EmergencyRegion(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      countries: (json['countries'] as List? ?? const []).cast<String>(),
    );
  }

  @override
  List<Object?> get props => [id, name, phone, countries];
}

/// What a facility is documented to do.
///
/// [divingEmergency] requires evidence that it accepts acute diving injuries.
/// The bar is DAN's own referral-network acceptance criteria: capable and
/// willing to treat injured divers, standard oxygen treatment tables for DCI,
/// oxygen available for every diving treatment table, and space to monitor a
/// diver before and after treatment.
///
/// [elective] marks hyperbaric oxygen therapy clinics (wound care and similar)
/// that will not accept a bent diver out of hours. They are listed because a
/// chamber is a chamber when nothing else is in range, never ranked above a
/// facility that treats divers.
enum ChamberCapability {
  divingEmergency('diving_emergency'),
  hyperbaricUnit('hyperbaric_unit'),
  elective('elective'),
  unknown('unknown');

  const ChamberCapability(this.wireName);

  final String wireName;

  static ChamberCapability fromWire(Object? value) {
    for (final capability in ChamberCapability.values) {
      if (capability.wireName == value) return capability;
    }
    return ChamberCapability.unknown;
  }
}

/// When the facility can be reached. Sourced from registry tagging where it
/// exists (SIMSI publishes an "Urgenza h24" flag per centre).
enum ChamberAvailability {
  h24('h24'),
  onCall('on_call'),
  businessHours('business_hours'),
  unknown('unknown');

  const ChamberAvailability(this.wireName);

  final String wireName;

  static ChamberAvailability fromWire(Object? value) {
    for (final availability in ChamberAvailability.values) {
      if (availability.wireName == value) return availability;
    }
    return ChamberAvailability.unknown;
  }
}

/// How a row's details were last confirmed. [facility] means the details were
/// checked against the facility's own website, which is both the provenance
/// story and the reason the dataset carries no third-party compilation.
enum ChamberVerification {
  facility('facility'),
  registry('registry'),
  unknown('unknown');

  const ChamberVerification(this.wireName);

  final String wireName;

  static ChamberVerification fromWire(Object? value) {
    for (final verification in ChamberVerification.values) {
      if (verification.wireName == value) return verification;
    }
    return ChamberVerification.unknown;
  }
}

/// A hyperbaric chamber entry: bundled (dated, read-only) or user-added.
class EmergencyChamber extends Equatable {
  final String id;
  final String name;
  final String country;
  final String? city;
  final String phone;

  /// The route a diver in trouble should take, when the facility publishes one
  /// distinct from [phone]. Preferred by [callNumber].
  ///
  /// This is emphatically not "the more specific number". For a hospital unit
  /// it is very often the main switchboard, because that is what pages the
  /// on-call hyperbaric physician at 2am, while the unit's own direct line
  /// rings an empty desk out of hours. Several Australian units publish
  /// exactly that arrangement. Where a facility publishes a dedicated
  /// emergency or after-hours line, that goes here instead.
  final String? emergencyPhone;

  final double? latitude;
  final double? longitude;
  final String? notes;

  final ChamberCapability capability;
  final ChamberAvailability availability;

  /// Verification date for bundled entries; null for user entries.
  final DateTime? lastVerified;

  final ChamberVerification verifiedVia;

  /// The page the details were confirmed against.
  final String? verifiedUrl;

  final bool isBuiltIn;

  const EmergencyChamber({
    required this.id,
    required this.name,
    required this.country,
    this.city,
    required this.phone,
    this.emergencyPhone,
    this.latitude,
    this.longitude,
    this.notes,
    this.capability = ChamberCapability.unknown,
    this.availability = ChamberAvailability.unknown,
    this.lastVerified,
    this.verifiedVia = ChamberVerification.unknown,
    this.verifiedUrl,
    required this.isBuiltIn,
  });

  /// The number to dial. [emergencyPhone] wins when the facility publishes a
  /// separate emergency route, because reaching a switchboard that pages the
  /// on-call physician beats reaching a direct line nobody answers.
  String get callNumber => emergencyPhone ?? phone;

  factory EmergencyChamber.fromBundledJson(Map<String, dynamic> json) {
    final verified = json['verified'] as Map<String, dynamic>?;
    // The date moved into `verified` with the curated dataset; `lastVerified`
    // is still read so a row written before that move keeps its date.
    final verifiedDate =
        verified?['date'] as String? ?? json['lastVerified'] as String?;

    return EmergencyChamber(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      city: json['city'] as String?,
      phone: json['phone'] as String,
      emergencyPhone: json['emergencyPhone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      capability: ChamberCapability.fromWire(json['capability']),
      availability: ChamberAvailability.fromWire(json['availability']),
      lastVerified: verifiedDate != null
          ? DateTime.tryParse(verifiedDate)
          : null,
      verifiedVia: ChamberVerification.fromWire(verified?['via']),
      verifiedUrl: verified?['url'] as String?,
      isBuiltIn: true,
    );
  }

  EmergencyChamber copyWith({
    String? id,
    String? name,
    String? country,
    String? city,
    String? phone,
    String? emergencyPhone,
    double? latitude,
    double? longitude,
    String? notes,
    ChamberCapability? capability,
    ChamberAvailability? availability,
    DateTime? lastVerified,
    ChamberVerification? verifiedVia,
    String? verifiedUrl,
    bool? isBuiltIn,
  }) {
    return EmergencyChamber(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      capability: capability ?? this.capability,
      availability: availability ?? this.availability,
      lastVerified: lastVerified ?? this.lastVerified,
      verifiedVia: verifiedVia ?? this.verifiedVia,
      verifiedUrl: verifiedUrl ?? this.verifiedUrl,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    country,
    city,
    phone,
    emergencyPhone,
    latitude,
    longitude,
    notes,
    capability,
    availability,
    lastVerified,
    verifiedVia,
    verifiedUrl,
    isBuiltIn,
  ];
}

/// The bundled hotline + EMS dataset.
class EmergencyNumbers {
  final List<EmergencyRegion> regions;
  final String defaultEms;
  final Map<String, String> emsByCountry;

  const EmergencyNumbers({
    required this.regions,
    required this.defaultEms,
    required this.emsByCountry,
  });

  /// Hotline for an ISO country code: the region listing the country, else
  /// the worldwide fallback (empty country list), else the first region.
  EmergencyRegion hotlineFor(String? countryCode) {
    if (countryCode != null) {
      for (final region in regions) {
        if (region.countries.contains(countryCode.toUpperCase())) {
          return region;
        }
      }
    }
    return regions.firstWhere(
      (r) => r.countries.isEmpty,
      orElse: () => regions.first,
    );
  }

  String emsFor(String? countryCode) {
    if (countryCode == null) return defaultEms;
    return emsByCountry[countryCode.toUpperCase()] ?? defaultEms;
  }
}
