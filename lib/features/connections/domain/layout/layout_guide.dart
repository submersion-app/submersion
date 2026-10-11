import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// A label a layout places in graph space beside its nodes, such as the
/// timeline's year and lane names. The painter draws the text.
sealed class LayoutGuide extends Equatable {
  const LayoutGuide(this.at);

  /// Year guides centre their text here; lane guides end their text here.
  final GraphPoint at;
}

class YearGuide extends LayoutGuide {
  const YearGuide(this.year, super.at);
  final int year;
  @override
  List<Object?> get props => [year, at];
}

class LaneGuide extends LayoutGuide {
  const LaneGuide(this.kind, super.at);
  final ConnectionKind kind;
  @override
  List<Object?> get props => [kind, at];
}
