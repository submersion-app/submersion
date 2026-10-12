import 'package:equatable/equatable.dart';

/// One dive whose tanks came from a tagged cylinder (issue #2650): what the
/// passport's usage card lists for it.
class PassportUsageDive extends Equatable {
  final String diveId;

  /// The dive's date and time, wall clock stored as UTC like every dive.
  final DateTime dateTime;
  final int? diveNumber;

  /// Null when the dive has no site.
  final String? siteName;

  const PassportUsageDive({
    required this.diveId,
    required this.dateTime,
    this.diveNumber,
    this.siteName,
  });

  PassportUsageDive copyWith({
    String? diveId,
    DateTime? dateTime,
    int? diveNumber,
    String? siteName,
  }) => PassportUsageDive(
    diveId: diveId ?? this.diveId,
    dateTime: dateTime ?? this.dateTime,
    diveNumber: diveNumber ?? this.diveNumber,
    siteName: siteName ?? this.siteName,
  );

  @override
  List<Object?> get props => [diveId, dateTime, diveNumber, siteName];
}
