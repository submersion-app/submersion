import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

/// The most two gas percentages may differ and still be the same mix, as the
/// re-parse's own diver-edit test treats them.
const double _sameMixTolerancePercent = 0.5;

/// Whether [row]'s stored role is only the importer's guess for a gas that
/// [parsed] has since corrected, so a re-parse may give it the role of the
/// corrected gas (issue #5057).
///
/// A back-gas transmitter used to import with the deco gas when the deco
/// outlasted the bottom phase, and the importer gave every cylinder the role
/// its O2 suggested ([openCircuitGasRole]). Nothing stored tells that guess
/// from a role the diver chose, so a re-parse kept both cylinders' roles
/// while it swapped their gases: trimix as deco, EAN50 as back gas.
///
/// The row must have no role source (a role read off a transmitter name has
/// its own rule), [parsed] must carry a mix the computer recorded, the gas
/// must differ from the stored one, and the stored role must be exactly the
/// O2 guess for the stored gas. A role the diver chose that matches that
/// guess is tied to the old gas anyway.
bool roleGuessedForCorrectedGas(DiveTank row, TankData parsed) =>
    row.roleSource == null &&
    parsed.mixRecorded &&
    ((row.o2Percent - parsed.o2Percent).abs() > _sameMixTolerancePercent ||
        (row.hePercent - parsed.hePercent).abs() > _sameMixTolerancePercent) &&
    row.tankRole == openCircuitGasRole(row.o2Percent);
