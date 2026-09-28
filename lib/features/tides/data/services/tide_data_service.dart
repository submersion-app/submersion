import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_reader.dart';

/// A model-tier calculator and the grid spacing behind it.
class FesModelData {
  final TideCalculator calculator;
  final double resolutionKm;

  const FesModelData({required this.calculator, required this.resolutionKm});
}

/// Offline FES2022 tide model: harmonic constituents interpolated from the
/// bundled grid (see `FesGridReader`). Heights are relative to mean sea
/// level.
class TideDataService {
  final FesGridReader _reader;

  TideDataService({FesGridReader? reader})
    : _reader = reader ?? FesGridReader.bundled();

  /// Calculator and grid resolution at a location, or null without data.
  Future<FesModelData?> getModelForLocation(
    double latitude,
    double longitude,
  ) async {
    final sample = await _reader.sampleAt(latitude, longitude);
    if (sample == null) return null;
    return FesModelData(
      calculator: TideCalculator(constituents: sample.constituents),
      resolutionKm: sample.resolutionKm,
    );
  }

  /// A [TideCalculator] for a location, or null without data.
  Future<TideCalculator?> getCalculatorForLocation(
    double latitude,
    double longitude,
  ) async => (await getModelForLocation(latitude, longitude))?.calculator;

  /// Whether the model has data for a location.
  Future<bool> hasTideData(double latitude, double longitude) async =>
      await getModelForLocation(latitude, longitude) != null;
}
