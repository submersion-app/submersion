import 'package:equatable/equatable.dart';

/// The mercator-space mapping of a stitched terrain-imagery mosaic. Plain
/// data ON PURPOSE: geometry builds UVs inside compute() isolates, where
/// the ui.Image itself cannot travel; this frame is everything the pure
/// math needs. u/v 0..1 map linearly to these world-mercator coordinates;
/// [v1MercY] deliberately sits below the mosaic's true south tile edge
/// because a 4px white strip is appended to the image (see
/// TerrainImageryService), and [whiteU]/[whiteV] point into that strip.
class TerrainImageryFrame extends Equatable {
  final double u0MercX;
  final double u1MercX;
  final double v0MercY;
  final double v1MercY;
  final double whiteU;
  final double whiteV;

  const TerrainImageryFrame({
    required this.u0MercX,
    required this.u1MercX,
    required this.v0MercY,
    required this.v1MercY,
    required this.whiteU,
    required this.whiteV,
  });

  @override
  List<Object?> get props => [
    u0MercX,
    u1MercX,
    v0MercY,
    v1MercY,
    whiteU,
    whiteV,
  ];
}
