import 'dart:math' as math;

import 'package:submersion/core/tide/constants/harmonic_constituents.dart';

/// Astronomical arguments needed for tidal harmonic prediction.
///
/// These arguments represent the positions of the Moon and Sun, which are
/// the primary drivers of ocean tides. The calculations follow:
/// - IERS Conventions for fundamental astronomical arguments
/// - Meeus "Astronomical Algorithms" for lunar/solar positions
/// - IHO standards for tidal prediction
///
/// The six fundamental arguments are:
/// - τ (tau): Mean lunar time (hour angle of mean Moon)
/// - s: Mean longitude of the Moon
/// - h: Mean longitude of the Sun
/// - p: Mean longitude of lunar perigee
/// - N: Mean longitude of ascending lunar node (negative in Doodson)
/// - p_s: Mean longitude of solar perigee (perihelion)
class AstronomicalArguments {
  /// Mean longitude of the Moon (s) in degrees
  final double s;

  /// Mean longitude of the Sun (h) in degrees
  final double h;

  /// Mean longitude of lunar perigee (p) in degrees
  final double p;

  /// Mean longitude of lunar ascending node (N) in degrees
  /// Note: Doodson uses N' = -N
  final double n;

  /// Mean longitude of solar perigee/perihelion (p_s) in degrees
  final double ps;

  /// Julian centuries from J2000.0
  final double T;

  /// Hour of day in solar hours (0-24)
  final double hourOfDay;

  AstronomicalArguments._({
    required this.s,
    required this.h,
    required this.p,
    required this.n,
    required this.ps,
    required this.T,
    required this.hourOfDay,
  });

  /// Calculate astronomical arguments for a given UTC time.
  ///
  /// All calculations use UTC time and produce results in degrees.
  factory AstronomicalArguments.forDateTime(DateTime time) {
    // Ensure we're working in UTC
    final utc = time.toUtc();

    // Calculate Julian Date
    final jd = _toJulianDate(utc);

    // Julian centuries from J2000.0 (noon on Jan 1, 2000)
    final T = (jd - 2451545.0) / 36525.0;

    // Hour of day for tau calculation
    final hourOfDay =
        utc.hour +
        utc.minute / 60.0 +
        utc.second / 3600.0 +
        utc.millisecond / 3600000.0;

    // Mean longitude of the Moon (s)
    // Meeus Chapter 47, accurate to 0.001 degree
    final s = _normalize(
      218.3164477 +
          481267.88123421 * T -
          0.0015786 * T * T +
          T * T * T / 538841.0 -
          T * T * T * T / 65194000.0,
    );

    // Mean longitude of the Sun (h)
    // Based on mean anomaly and longitude of perihelion
    final h = _normalize(280.4664567 + 360007.6982779 * T + 0.03032028 * T * T);

    // Mean longitude of lunar perigee (p)
    // Longitude of the Moon's closest approach point
    final p = _normalize(
      83.3532465 + 4069.0137287 * T - 0.0103200 * T * T - T * T * T / 80053.0,
    );

    // Mean longitude of lunar ascending node (N)
    // The point where Moon's orbit crosses the ecliptic going north
    final n = _normalize(
      125.0445479 - 1934.1362891 * T + 0.0020754 * T * T + T * T * T / 467441.0,
    );

    // Mean longitude of solar perigee (p_s)
    // Earth's perihelion point
    final ps = _normalize(282.9373 + 1.7195 * T + 0.00046 * T * T);

    return AstronomicalArguments._(
      s: s,
      h: h,
      p: p,
      n: n,
      ps: ps,
      T: T,
      hourOfDay: hourOfDay,
    );
  }

