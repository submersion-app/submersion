/// Options for a UDDF export.
///
/// Shaped after `PdfExportOptions` in `lib/core/constants/pdf_templates.dart`:
/// a const class with defaults, passed as a defaulted named parameter, so no
/// existing call site has to change.
class UddfExportOptions {
  /// Whether to carry each dive's raw dive computer bytes.
  ///
  /// Defaults to true, matching what every export UI shows: the checkbox is
  /// pre-checked in both the full backup and the dives only share paths, and
  /// the code level default is kept in step with it rather than diverging.
  /// A caller that omits options therefore gets a complete export.
  final bool includeRawData;

  /// Whether the dives only export carries each dive's participants and
  /// their roles (issue #1796). The full backup always carries them and
  /// ignores this.
  final bool includeParticipants;

  /// Whether the dives only export carries the gear and dive computer used
  /// on each dive (issue #1718). The full backup always carries them and
  /// ignores this.
  final bool includeGear;

  const UddfExportOptions({
    this.includeRawData = true,
    this.includeParticipants = true,
    this.includeGear = true,
  });

  UddfExportOptions copyWith({
    bool? includeRawData,
    bool? includeParticipants,
    bool? includeGear,
  }) => UddfExportOptions(
    includeRawData: includeRawData ?? this.includeRawData,
    includeParticipants: includeParticipants ?? this.includeParticipants,
    includeGear: includeGear ?? this.includeGear,
  );
}
