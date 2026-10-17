import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// How a dive reads when a document is filed under it (#3391): the same
/// words in the File-under field, the list, the detail page and the export
/// folder, built from the dive's number, site and date.
class DiveOwnerLabel extends Equatable {
  final int? number;
  final String? siteName;

  /// The dive's wall-clock date, stored as UTC (see `wallClockUtcFromMillis`).
  final DateTime date;

  const DiveOwnerLabel({this.number, this.siteName, required this.date});

  List<String> _parts(String date) => [
    if (number != null) '#$number',
    if (siteName?.trim() case final site? when site.isNotEmpty) site,
    date,
  ];

  /// The on-screen form, `#142 · Blue Hole · 12 Oct 2026`, with
  /// [formattedDate] in the diver's date format.
  String display(String formattedDate) => _parts(formattedDate).join(' · ');

  /// The export folder form, `#142 Blue Hole 2026-10-12`, which sorts by
  /// date in a file browser.
  String folderName() =>
      _parts(DateFormat('yyyy-MM-dd').format(date)).join(' ');

  @override
  List<Object?> get props => [number, siteName, date];
}
