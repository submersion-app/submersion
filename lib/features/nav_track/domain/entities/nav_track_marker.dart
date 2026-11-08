import 'package:equatable/equatable.dart';

/// A marker the recording console set during the dive (issue #4231).
///
/// A Seacraft ENC writes one into its battery column as a negative number
/// when the diver holds the recording or sets a return point. The value
/// itself is kept as [rawValue] but is not a usable number: the same value
/// repeats within one recording. Markers are therefore numbered in file
/// order by whoever shows them.
class NavTrackMarker extends Equatable {
  /// Index of the sample the marker belongs to, in the route's own points.
  final int index;

  /// The value the file stored, e.g. -1 or -101.
  final int rawValue;

  const NavTrackMarker({required this.index, required this.rawValue});

  NavTrackMarker copyWith({int? index, int? rawValue}) => NavTrackMarker(
    index: index ?? this.index,
    rawValue: rawValue ?? this.rawValue,
  );

  @override
  List<Object?> get props => [index, rawValue];
}