  /// Calculate the equilibrium argument V₀ + u for a constituent.
  ///
  /// The equilibrium argument is the phase of the equilibrium tide
  /// (the tide that would exist on an ideal water-covered Earth)
  /// for a given constituent at Greenwich.
  ///
  /// V₀ is computed from Doodson numbers and astronomical arguments.
  /// u is the nodal angle correction.
  double equilibriumPhase(String constituent) {
    final doodson = doodsonNumbers[constituent];
    if (doodson == null) return 0.0;

    // Calculate V₀ from Doodson numbers: V₀ = D1*τ + D2*s + D3*h + D4*p + D5*(-N) + D6*p_s
    // where τ = h + hourAngle (in this simplified form, we use mean solar time)

    // Mean lunar time (tau): represents the hour angle of the mean Moon
    // τ = 15° * hour + h - s (approximately)
    final tau = hourOfDay * 15.0 + h - s;

    final v0 =
        doodson[0] * tau +
        doodson[1] * s +
        doodson[2] * h +
        doodson[3] * p +
        doodson[4] * (-n) + // Note: Doodson uses N' = -N
        doodson[5] * ps;

    // Add nodal correction u
    final u = nodalAngle(constituent);

    return _normalize(v0 + u);
  }

  /// Calculate the nodal modulation factor f for a constituent.
  ///
  /// Nodal factors account for the 18.6-year cycle of the lunar node,
  /// which modulates the amplitude of tidal constituents.
  ///
  /// f is typically between 0.8 and 1.2 for most constituents.
  double nodalFactor(String constituent) {
    // Cosine of node longitude (in radians) for nodal modulation
    final nRad = degreesToRadians(n);
    final cosN = math.cos(nRad);

    // Nodal factors from IHO/NOAA formulas
    // These are empirical formulas that approximate the satellite corrections
    switch (constituent) {
      // Semi-diurnal constituents
      case 'M2':
        return 1.0 - 0.037 * cosN;
      case 'S2':
        return 1.0; // S2 has no nodal modulation
      case 'N2':
        return 1.0 - 0.037 * cosN;
      case 'K2':
        return 1.024 + 0.286 * cosN;
      case '2N2':
        return 1.0 - 0.037 * cosN;
      case 'Mu2':
        return 1.0 - 0.037 * cosN;
      case 'Nu2':
        return 1.0 - 0.037 * cosN;
      case 'L2':
        // L2 nodal factor - simplified formula using lunar inclination effect
        // Uses cosN like other semi-diurnal constituents
        return 1.0 - 0.037 * cosN;
      case 'T2':
        return 1.0;
      case 'Eps2':
        return 1.0 - 0.037 * cosN;
      case 'La2':
        return 1.0 - 0.037 * cosN;
      case 'R2':
        return 1.0;

      // Diurnal constituents
      case 'K1':
        return 1.006 + 0.115 * cosN;
      case 'O1':
        return 1.009 + 0.187 * cosN;
      case 'P1':
        return 1.0;
      case 'Q1':
        return 1.009 + 0.187 * cosN;
      case '2Q1':
        return 1.009 + 0.187 * cosN;
      case 'Sig1':
        return 1.009 + 0.187 * cosN;
      case 'Rho1':
        return 1.009 + 0.187 * cosN;
      case 'M1':
        return 1.015 + 0.036 * cosN;
      case 'Chi1':
        return 1.0;
      case 'Pi1':
        return 1.0;
      case 'Phi1':
        return 1.0;
      case 'The1':
        return 1.0;
      case 'J1':
        return 1.006 + 0.115 * cosN;
      case 'OO1':
        return 1.185 + 0.415 * cosN;

      // Long-period constituents
      case 'Mf':
        return 1.043 + 0.414 * cosN;
      case 'Mm':
        return 1.0 - 0.13 * cosN;
      case 'Ssa':
        return 1.0;
      case 'Sa':
        return 1.0;
      case 'Msqm':
        return 1.0;
      case 'Mtm':
        return 1.0 + 0.414 * cosN;

      // Shallow-water constituents
      case 'M4':
        final fM2 = 1.0 - 0.037 * cosN;
        return fM2 * fM2;
      case 'MS4':
        return 1.0 - 0.037 * cosN;

      default:
        return 1.0;
    }
  }

