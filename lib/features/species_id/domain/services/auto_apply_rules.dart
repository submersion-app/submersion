/// When the app may tag a species with no tap (issue #4727). Pure, so every
/// screen and service decides alike.
library;

import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// A bar above 1 is "never": a score is a share of at most 1.
bool _reachable(double bar) => bar <= 1;

/// Whether [naming] can ever call a match confident, with a place or
/// without one. When it cannot, auto-apply has nothing to do.
bool packCanApply(NamingConfig naming) =>
    _reachable(naming.confidentScore) ||
    _reachable(naming.confidentScoreNoLocation);

/// Whether [naming] calls a match confident only when the media has a
/// usable place (Megalodon alone, measured 2026-11-17).
bool packAppliesOnlyWithPlace(NamingConfig naming) =>
    _reachable(naming.confidentScore) &&
    !_reachable(naming.confidentScoreNoLocation);
