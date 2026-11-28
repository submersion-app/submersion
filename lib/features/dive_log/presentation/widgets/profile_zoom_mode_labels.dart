import 'package:submersion/core/constants/profile_zoom_mode.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name the Zoom choice shows for [mode], in the chart options and in
/// Settings alike (issue #5069).
String profileZoomModeLabel(AppLocalizations l10n, ProfileZoomMode mode) =>
    switch (mode) {
      ProfileZoomMode.magnifyOverlays => l10n.diveLog_chartOption_zoom_magnify,
      ProfileZoomMode.keepOverlaysInView =>
        l10n.diveLog_chartOption_zoom_keepInView,
      ProfileZoomMode.timeOnly => l10n.diveLog_chartOption_zoom_timeOnly,
    };
