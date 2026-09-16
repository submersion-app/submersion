import 'package:equatable/equatable.dart';

/// A person a multi-diver logbook attributes records to (issue #1893).
///
/// A MacDive library can hold several divers. Parsers describe each one here
/// and stamp its [key] on every dive and certification map under [mapKey], so
/// the import wizard can send each diver's records to the Submersion profile
/// the user picks.
class SourceDiver extends Equatable {
  /// [key] of the records the source attributes to no diver.
  static const unownedKey = '_unowned';

  /// Payload map key that carries a record's [key].
  static const mapKey = 'sourceDiverKey';

  /// Prefix of a [key] that is unique only within one file, such as one
  /// built from a Core Data primary key. PayloadMerger qualifies these with
  /// the file's id, so two files' divers never merge on a coincidence.
  static const fileLocalPrefix = 'local:';

  /// [key] qualified by [fileId] when it is file-local, else unchanged.
  static String qualifyForFile(String key, String fileId) =>
      key.startsWith(fileLocalPrefix)
      ? '$fileLocalPrefix$fileId:${key.substring(fileLocalPrefix.length)}'
      : key;

  /// Stable id within one import: `macdive:<ZUUID>` for MacDive.sqlite,
  /// `name:<name>` for MacDive XML, or [unownedKey].
  final String key;

  /// Display name; empty for the unowned row.
  final String name;

  final int diveCount;
  final int certificationCount;

  // What a new Submersion profile is seeded from. MacDive.sqlite only; the
  // XML export carries a diver's name and nothing else.
  final String? email;
  final String? phone;
  final String? emergencyContact;
  final String? bloodType;
  final String? danNumber;

  const SourceDiver({
    required this.key,
    required this.name,
    this.diveCount = 0,
    this.certificationCount = 0,
    this.email,
    this.phone,
    this.emergencyContact,
    this.bloodType,
    this.danNumber,
  });

  bool get isUnowned => key == unownedKey;

  bool get hasRecords => diveCount > 0 || certificationCount > 0;

  SourceDiver copyWith({String? key, int? diveCount, int? certificationCount}) {
    return SourceDiver(
      key: key ?? this.key,
      name: name,
      diveCount: diveCount ?? this.diveCount,
      certificationCount: certificationCount ?? this.certificationCount,
      email: email,
      phone: phone,
      emergencyContact: emergencyContact,
      bloodType: bloodType,
      danNumber: danNumber,
    );
  }

  @override
  List<Object?> get props => [
    key,
    name,
    diveCount,
    certificationCount,
    email,
    phone,
    emergencyContact,
    bloodType,
    danNumber,
  ];
}

/// The rows the Divers step shows, in display order: divers with records by
/// dive count (most first, then name), then the unowned row when it has
/// records.
List<SourceDiver> orderedDiverRows(List<SourceDiver> divers) {
  final named = [
    for (final d in divers)
      if (!d.isUnowned && d.hasRecords) d,
  ];
  named.sort((a, b) {
    final byCount = b.diveCount.compareTo(a.diveCount);
    return byCount != 0 ? byCount : a.name.compareTo(b.name);
  });
  return [
    ...named,
    for (final d in divers)
      if (d.isUnowned && d.hasRecords) d,
  ];
}
