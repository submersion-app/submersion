/// One dive in a career terrain set: its position in the set, when it
/// happened, its max depth, and a downsampled depth-time series.
class CareerDiveInput {
  final int index; // 0 = oldest in the set
  final DateTime date;
  final double maxDepthMeters;
  final List<double> times; // seconds from descent
  final List<double> depths; // meters

  const CareerDiveInput({
    required this.index,
    required this.date,
    required this.maxDepthMeters,
    required this.times,
    required this.depths,
  });
}

/// The set of dives to render as a stacked terrain (oldest first).
class CareerSceneData {
  final List<CareerDiveInput> dives;

  const CareerSceneData({required this.dives});

  bool get isEmpty => dives.isEmpty;
}
