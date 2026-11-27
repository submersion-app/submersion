import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// Asks for the photo or video on screen to be analysed for marine life
/// (issues #4668, #4675), once it has been shown a moment. Draws nothing.
/// A video is scanned a chunk at a time; leaving it stops the scan, and
/// coming back resumes it.
///
/// The viewer mounts one for the current item only, never for the
/// neighbouring pages the gallery builds ahead of a swipe. A photo swiped
/// past within [dwell] is never asked for, and each photo is asked for at
/// most once while this stays mounted, unless its request was dropped
/// before it ran. A location that arrives after the request (the dive was
/// still loading) is passed on. It also keeps the app's decisions in step
/// with the photo's species tags as they change.
class IdentificationTrigger extends ConsumerStatefulWidget {
  const IdentificationTrigger({
    super.key,
    required this.item,
    this.location,
    this.dwell = const Duration(milliseconds: 400),
  });

  final MediaItem item;

  /// Where the photo was taken: its own position, else its dive's site.
  final GeoPoint? location;
  final Duration dwell;

  @override
  ConsumerState<IdentificationTrigger> createState() =>
      _IdentificationTriggerState();
}

class _IdentificationTriggerState extends ConsumerState<IdentificationTrigger>
    with WidgetsBindingObserver {
  final _requested = <String>{};
  Timer? _timer;

  /// Whether the viewer is on screen: false while another full page covers
  /// it (a species page), when a video's scan is stopped. A sheet over the
  /// viewer leaves it showing.
  var _showing = true;

  /// The app went to the background (not merely lost focus): a video's
  /// scan stopped there, and resumes when it is back.
  var _wasAway = false;

  /// The service asked, kept for [dispose], where `ref` may no longer be
  /// read.
  MediaIdentificationService? _service;

  /// Photos, and videos where they are scanned (not Linux, which has no
  /// video player).
  bool get _applies =>
      marineLifeIdEnabled &&
      (widget.item.mediaType == MediaType.photo ||
          (widget.item.mediaType == MediaType.video &&
              visionVideoRuns(defaultTargetPlatform)));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Routes under a full page run with tickers off; under a sheet, on.
    final showing = TickerMode.valuesOf(context).enabled;
    if (showing == _showing) return;
    _showing = showing;
    final item = widget.item;
    if (!showing) {
      _timer?.cancel();
      if (marineLifeIdEnabled &&
          ref.read(mediaIdentificationServiceProvider).cancelPending(item.id)) {
        _requested.remove(item.id);
      }
    } else {
      _schedule();
    }
  }

  /// A video's scan stops in the background; back in the foreground with
  /// the video still on screen, it carries on (issue #4675).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasAway = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_wasAway) return;
    _wasAway = false;
    final item = widget.item;
    if (_showing &&
        _applies &&
        item.mediaType == MediaType.video &&
        _requested.contains(item.id)) {
      _ask(item);
    }
  }

  @override
  void didUpdateWidget(IdentificationTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    final item = widget.item;
    if (oldWidget.item.id == item.id) {
      final location = widget.location;
      if (_applies &&
          _showing &&
          location != null &&
          location != oldWidget.location &&
          _requested.contains(item.id)) {
        _ask(item);
      }
      return;
    }
    _timer?.cancel();
    if (marineLifeIdEnabled &&
        ref
            .read(mediaIdentificationServiceProvider)
            .cancelPending(oldWidget.item.id)) {
      // Never looked at: ask again if the diver comes back to it.
      _requested.remove(oldWidget.item.id);
    }
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _service?.cancelPending(widget.item.id);
    super.dispose();
  }

  void _schedule() {
    if (!_applies || !_showing || _requested.contains(widget.item.id)) {
      return;
    }
    final item = widget.item;
    _timer = Timer(widget.dwell, () {
      if (!mounted || widget.item.id != item.id) return;
      _requested.add(item.id);
      _ask(item);
    });
  }

  void _ask(MediaItem item) {
    final service = ref.read(mediaIdentificationServiceProvider);
    _service = service;
    unawaited(service.request(item, location: widget.location));
  }

  @override
  Widget build(BuildContext context) {
    if (_applies) {
      final id = widget.item.id;
      ref.listen(mediaTagChipsProvider(id), (previous, next) {
        if (previous?.value == next.value || !next.hasValue) return;
        unawaited(ref.read(mediaIdentificationServiceProvider).reconcile(id));
      });
    }
    return const SizedBox.shrink();
  }
}
