import 'package:equatable/equatable.dart';

/// Reef presence and integrated threat classification at a point.
///
/// Sourced from WRI Reefs at Risk Revisited 2011 (CC BY 3.0). This answers
/// whether a reef is present and how threatened it is; it does not describe
/// benthic composition or geomorphic zone.
class ReefHabitat extends Equatable {
  final bool onReef;

  /// WRI's integrated local threat class, e.g. "Low", "Medium", "High",
  /// "Very High", "Critical". Null when the source did not report one.
  final String? threatLevel;

  const ReefHabitat({required this.onReef, this.threatLevel});

  ReefHabitat copyWith({bool? onReef, String? threatLevel}) => ReefHabitat(
    onReef: onReef ?? this.onReef,
    threatLevel: threatLevel ?? this.threatLevel,
  );

  Map<String, dynamic> toJson() => {
    'onReef': onReef,
    'threatLevel': threatLevel,
  };

  factory ReefHabitat.fromJson(Map<String, dynamic> json) => ReefHabitat(
    onReef: json['onReef'] as bool? ?? false,
    threatLevel: json['threatLevel'] as String?,
  );

  @override
  List<Object?> get props => [onReef, threatLevel];
}
