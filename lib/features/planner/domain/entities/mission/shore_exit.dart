import 'package:equatable/equatable.dart';

/// The nearest way onto land from a waypoint, entered by hand (issue
/// #2086): a surface swim to the shore, then a walk back to the entry.
/// Nothing here is derived from a map.
class ShoreExit extends Equatable {
  /// Surface swim from the waypoint to the shore, in metres.
  final double surfaceSwimM;

  /// Walk from where the diver lands back to the entry, in metres.
  final double walkM;

  const ShoreExit({required this.surfaceSwimM, required this.walkM});

  ShoreExit copyWith({double? surfaceSwimM, double? walkM}) {
    return ShoreExit(
      surfaceSwimM: surfaceSwimM ?? this.surfaceSwimM,
      walkM: walkM ?? this.walkM,
    );
  }

  @override
  List<Object?> get props => [surfaceSwimM, walkM];
}
