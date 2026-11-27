import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/build_date_label.dart';
import 'package:submersion/features/settings/presentation/widgets/submersion_about_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Version 1.8.5.412", badged as beta on the beta channel. Empty while the
/// package details load, or when they cannot be read.
String watchAboutVersionLabel(BuildContext context, WidgetRef ref) {
  final isBetaChannel =
      UpdateChannelConfig.isAutoUpdateEnabled &&
      ref.watch(releaseChannelProvider) == ReleaseChannel.beta;
  return ref
      .watch(packageInfoProvider)
      .when(
        data: (info) {
          final base = context.l10n.settings_about_version(
            formatAppVersion(info),
          );
          return isBetaChannel
              ? context.l10n.settings_updates_channelBadgeBeta(base)
              : base;
        },
        loading: () => '',
        error: (_, _) => '',
      );
}

/// Opens the About Submersion dialog: the app's icon and name, its version
/// and build date, and what it is. Settings opens it from its About section
/// and Home from the logo, so both show the same dialog.
///
/// The dialog reads the version itself, so it fills in as soon as the
/// package details load rather than showing what the caller last saw. On
/// the root navigator and dismissed by a tap outside, as Flutter's own
/// showAboutDialog opens its dialog.
Future<void> showAboutSubmersion(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) => SubmersionAboutDialog(
      applicationName: context.l10n.settings_about_appName,
      applicationVersion: watchAboutVersionLabel(context, ref),
      builtOn: watchBuildDateLabel(context, ref),
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/icon/icon.png', width: 64, height: 64),
      ),
      children: [Text(context.l10n.settings_about_description)],
    ),
  ),
);
