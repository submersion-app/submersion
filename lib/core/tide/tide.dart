/// Harmonic tidal prediction module for Submersion.
///
/// This module provides offline tide calculations using harmonic analysis,
/// the same mathematical approach used by NOAA and international
/// hydrographic offices.
///
/// ## Overview
///
/// Tidal prediction uses harmonic constituents - amplitude and phase values
/// that describe how different astronomical forces (Moon, Sun, and their
/// combinations) affect water levels at a specific location.
///
/// ## Usage
///
/// ```dart
/// import 'package:submersion/core/tide/tide.dart';
///
/// // Create calculator with constituent data (from FES model)
/// final calculator = TideCalculator(constituents: {
///   'M2': TideConstituent(name: 'M2', amplitude: 0.523, phase: 127.4),
///   'S2': TideConstituent(name: 'S2', amplitude: 0.187, phase: 156.2),
///   // ... more constituents
/// });
///
/// // Get current tide height
/// final height = calculator.calculateHeight(DateTime.now());
///
/// // Get tide status with state and extremes
/// final status = calculator.getStatus(DateTime.now());
/// print('Tide is ${status.state.displayName}, ${status.currentHeight}m');
///
/// // Find high/low tides for the next 24 hours
/// final extremes = calculator.findExtremes(
///   start: DateTime.now(),
///   end: DateTime.now().add(Duration(hours: 24)),
/// );
/// ```
///
/// ## Data Sources
///
/// Constituent data can come from:
/// - FES2014/FES2022 global ocean tide models (via PyFES extraction)
/// - NOAA harmonic constants database
/// - UK Hydrographic Office data
/// - Australian BOM tide data
///
/// See `scripts/tide/` for extraction tools.
library;

// Constants
export 'constants/harmonic_constituents.dart';

// Core calculator
export 'astronomical_arguments.dart';
export 'tide_calculator.dart';

// Entities
export 'entities/tide_constituent.dart';
export 'entities/tide_extremes.dart';
export 'entities/tide_prediction.dart';
