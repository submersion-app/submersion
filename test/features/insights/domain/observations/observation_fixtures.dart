import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

/// "Now" for every rule test: wall-clock UTC, a Monday.
final now = DateTime.utc(2026, 10, 5, 12);

DateTime daysAgo(int days) => now.subtract(Duration(days: days));

ObservationDive dive(
  String id,
  DateTime date, {
  double? maxDepthM,
  int? runtimeSeconds,
  double? weightKg,
  String? siteId,
  String? siteName,
  String? country,
  bool hasProfile = false,
  List<ObservationBuddy> buddies = const [],
}) => ObservationDive(
  id: id,
  date: date,
  maxDepthM: maxDepthM,
  runtimeSeconds: runtimeSeconds,
  weightKg: weightKg,
  siteId: siteId,
  siteName: siteName,
  country: country,
  hasProfile: hasProfile,
  buddies: buddies,
);

/// [count] dives spread evenly through the window that ends [endDaysAgo]
/// days ago and spans [spanDays] days, oldest first.
List<ObservationDive> divesIn({
  required String prefix,
  required int count,
  required int endDaysAgo,
  int spanDays = 300,
}) => [
  for (var k = count - 1; k >= 0; k--)
    dive('$prefix-$k', daysAgo(endDaysAgo + (spanDays * k) ~/ count)),
];
