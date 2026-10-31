import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Whether the Dive Lab can branch [dive]: a profile of at least two samples
/// on an open-circuit or rebreather dive. Gauge dives carry no deco analysis
/// to branch from. The menu, the teaser section and the page's empty state
/// all decide through this one function.
bool isDiveLabEligible(Dive dive) => !dive.isGauge && dive.profile.length >= 2;
