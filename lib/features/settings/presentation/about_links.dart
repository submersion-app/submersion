import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/browser_launch.dart';
import 'package:submersion/shared/utils/link_open.dart';

/// The URL for the GitHub issues page, used by [launchReportIssue].
const reportIssueUrl = 'https://github.com/submersion-app/submersion/issues';

/// The URL for the published user guide, used by [launchUserGuide].
const userGuideUrl = 'https://submersion.app/guide/';

/// Opens the GitHub issues page in an external browser. Falls back to a
/// snackbar with a copy-link action if the launch fails. [launch] is
/// injectable so tests never open a real browser.
Future<void> launchReportIssue(
  BuildContext context, {
  UrlLaunch launch = openInBrowser,
}) => openLinkOrOfferCopy(
  context,
  Uri.parse(reportIssueUrl),
  launch: launch,
  failureMessage: context.l10n.settings_about_reportIssue_snackbar,
);

/// Opens the user guide in an external browser, with the same copy-link
/// fallback as [launchReportIssue] (issue #4145).
Future<void> launchUserGuide(
  BuildContext context, {
  UrlLaunch launch = openInBrowser,
}) => openLinkOrOfferCopy(
  context,
  Uri.parse(userGuideUrl),
  launch: launch,
  failureMessage: context.l10n.settings_about_userGuide_snackbar,
);
