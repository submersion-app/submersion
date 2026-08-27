import 'dart:typed_data';

/// The n x k tissue surface as a topology-preserving grid. Its [positions]
/// are the exact vertices (and order) of the drawn mesh, so the draped
/// wireframe and the hover picker align pixel-for-pixel with what is rendered.
/// Built once, in the same pass as the Scene3d, by SubsurfaceTissueBuilder.
class TissueSurfaceGrid {
  /// Number of (decimated) time columns.
  final int columns;

  /// Number of compartments (16).
  final int compartments;

  /// n*k*3 world coordinates: (x = time, y = height/percent, z = compartment).
  final Float32List positions;

  /// Length [columns]; 0..1 progress per column.
  final List<double> normalizedTimes;

  /// Length [compartments]; Buhlmann compartment numbers (1..16, fast -> slow).
  final List<int> compartmentNumbers;

  /// Length [compartments]; nitrogen half-times in minutes.
  final List<double> halfTimesN2;

  /// Length n*k; subsurfacePercentage per cell (matches height and color).
  final Float32List saturationPct;

  const TissueSurfaceGrid({
    required this.columns,
    required this.compartments,
    required this.positions,
    required this.normalizedTimes,
    required this.compartmentNumbers,
    required this.halfTimesN2,
    required this.saturationPct,
  });

  /// An empty grid (no samples). The chrome/picker treat this as "draw nothing".
  static final TissueSurfaceGrid empty = TissueSurfaceGrid(
    columns: 0,
    compartments: 0,
    positions: Float32List(0),
    normalizedTimes: const [],
    compartmentNumbers: const [],
    halfTimesN2: const [],
    saturationPct: Float32List(0),
  );

  bool get isEmpty => columns == 0 || compartments == 0;

  int _index(int col, int comp) => col * compartments + comp;

  /// World position (x, y, z) of the vertex at (col, comp).
  (double, double, double) positionAt(int col, int comp) {
    final i = _index(col, comp) * 3;
    return (positions[i], positions[i + 1], positions[i + 2]);
  }

  /// subsurfacePercentage at (col, comp).
  double percentAt(int col, int comp) => saturationPct[_index(col, comp)];
}
