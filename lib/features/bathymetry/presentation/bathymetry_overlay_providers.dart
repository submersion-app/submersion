import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_image.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The rendered depth overlay for a quantized bathymetry cell, or null
/// when no grid resolves there. FutureProvider memoizes the value per key,
/// which keeps the SAME Uint8List instance alive across reads: that
/// reference identity is what lets MemoryImage hit Flutter's ImageCache.
/// Appearance or unit changes invalidate and re-render.
final bathymetryOverlayProvider =
    FutureProvider.family<BathymetryOverlayData?, ({double lat, double lon})>((
      ref,
      cell,
    ) async {
      final grid = await ref.watch(bathymetryGridProvider(cell).future);
      if (grid == null) return null;
      // Normalize the fields the overlay never reads (the toggle itself,
      // the wall threshold) so changing them cannot invalidate this
      // provider and re-render the PNG; Equatable equality on the selected
      // value does the rest.
      final appearance = ref.watch(
        settingsProvider.select(
          (s) => s.seascapeAppearance.copyWith(
            mapDepthOverlay: false,
            wallAngleDeg: 0,
            surfaceMode: SeascapeSurfaceMode.depth,
          ),
        ),
      );
      final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
      return buildBathymetryOverlay(
        grid: grid,
        appearance: appearance,
        displayUnitInMeters: depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
        depthSymbol: depthUnit.symbol,
      );
    });
