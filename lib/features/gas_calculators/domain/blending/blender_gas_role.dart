import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// The three fill-gas roles a Trimix bank can be wired to.
///
/// Fixed identities rather than bank positions (issue #42): a fill station's
/// oxygen bank is always the oxygen bank, whatever order the diver fills in
/// today. Keying prices and flush-fee settings by role rather than by
/// position keeps them correct however the fill order is arranged, and lets
/// the two previously separate price systems (positional bank prices,
/// identity-based flush-fee prices) share one source of truth.
enum BlenderGasRole {
  o2,
  he,
  topup;

  static BlenderGasRole? fromName(String? name) => switch (name) {
    'o2' => BlenderGasRole.o2,
    'he' => BlenderGasRole.he,
    'topup' => BlenderGasRole.topup,
    _ => null,
  };
}

/// The fill order a fresh install starts with: oxygen, then helium, then
/// topup. The sequence a fill station actually works in -- helium is
/// decanted while the cylinder is still low, and the compressor tops off
/// with the topup gas last.
const List<BlenderGasRole> kDefaultBlenderFillOrder = [
  BlenderGasRole.o2,
  BlenderGasRole.he,
  BlenderGasRole.topup,
];

/// [order] if it is a valid fill order (each role exactly once), otherwise
/// [kDefaultBlenderFillOrder].
///
/// Guards every read of a stored or provided order: a corrupt or truncated
/// sync blob must not hand the solver a list that is missing a role or
/// repeats one, the same defensive stance [BlenderPreferences.fromJson]
/// takes with every other field.
List<BlenderGasRole> normalizeBlenderFillOrder(List<BlenderGasRole>? order) {
  if (order != null &&
      order.length == BlenderGasRole.values.length &&
      order.toSet().length == BlenderGasRole.values.length) {
    return order;
  }
  return kDefaultBlenderFillOrder;
}

/// The gas [role] actually holds.
///
/// Oxygen and helium are fixed at 100% purity -- that fixed purity is what
/// makes them a role rather than a bank a diver mixes by hand. Only the
/// topup role has a configurable oxygen fraction, since a fill station's
/// third bank is air on most days but not always.
GasMix gasForRole(BlenderGasRole role, double topupO2Percent) => switch (role) {
  BlenderGasRole.o2 => const GasMix(o2: 100),
  BlenderGasRole.he => const GasMix(o2: 0, he: 100),
  BlenderGasRole.topup => GasMix(o2: topupO2Percent),
};
