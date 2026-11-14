import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A moved map is reported this long after it last moved, so a pan or a
/// pinch reads the catalogue once, where it comes to rest.
const _settle = Duration(milliseconds: 300);

/// Tells the built-in overlay's providers what the map shows.
///
/// A layer that draws nothing: placed among a [FlutterMap]'s children, it
/// sees every camera change, and reports the view once it rests. The first
/// view after the overlay is turned on is reported at once. With the
/// overlay off it reports nothing, so the catalogue is not read.
class BuiltInOverlayBoundsReporter extends ConsumerStatefulWidget {
  const BuiltInOverlayBoundsReporter({super.key});

  @override
  ConsumerState<BuiltInOverlayBoundsReporter> createState() =>
      _BuiltInOverlayBoundsReporterState();
}

class _BuiltInOverlayBoundsReporterState
    extends ConsumerState<BuiltInOverlayBoundsReporter> {
  Timer? _timer;
  bool _reported = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _report(CatalogueBounds bounds) {
    if (!mounted) return;
    _reported = true;
    final notifier = ref.read(builtInOverlayBoundsProvider.notifier);
    if (notifier.state != bounds) notifier.state = bounds;
  }

  @override
  Widget build(BuildContext context) {
    final show = ref.watch(showBuiltInSitesProvider);
    final bounds = catalogueBoundsOf(MapCamera.of(context));
    _timer?.cancel();
    if (!show) {
      // Turned on again, the view then is reported at once.
      _reported = false;
    } else if (!_reported) {
      // A provider cannot be written while the tree builds.
      WidgetsBinding.instance.addPostFrameCallback((_) => _report(bounds));
    } else {
      _timer = Timer(_settle, () => _report(bounds));
    }
    return const SizedBox.shrink();
  }
}

/// What a map shows, as the catalogue is read by.
///
/// The latitudes are the map's own. The longitudes are worked out from the
/// camera's centre, zoom and size: the map reports its visible bounds
/// clamped at 180 degrees, which would cut a view across the antimeridian
/// off at the seam. A view wider than one world is the whole world.
CatalogueBounds catalogueBoundsOf(MapCamera camera) {
  final visible = camera.visibleBounds;
  final south = visible.south.clamp(-90.0, 90.0);
  final north = visible.north.clamp(-90.0, 90.0);
  final size = camera.nonRotatedSize;
  // A turned map shows up to its diagonal east to west.
  final pixels = camera.rotation == 0
      ? size.width
      : math.sqrt(size.width * size.width + size.height * size.height);
  final degreesPerPixel = 360 / (_tilePixels * math.pow(2, camera.zoom));
  final halfSpan = pixels / 2 * degreesPerPixel;
  if (halfSpan >= 180) {
    return CatalogueBounds(south: south, west: -180, north: north, east: 180);
  }
  return CatalogueBounds(
    south: south,
    west: normalizeLongitude(camera.center.longitude - halfSpan),
    north: north,
    east: normalizeLongitude(camera.center.longitude + halfSpan),
  );
}

/// The width of the world at zoom 0, in logical pixels.
const _tilePixels = 256;

/// Says to zoom in when the map's view holds more built-in sites than it
/// marks. Nothing with the overlay off, or when every site in view is
/// marked.
class BuiltInOverlayCaption extends ConsumerWidget {
  const BuiltInOverlayCaption({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showBuiltInSitesProvider) ||
        !ref.watch(builtInOverlayTruncatedProvider)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          context.l10n.diveSites_map_builtIn_zoomIn,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        ),
      ),
    );
  }
}
