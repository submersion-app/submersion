/// Tidal harmonic constituent definitions for FES2014/FES2022 models.
///
/// This file contains the astronomical parameters needed to compute tidal
/// predictions using harmonic analysis. The data is based on:
/// - FES2014/FES2022 ocean tide models from CNES/LEGOS
/// - IHO standards for tidal constituent definitions
/// - NOAA CO-OPS tidal prediction methods
///
/// Each constituent represents a specific astronomical forcing:
/// - Semi-diurnal (period ~12 hours): M2, S2, N2, K2, etc.
/// - Diurnal (period ~24 hours): K1, O1, P1, Q1, etc.
/// - Long-period (weeks to months): Mf, Mm, Ssa, Sa
/// - Shallow-water (overtides): M4, MS4, MN4, etc.
library;

/// Total number of tidal constituents supported (matching FES2014)
const int tidalConstituentCount = 34;

/// Standard constituent names in FES order.
///
/// The first 8 are the "major" constituents that contribute most of the
/// tidal signal at most locations.
const List<String> constituentNames = [
  // Major semi-diurnal constituents
  'M2', // Principal lunar semi-diurnal (dominant at most locations)
  'S2', // Principal solar semi-diurnal
  'N2', // Larger lunar elliptic semi-diurnal
  'K2', // Luni-solar semi-diurnal
  // Major diurnal constituents
  'K1', // Luni-solar diurnal (often largest diurnal)
  'O1', // Principal lunar diurnal
  'P1', // Principal solar diurnal
  'Q1', // Larger lunar elliptic diurnal
  // Additional semi-diurnal constituents
  '2N2', // Lunar elliptic semi-diurnal (second order)
  'Mu2', // Variational semi-diurnal
  'Nu2', // Larger lunar evectional semi-diurnal
  'L2', // Smaller lunar elliptic semi-diurnal
  'T2', // Larger solar elliptic semi-diurnal
  'Eps2', // Lunar semi-diurnal
  'La2', // Smaller lunar evectional semi-diurnal (Lambda2)
  'R2', // Smaller solar elliptic semi-diurnal
  // Additional diurnal constituents
  '2Q1', // Lunar elliptic diurnal (second order)
  'Sig1', // Lunar diurnal (Sigma1)
  'Rho1', // Larger lunar evectional diurnal
  'M1', // Smaller lunar elliptic diurnal
  'Chi1', // Lunar diurnal
  'Pi1', // Solar diurnal
  'Phi1', // Solar diurnal
  'The1', // Lunar diurnal (Theta1)
  'J1', // Smaller lunar elliptic diurnal
  'OO1', // Lunar diurnal (second order)
  // Long-period constituents
  'Mf', // Lunar fortnightly
  'Mm', // Lunar monthly
  'Ssa', // Solar semi-annual
  'Sa', // Solar annual
  'Msqm', // Shallow water constituent
  'Mtm', // Shallow water constituent
  // Shallow-water (overtide) constituents
  'M4', // First overtide of M2
  'MS4', // Compound of M2 and S2
];

/// Angular speeds in degrees per hour for each constituent.
///
/// The speed determines how fast the constituent cycles:
/// - Semi-diurnal: ~28-30°/hr (2 cycles per day)
/// - Diurnal: ~13-16°/hr (1 cycle per day)
/// - Long-period: <1°/hr (weeks to years)
///
/// Values from IHO Tidal Constituent definitions.
const Map<String, double> constituentSpeeds = {
  // Semi-diurnal (period ~12 hours)
  'M2': 28.9841042, // 12.42 hours
  'S2': 30.0000000, // 12.00 hours
  'N2': 28.4397295, // 12.66 hours
  'K2': 30.0821373, // 11.97 hours
  '2N2': 27.8953548,
  'Mu2': 27.9682084,
  'Nu2': 28.5125831,
  'L2': 29.5284789,
  'T2': 29.9589333,
  'Eps2': 27.4238337,
  'La2': 29.4556253,
  'R2': 30.0410667,

  // Diurnal (period ~24 hours)
  'K1': 15.0410686, // 23.93 hours
  'O1': 13.9430356, // 25.82 hours
  'P1': 14.9589314, // 24.07 hours
  'Q1': 13.3986609, // 26.87 hours
  '2Q1': 12.8542862,
  'Sig1': 12.9271398,
  'Rho1': 13.4715145,
  'M1': 14.4966939,
  'Chi1': 14.5695476,
  'Pi1': 14.9178647,
  'Phi1': 15.1232059,
  'The1': 15.5125897,
  'J1': 15.5854433,
  'OO1': 16.1391017,

  // Long-period
  'Mf': 1.0980331, // 13.66 days
  'Mm': 0.5443747, // 27.55 days
  'Ssa': 0.0821373, // 182.6 days
  'Sa': 0.0410686, // 365.2 days
  'Msqm': 0.4715211,
  'Mtm': 1.4423708,

  // Shallow-water overtides
  'M4': 57.9682084, // 6.21 hours (2 × M2)
  'MS4': 58.9841042, // 6.10 hours (M2 + S2)
};

