import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/device_location_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The map's Show my location control (issue #4808): finds the device, draws
/// the blue dot through [deviceLocationNotifierProvider] and hands the fix to
/// [onLocated] so the map can move its camera there.
///
/// The maps used to put this crosshair icon on their Fit all button, which
/// read as a locate button that did nothing. Fit all now has its own icon.
class MyLocationButton extends ConsumerStatefulWidget {
  const MyLocationButton({
    super.key,
    required this.onLocated,
    this.iconSize,
    this.isPhone,
  });

  /// Called with the device's position after a fix.
  final ValueChanged<LatLng> onLocated;

  /// Matches the neighbouring map controls; null keeps the theme's size.
  final double? iconSize;

  /// Whether a failed fix offers the app's settings. Defaults to the host
  /// platform; tests pin it.
  final bool? isPhone;

  @override
  ConsumerState<MyLocationButton> createState() => _MyLocationButtonState();
}

class _MyLocationButtonState extends ConsumerState<MyLocationButton> {
  bool _locating = false;

  bool get _isPhone =>
      widget.isPhone ??
      (!kIsWeb && (HostPlatform.isIOS || HostPlatform.isAndroid));

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final l10n = context.l10n;
    final service = ref.read(locationServiceProvider);
    try {
      // Coordinates are all the map needs; skip the place-name lookup.
      final result = await service.getCurrentLocation(includeGeocoding: false);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _isPhone
              ? SnackBar(
                  content: Text(
                    l10n.diveSites_edit_snackbar_locationUnavailableMobile,
                  ),
                  persist: false,
                  action: SnackBarAction(
                    label: l10n.diveSites_edit_snackbar_locationSettings,
                    onPressed: () => service.openAppSettings(),
                  ),
                )
              : SnackBar(
                  content: Text(
                    l10n.diveSites_edit_snackbar_locationUnavailableDesktop,
                  ),
                ),
        );
        return;
      }
      final point = LatLng(result.latitude, result.longitude);
      ref.read(deviceLocationNotifierProvider.notifier).located(point);
      widget.onLocated(point);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.iconSize ?? IconTheme.of(context).size ?? 24;
    final l10n = context.l10n;
    return IconButton(
      // Busy while locating, so a screen reader announces more than the
      // button's name during a fix that can take several seconds.
      tooltip: _locating
          ? l10n.diveLog_edit_gettingLocation
          : l10n.maps_myLocation_tooltip,
      onPressed: _locate,
      icon: _locating
          ? SizedBox.square(
              dimension: size,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Icon(Icons.my_location, size: widget.iconSize),
    );
  }
}
