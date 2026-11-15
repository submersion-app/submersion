import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Why a site and a catalogue record are taken for the same place.
enum CataloguePairKind {
  /// The site is already linked to the record.
  linked,

  /// The same name, within the pairing distance.
  sure,

  /// Within the pairing distance under another name.
  nearby,

  /// The same name, and the site has no position to compare.
  named,
}

/// One of the diver's sites with the catalogue record believed to be the
/// same place, and what the record would add to the site.
class CataloguePair extends Equatable {
  const CataloguePair({
    required this.site,
    required this.record,
    required this.kind,
    required this.fields,
    this.distanceMeters,
  });

  final DiveSite site;
  final CatalogueSite record;
  final CataloguePairKind kind;

  /// The record's details the site has empty, in the order they are shown.
  final Set<CatalogueGapField> fields;

  /// How far apart the two are; null when either has no position.
  final double? distanceMeters;

  /// Whether applying the pair links the site: true unless it is linked
  /// already.
  bool get addsLink => site.catalogueId == null;

  /// Whether the pair is listed ticked. Only a pair the app is sure of,
  /// and never one that would give the site a position or whose record
  /// has not been checked against a traceable source: those the diver
  /// ticks themselves.
  bool get preTicked =>
      (kind == CataloguePairKind.linked || kind == CataloguePairKind.sure) &&
      !fields.contains(CatalogueGapField.position) &&
      record.trust == CatalogueTrust.verified;

  /// The site, the record and the fields on offer. The notice on the
  /// Sites page remembers these, so a pair whose offer has grown counts as
  /// new.
  String get key {
    final names = [for (final field in fields) field.name]..sort();
    return '${site.id}|${record.id}|${names.join(',')}';
  }

  @override
  List<Object?> get props => [site, record, kind, fields, distanceMeters];
}
