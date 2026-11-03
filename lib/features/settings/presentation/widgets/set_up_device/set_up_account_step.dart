import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/platform/web/remember_credentials_provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_chooser.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/features/setup_wizard/domain/unit_preset_detector.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Step 1, "Where should Submersion keep your data?" (issue #3482, spec
/// 6.4): the account sheet inline, the accounts signed in here first. A
/// choice is held for the next steps and writes nothing: no feature is
/// turned on here.
class SetUpAccountStep extends ConsumerWidget {
  const SetUpAccountStep({
    super.key,
    required this.navigation,
    this.consequenceOf,
    this.onRestoreFile,
    this.onTryDemo,
  });

  final SetUpStepNavigation navigation;

  /// What choosing an account will do to sync, shown before the choice is
  /// taken. Defaults to the Sync page's own switch warning.
  final String? Function(AccountGroup choice)? consequenceOf;

  /// Restores from a backup file instead. Defaults to Backups' Restore from
  /// a file.
  final Future<void> Function()? onRestoreFile;

  /// Opens the sample logbook instead. Defaults to the question and the
  /// download the welcome screen's link uses natively.
  final void Function(DemoPackage package)? onTryDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final flow = ref.read(setUpFlowProvider.notifier);
    final chosen = ref.watch(setUpFlowProvider);
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    // Run again, the step starts from the account sync already uses.
    final current = currentSyncGroup(groups);
    final account = chosen ?? current;
    final host = navigation.host;
    final browser = ref.watch(deviceCapabilitiesProvider).isBrowser;
    return SetUpStepScaffold(
      title: l10n.settings_setUpDevice_account_title,
      // In the wizard the first step has a step before it, and Not now
      // moves on without an account (spec 6.6).
      backLabel: host.inWizard
          ? l10n.common_action_back
          : l10n.settings_setUpDevice_notNow,
      onBack: navigation.onBack,
      // A browser's connect step offers to continue without a sync store
      // where native offers Not now (issue #4121).
      secondary: host.inWizard
          ? TextButton(
              onPressed: navigation.onNoLibrary ?? navigation.onNotNow,
              child: Text(
                navigation.onNoLibrary != null
                    ? l10n.web_continueWithoutSync
                    : l10n.settings_setUpDevice_notNow,
              ),
            )
          : null,
      primaryLabel: l10n.settings_setUpDevice_next,
      onPrimary: account == null
          ? null
          : () {
              flow.choose(account);
              navigation.onNext();
            },
      children: [
        AccountChooser(
          embedded: true,
          offerHints: true,
          signedInFirst: true,
          allowedKinds: syncAccountKinds,
          currentKey: account?.key,
          consequenceOf:
              consequenceOf ??
              (choice) =>
                  syncSwitchConsequence(context, ref, choice, current: current),
          onChosen: (choice) {
            if (choice is ChoseAccount) {
              flow.choose(choice.group);
              navigation.onNext();
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settings_setUpDevice_account_note,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        // A browser forgets the credentials when the tab closes unless the
        // user asks to be remembered (issue #4121).
        if (browser)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.web_rememberOnThisDevice_title),
            subtitle: Text(l10n.web_rememberOnThisDevice_subtitle),
            value: ref.watch(rememberCredentialsProvider),
            onChanged: (value) =>
                ref.read(rememberCredentialsProvider.notifier).set(value),
          ),
        // Native first run offers its own Restore a backup file; a browser's
        // opens here, so it offers it here (issue #4121).
        if (ref.watch(deviceCapabilitiesProvider).backupRestore &&
            (host != SetUpHost.firstRun || browser))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onRestoreFile ?? () => restoreFromFile(context, ref),
              child: Text(
                host == SetUpHost.firstRun
                    ? l10n.setup_existing_restore_title
                    : l10n.settings_setUpDevice_account_backupFile,
              ),
            ),
          ),
        // A browser's first run opens here rather than on the welcome
        // screen, so the sample logbook is offered here when the site ships
        // one (issue #4121).
        if (browser && host == SetUpHost.firstRun)
          _TryDemoLink(onTryDemo: onTryDemo),
      ],
    );
  }
}

class _TryDemoLink extends ConsumerWidget {
  const _TryDemoLink({this.onTryDemo});

  final void Function(DemoPackage package)? onTryDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(demoAvailabilityProvider).value;
    if (package == null || !ref.watch(deviceCapabilitiesProvider).demoMode) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () =>
            (onTryDemo ?? (p) => _askAndEnter(context, p))(package),
        child: Text(context.l10n.demo_welcome_title),
      ),
    );
  }

  static void _askAndEnter(BuildContext context, DemoPackage package) =>
      askAndEnterDemo(
        context,
        fromFirstRun: true,
        package: package,
        units: demoUnitsForPreset(
          presetForLocale(WidgetsBinding.instance.platformDispatcher.locale),
        ),
      );
}
