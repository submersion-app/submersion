import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// One published firmware release of a model (issue #5104).
class FirmwareRelease extends Equatable {
  /// The maker's spelling, as the release notes print it ("V95").
  final String version;

  /// Other spellings of the same release: what libdivecomputer or a maker's
  /// cloud reports ("95").
  final List<String> reportedAs;
  final DateTime? date;
  final String? notesUrl;
  final String? instructionsUrl;
  final String? summary;

  /// The maker calls this release a safety fix.
  final bool safety;

  const FirmwareRelease({
    required this.version,
    this.reportedAs = const [],
    this.date,
    this.notesUrl,
    this.instructionsUrl,
    this.summary,
    this.safety = false,
  });

  @override
  List<Object?> get props => [
    version,
    reportedAs,
    date,
    notesUrl,
    instructionsUrl,
    summary,
    safety,
  ];
}

/// One model's entry in the catalogue, its releases newest first.
class FirmwareModel extends Equatable {
  final String id;
  final String manufacturer;
  final List<String> manufacturerAliases;
  final String model;
  final List<String> aliases;
  final Set<EquipmentType> equipmentTypes;
  final String? firmwarePageUrl;
  final List<FirmwareRelease> releases;

  const FirmwareModel({
    required this.id,
    required this.manufacturer,
    this.manufacturerAliases = const [],
    required this.model,
    this.aliases = const [],
    required this.equipmentTypes,
    this.firmwarePageUrl,
    required this.releases,
  });

  @override
  List<Object?> get props => [
    id,
    manufacturer,
    manufacturerAliases,
    model,
    aliases,
    equipmentTypes,
    firmwarePageUrl,
    releases,
  ];
}

/// The curated list of the latest firmware per model, published by
/// `submersion-app/firmware-catalogue` (see the design record
/// `docs/design/specs/2026-11-27-firmware-tracking-design.md`).
class FirmwareCatalogue extends Equatable {
  /// The only format this build reads. A file in another format is ignored
  /// and the last good copy kept.
  static const int knownFormat = 1;

  final int format;
  final DateTime? generatedAt;
  final List<FirmwareModel> models;

  const FirmwareCatalogue({
    required this.format,
    this.generatedAt,
    required this.models,
  });

  /// Reads a published file, or null when it is not one this build can
  /// trust: not JSON, another format, or any required field missing or of
  /// the wrong type. The file is taken whole or not at all, so a broken
  /// entry can never leave a model with half its releases. Unknown keys are
  /// ignored; links that are not web links are dropped.
  static FirmwareCatalogue? parse(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      if (json['format'] != knownFormat) return null;
      final models = json['models'] as List<dynamic>;
      return FirmwareCatalogue(
        format: knownFormat,
        generatedAt: _date(json['generatedAt']),
        models: [
          for (final m in models)
            if (_model(m as Map<String, dynamic>) case final model?) model,
        ],
      );
    } catch (_) {
      // FormatException from jsonDecode, TypeError from a cast: either way
      // the file is not one to act on.
      return null;
    }
  }

  /// Null for a model with no equipment type this build knows: it could
  /// never match an item.
  static FirmwareModel? _model(Map<String, dynamic> m) {
    final types = {
      for (final name in _strings(m['equipmentTypes']))
        if (EquipmentType.values.asNameMap()[name] case final type?) type,
    };
    final releases = [
      for (final r in m['releases'] as List<dynamic>)
        _release(r as Map<String, dynamic>),
    ];
    if (types.isEmpty) return null;
    return FirmwareModel(
      id: m['id'] as String,
      manufacturer: m['manufacturer'] as String,
      manufacturerAliases: _strings(m['manufacturerAliases']),
      model: m['model'] as String,
      aliases: _strings(m['aliases']),
      equipmentTypes: types,
      firmwarePageUrl: _link(m['firmwarePageUrl']),
      releases: releases,
    );
  }

  static FirmwareRelease _release(Map<String, dynamic> r) => FirmwareRelease(
    version: r['version'] as String,
    reportedAs: _strings(r['reportedAs']),
    date: _date(r['date']),
    notesUrl: _link(r['notesUrl']),
    instructionsUrl: _link(r['instructionsUrl']),
    summary: r['summary'] as String?,
    safety: r['safety'] as bool? ?? false,
  );

  static List<String> _strings(Object? value) =>
      value == null ? const [] : List<String>.from(value as List<dynamic>);

  /// A `2026-10-01` date is a calendar day, read as UTC midnight so it never
  /// shifts with the device's zone.
  static DateTime? _date(Object? value) {
    final text = value as String?;
    if (text == null) return null;
    final parsed = DateTime.parse(text);
    return text.length == 10
        ? DateTime.utc(parsed.year, parsed.month, parsed.day)
        : parsed.toUtc();
  }

  static String? _link(Object? value) {
    final text = value as String?;
    return parseWebLink(text) == null ? null : text;
  }

  @override
  List<Object?> get props => [format, generatedAt, models];
}
