import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// One row of the dive picker: only what naming and dating a dive takes, so
/// listing a page of them reads no related table beyond the site's name.
class DivePickerRow extends Equatable {
  final String id;
  final int? diveNumber;
  final String? name;
  final String? siteName;
  final DateTime dateTime;

  /// `COALESCE(entry_time, dive_date_time)` in epoch milliseconds: the key
  /// the list is ordered by, kept for [cursor].
  final int sortTimestamp;

  const DivePickerRow({
    required this.id,
    this.diveNumber,
    this.name,
    this.siteName,
    required this.dateTime,
    required this.sortTimestamp,
  });

  /// Where the next page starts when this is the last row of a page.
  DiveSummaryCursor get cursor => DiveSummaryCursor(
    sortTimestamp: sortTimestamp,
    diveNumber: diveNumber ?? 0,
    id: id,
  );

  DivePickerRow copyWith({
    String? id,
    int? diveNumber,
    String? name,
    String? siteName,
    DateTime? dateTime,
    int? sortTimestamp,
  }) {
    return DivePickerRow(
      id: id ?? this.id,
      diveNumber: diveNumber ?? this.diveNumber,
      name: name ?? this.name,
      siteName: siteName ?? this.siteName,
      dateTime: dateTime ?? this.dateTime,
      sortTimestamp: sortTimestamp ?? this.sortTimestamp,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveNumber,
    name,
    siteName,
    dateTime,
    sortTimestamp,
  ];
}
