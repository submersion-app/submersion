import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// A fill in a line: its mix, and its pressure in the diver's unit when it
/// has one. A fill logged without a pressure shows no placeholder for it.
String fillSummary(GasMix mix, double? pressureBar, UnitFormatter units) => [
  mix.name,
  if (pressureBar != null) units.formatPressure(pressureBar),
].join(' · ');
