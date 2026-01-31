import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// A weighted point for heat map visualization.
class HeatMapPoint extends Equatable {
  final LatLng location;
  final double weight;
  final String? label;

  const HeatMapPoint({required this.location, this.weight = 1.0, this.label});

  @override
  List<Object?> get props => [location, weight, label];
}
