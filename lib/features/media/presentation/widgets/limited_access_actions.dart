import 'package:flutter/material.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/presentation/providers/photo_access_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Allow full access" and "Choose photo again", for a photo outside the
/// user's limited selection (media sync program spec 6.3). Each hands off
/// to the system, and [onChanged] fires once the user is back, so the
/// caller can look for the photo again.
class LimitedAccessActions extends ConsumerStatefulWidget {
  const LimitedAccessActions({super.key, required this.onChanged});

  /// Called once the user is back from either action, whether or not it
  /// succeeded: they may have changed access in the meantime.
  final VoidCallback onChanged;

  @override
  ConsumerState<LimitedAccessActions> createState() =>
      _LimitedAccessActionsState();
}

class _LimitedAccessActionsState extends ConsumerState<LimitedAccessActions> {
  /// Armed while the user is in the system settings. Opening them returns at
  /// once, with the user still there, so the refresh waits for the app to
  /// come back to the foreground, once per trip.
  AppLifecycleListener? _returning;

  final _log = LoggerService.forClass(
    LimitedAccessActions,
    category: LogCategory.media,
  );

  @override
  void dispose() {
    _returning?.dispose();
    super.dispose();
  }

  void _disarm() {
    _returning?.dispose();
    _returning = null;
  }

  void _changed() {
    if (!mounted) return;
    // The shared gallery queries show the library as it was; a selection
    // changed under the same permission would stay invisible behind them.
    ref.read(assetResolutionServiceProvider).forgetGalleryQueries();
    widget.onChanged();
  }

  Future<void> _openSettings() async {
    _disarm();
    // Armed before the hand-off, so a quick return cannot slip past it.
    _returning = AppLifecycleListener(
      onResume: () {
        _disarm();
        _changed();
      },
    );
    try {
      await ref.read(photoAccessActionsProvider).openSettings();
    } on Object catch (e, stackTrace) {
      // The settings never opened, so there is no return to wait for.
      _log.warning('Could not open settings', error: e, stackTrace: stackTrace);
      _disarm();
      _changed();
    }
  }

  Future<void> _chooseMorePhotos() async {
    try {
      // Returns when the selection sheet closes.
      await ref.read(photoAccessActionsProvider).chooseMorePhotos();
    } on Object catch (e, stackTrace) {
      // An OS without the limited-selection sheet, or a platform channel
      // failure. The buttons are an offer; a failure is logged, not shown.
      _log.warning(
        'Could not open the photo selection',
        error: e,
        stackTrace: stackTrace,
      );
    }
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          onPressed: _openSettings,
          child: Text(l10n.media_limitedAccess_allowFullAccess),
        ),
        TextButton(
          onPressed: _chooseMorePhotos,
          child: Text(l10n.media_limitedAccess_choosePhotoAgain),
        ),
      ],
    );
  }
}
