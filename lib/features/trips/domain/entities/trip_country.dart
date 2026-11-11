import 'package:equatable/equatable.dart';

/// One country a trip's dives were in, for the flags beside the trip
/// (issue #4426).
class TripCountry extends Equatable {
  const TripCountry({required this.code, required this.name});

  /// ISO 3166-1 alpha-2 code.
  final String code;

  /// The country as the diver's sites store it, for the flags' tooltip and
  /// screen reader label.
  final String name;

  TripCountry copyWith({String? code, String? name}) =>
      TripCountry(code: code ?? this.code, name: name ?? this.name);

  @override
  List<Object?> get props => [code, name];
}
