import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_message_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why a saved computer cannot be downloaded from directly.
enum DcNoDirectDownloadReason {
  /// No stored Bluetooth address or USB port to connect to.
  noConnection,

  /// The computer connects over USB, and this platform has no USB host.
  usbUnavailable,
}

/// Terminal view for a saved computer the app cannot download from directly.
///
/// A computer that reached the library through a file or cloud import has no
/// stored Bluetooth address or USB descriptor, so there is nothing to connect
/// to. Garmin watches are the common case: they are not libdivecomputer
/// devices at all. Their dives arrive as FIT files, so the view points at the
/// file import instead of leaving the download spinning (issue #1858).
///
/// Where Submersion reads Garmin watches itself (Windows, issue #4223), a
/// Garmin can be downloaded after all, so the view says so: with a watch
/// connected it offers the download first, and without one it asks for the
/// watch instead of a manual copy.
///
/// A USB computer saved on a desktop also syncs to iOS, which has no USB
/// host; there the view says to download it on a desktop (issue #2837).
class DcNoDirectDownloadView extends StatelessWidget {
  const DcNoDirectDownloadView({
    super.key,
    required this.computer,
    required this.onImportFromFile,
    required this.onDone,
    this.reason = DcNoDirectDownloadReason.noConnection,
    this.readsConnectedWatches = false,
    this.onDownloadFromWatch,
  });

  final DiveComputer computer;
  final VoidCallback onImportFromFile;

  /// True where Submersion reads a connected Garmin watch directly
  /// (Windows). Only changes the wording for a Garmin with no watch
  /// connected.
  final bool readsConnectedWatches;

  /// Downloads the dives from the Garmin watch that is plugged in. Only for
  /// a Garmin computer; ignored for any other.
  final VoidCallback? onDownloadFromWatch;
  final VoidCallback onDone;
  final DcNoDirectDownloadReason reason;

  bool get _isGarmin => computer.manufacturer?.trim().toLowerCase() == 'garmin';

  /// A Garmin is never downloaded directly, so its FIT-file guidance wins
  /// over the USB explanation.
  bool get _explainsUsb =>
      reason == DcNoDirectDownloadReason.usbUnavailable && !_isGarmin;

  bool get _watchConnected => _isGarmin && onDownloadFromWatch != null;

  /// A Garmin that could be downloaded here, once its watch is connected.
  bool get _awaitsWatch =>
      _isGarmin && !_watchConnected && readsConnectedWatches;

  String _title(BuildContext context) {
    final l10n = context.l10n;
    if (_watchConnected) {
      return l10n.importWizard_dc_downloadFromGarminTitle(computer.displayName);
    }
    if (_awaitsWatch) {
      return l10n.importWizard_dc_connectGarminTitle(computer.displayName);
    }
    return l10n.importWizard_dc_noDirectDownload;
  }

  String _body(BuildContext context) {
    final l10n = context.l10n;
    if (_explainsUsb) {
      return l10n.importWizard_dc_noUsbOnThisPlatformBody(computer.displayName);
    }
    if (_watchConnected) {
      return l10n.importWizard_dc_noDirectDownloadGarminConnectedBody;
    }
    if (_awaitsWatch) return l10n.importWizard_dc_garminUnpluggedBody;
    return _isGarmin
        ? l10n.importWizard_dc_noDirectDownloadGarminBody
        : l10n.importWizard_dc_noDirectDownloadBody(computer.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final download = _watchConnected ? onDownloadFromWatch : null;
    if (download != null) {
      return DcMessageLayout(
        icon: Icons.watch,
        title: _title(context),
        body: _body(context),
        actionIcon: Icons.download,
        actionLabel: l10n.importWizard_dc_downloadFromWatch,
        onAction: download,
        secondaryActionIcon: Icons.upload_file,
        secondaryActionLabel: l10n.importWizard_dc_importFromFile,
        onSecondaryAction: onImportFromFile,
        onDone: onDone,
      );
    }
    return DcMessageLayout(
      icon: _explainsUsb
          ? Icons.usb_off
          : _awaitsWatch
          ? Icons.watch
          : Icons.file_open_outlined,
      title: _title(context),
      body: _body(context),
      actionIcon: Icons.upload_file,
      actionLabel: l10n.importWizard_dc_importFromFile,
      onAction: onImportFromFile,
      onDone: onDone,
    );
  }
}