/// Doodson numbers for each constituent.
///
/// Doodson numbers encode the relationship between constituents and
/// astronomical arguments. Each 6-digit number represents coefficients
/// for: [τ, s, h, p, N', p_s] where:
/// - τ (tau): Mean lunar time
/// - s: Mean longitude of the Moon
/// - h: Mean longitude of the Sun
/// - p: Mean longitude of lunar perigee
/// - N': Negative mean longitude of ascending lunar node
/// - p_s: Mean longitude of solar perigee (perihelion)
///
/// The Doodson number is encoded as: D1.D2.D3.D4.D5.D6 where each
/// digit has 5 subtracted for historical reasons (so 0 = -5 to 9 = +4).
/// Here we use the actual coefficients directly.
const Map<String, List<int>> doodsonNumbers = {
  // Semi-diurnal
  'M2': [2, 0, 0, 0, 0, 0],
  'S2': [2, 2, -2, 0, 0, 0],
  'N2': [2, -1, 0, 1, 0, 0],
  'K2': [2, 2, 0, 0, 0, 0],
  '2N2': [2, -2, 0, 2, 0, 0],
  'Mu2': [2, -2, 2, 0, 0, 0],
  'Nu2': [2, -1, 2, -1, 0, 0],
  'L2': [2, 1, 0, -1, 0, 0],
  'T2': [2, 2, -3, 0, 0, 1],
  'Eps2': [2, -3, 2, 1, 0, 0],
  'La2': [2, 1, -2, 1, 0, 0],
  'R2': [2, 2, -1, 0, 0, -1],

  // Diurnal
  'K1': [1, 1, 0, 0, 0, 0],
  'O1': [1, -1, 0, 0, 0, 0],
  'P1': [1, 1, -2, 0, 0, 0],
  'Q1': [1, -2, 0, 1, 0, 0],
  '2Q1': [1, -3, 0, 2, 0, 0],
  'Sig1': [1, -3, 2, 0, 0, 0],
  'Rho1': [1, -2, 2, -1, 0, 0],
  'M1': [1, 0, 0, -1, 0, 0],
  'Chi1': [1, 0, 2, -1, 0, 0],
  'Pi1': [1, 1, -3, 0, 0, 1],
  'Phi1': [1, 1, 1, 0, 0, -1],
  'The1': [1, 2, 0, -1, 0, 0],
  'J1': [1, 2, 0, -1, 0, 0],
  'OO1': [1, 3, 0, 0, 0, 0],

  // Long-period
  'Mf': [0, 2, 0, 0, 0, 0],
  'Mm': [0, 1, 0, -1, 0, 0],
  'Ssa': [0, 0, 2, 0, 0, 0],
  'Sa': [0, 0, 1, 0, 0, 0],
  'Msqm': [0, 1, -2, 1, 0, 0],
  'Mtm': [0, 3, 0, -1, 0, 0],

  // Shallow-water
  'M4': [4, 0, 0, 0, 0, 0],
  'MS4': [4, 2, -2, 0, 0, 0],
};

/// Number of tidal species for each constituent.
///
/// - 0: Long-period (period > 1 day)
/// - 1: Diurnal (period ~24 hours)
/// - 2: Semi-diurnal (period ~12 hours)
/// - 4: Quarter-diurnal/shallow-water (period ~6 hours)
const Map<String, int> constituentSpecies = {
  'M2': 2,
  'S2': 2,
  'N2': 2,
  'K2': 2,
  '2N2': 2,
  'Mu2': 2,
  'Nu2': 2,
  'L2': 2,
  'T2': 2,
  'Eps2': 2,
  'La2': 2,
  'R2': 2,
  'K1': 1,
  'O1': 1,
  'P1': 1,
  'Q1': 1,
  '2Q1': 1,
  'Sig1': 1,
  'Rho1': 1,
  'M1': 1,
  'Chi1': 1,
  'Pi1': 1,
  'Phi1': 1,
  'The1': 1,
  'J1': 1,
  'OO1': 1,
  'Mf': 0,
  'Mm': 0,
  'Ssa': 0,
  'Sa': 0,
  'Msqm': 0,
  'Mtm': 0,
  'M4': 4,
  'MS4': 4,
};

/// "Major 8" constituents that typically contribute >90% of tidal signal.
///
/// For quick approximations or when only major constituents are available,
/// these 8 constituents provide a reasonable tide prediction.
const List<String> majorConstituents = [
  'M2',
  'S2',
  'N2',
  'K2',
  'K1',
  'O1',
  'P1',
  'Q1',
];

/// Reference epoch for tidal calculations: January 1, 2000, 00:00 UTC.
///
/// All phase values in FES data are referenced to this epoch.
/// The J2000.0 epoch is a standard astronomical reference.
final DateTime referenceEpoch = DateTime.utc(2000, 1, 1, 0, 0, 0);

/// Convert degrees to radians
double degreesToRadians(double degrees) => degrees * 3.141592653589793 / 180.0;

/// Convert radians to degrees
double radiansToDegrees(double radians) => radians * 180.0 / 3.141592653589793;

/// Normalize angle to 0-360 degrees
double normalizeAngle(double degrees) {
  double result = degrees % 360.0;
  if (result < 0) result += 360.0;
  return result;
}