  /// Calculate the nodal angle u for a constituent in degrees.
  ///
  /// The nodal angle represents a phase shift due to the lunar node position.
  /// It's added to V₀ to get the complete equilibrium argument.
  double nodalAngle(String constituent) {
    // Node-related angles in radians
    final nRad = degreesToRadians(n);
    final sinN = math.sin(nRad);

    // Nodal angles from IHO/NOAA formulas (in degrees)
    switch (constituent) {
      // Semi-diurnal constituents
      case 'M2':
        return -2.1 * sinN;
      case 'S2':
        return 0.0;
      case 'N2':
        return -2.1 * sinN;
      case 'K2':
        return -17.7 * sinN;
      case '2N2':
        return -2.1 * sinN;
      case 'Mu2':
        return -2.1 * sinN;
      case 'Nu2':
        return -2.1 * sinN;
      case 'L2':
        return -2.1 * sinN; // Simplified
      case 'T2':
        return 0.0;
      case 'Eps2':
        return -2.1 * sinN;
      case 'La2':
        return -2.1 * sinN;
      case 'R2':
        return 0.0;

      // Diurnal constituents
      case 'K1':
        return -8.9 * sinN;
      case 'O1':
        return 10.8 * sinN;
      case 'P1':
        return 0.0;
      case 'Q1':
        return 10.8 * sinN;
      case '2Q1':
        return 10.8 * sinN;
      case 'Sig1':
        return 10.8 * sinN;
      case 'Rho1':
        return 10.8 * sinN;
      case 'M1':
        return 2.7 * sinN;
      case 'Chi1':
        return 0.0;
      case 'Pi1':
        return 0.0;
      case 'Phi1':
        return 0.0;
      case 'The1':
        return -8.9 * sinN;
      case 'J1':
        return -8.9 * sinN;
      case 'OO1':
        return -36.7 * sinN;

      // Long-period constituents
      case 'Mf':
        return -23.7 * sinN;
      case 'Mm':
        return 0.0;
      case 'Ssa':
        return 0.0;
      case 'Sa':
        return 0.0;
      case 'Msqm':
        return 0.0;
      case 'Mtm':
        return -23.7 * sinN;

      // Shallow-water constituents
      case 'M4':
        return -4.2 * sinN;
      case 'MS4':
        return -2.1 * sinN;

      default:
        return 0.0;
    }
  }

  /// Convert DateTime to Julian Date.
  ///
  /// Julian Date is a continuous count of days since noon on January 1, 4713 BC.
  /// It's the standard time system used in astronomical calculations.
  static double _toJulianDate(DateTime time) {
    final y = time.year;
    final m = time.month;
    final d =
        time.day +
        (time.hour +
                time.minute / 60.0 +
                time.second / 3600.0 +
                time.millisecond / 3600000.0) /
            24.0;

    // Algorithm from Meeus, "Astronomical Algorithms"
    final a = ((14 - m) / 12).floor();
    final y2 = y + 4800 - a;
    final m2 = m + 12 * a - 3;

    // Gregorian calendar
    return d +
        ((153 * m2 + 2) / 5).floor() +
        365 * y2 +
        (y2 / 4).floor() -
        (y2 / 100).floor() +
        (y2 / 400).floor() -
        32045;
  }

  /// Normalize angle to 0-360 degrees.
  static double _normalize(double angle) {
    double result = angle % 360.0;
    if (result < 0) result += 360.0;
    return result;
  }

  /// Calculate hours from reference epoch (J2000.0) to given time.
  ///
  /// This is used for computing the phase argument ω×t in the
  /// harmonic prediction formula.
  static double hoursFromReferenceEpoch(DateTime time) {
    final epoch = DateTime.utc(2000, 1, 1, 0, 0, 0);
    return time.toUtc().difference(epoch).inMilliseconds / 3600000.0;
  }

  @override
  String toString() {
    return 'AstronomicalArguments(T=$T, s=${s.toStringAsFixed(2)}°, '
        'h=${h.toStringAsFixed(2)}°, p=${p.toStringAsFixed(2)}°, '
        'N=${n.toStringAsFixed(2)}°)';
  }
}
