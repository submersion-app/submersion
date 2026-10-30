import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_account_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_backups_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_done_view.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_photos_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/device_kind.dart';

/// Builds one step's body with the navigation it leaves by.
typedef SetUpStepBody =
    Widget Function(SetUpStep step, SetUpStepNavigation navigation);

/// Set up this device as a pushed Settings page (issue #3482, spec 6.4):
/// the four steps one at a time, then the done view. The page decides which
/// step shows; each step only says how it leaves.
class SetUpDevicePage extends ConsumerStatefulWidget {
  const SetUpDevicePage({
    super.key,
    this.start,
    this.again = false,
    @visibleForTesting this.stepBody,
  });

  /// The page a `/settings/setup` location names: `step=<name>` opens that
  /// step, `again=true` reruns the flow from the first.
  factory SetUpDevicePage.fromUri(Uri uri) => SetUpDevicePage(
    start: SetUpStep.values.asNameMap()[uri.queryParameters['step']],
    again: uri.queryParameters['again'] == 'true',
  );

  static const doneKey = ValueKey('setUpDone');

  /// The step to open; null opens the one the card would continue to.
  final SetUpStep? start;

  /// Reruns the flow from the first step with every step shown, and shows
  /// a hidden card again (spec 6.3).
  final bool again;

  /// Stands in for the real steps in tests.
  final SetUpStepBody? stepBody;

  @override
  ConsumerState<SetUpDevicePage> createState() => _SetUpDevicePageState();
}

class _SetUpDevicePageState extends ConsumerState<SetUpDevicePage> {
  SetUpStep? _step;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.again) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(setUpCardPrefsNotifierProvider.notifier).setHidden(false);
        }
      });
    }
  }

  void _close() => Navigator.of(context).maybePop();

  void _go(int delta) {
    final index = SetUpStep.values.indexOf(_step!) + delta;
    if (index < 0) {
      _close();
    } else if (index >= SetUpStep.values.length) {
      setState(() => _done = true);
    } else {
      setState(() => _step = SetUpStep.values[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(setUpProgressProvider);
    // Chosen once: the step the card would continue to, or the first.
    _step ??=
        widget.start ??
        (widget.again
            ? SetUpStep.account
            : progress == null
            ? null
            : progress.next ?? SetUpStep.account);
    final step = _step;
    final l10n = context.l10n;
    final Widget body;
    if (_done) {
      body = KeyedSubtree(
        key: SetUpDevicePage.doneKey,
        child: SetUpDoneView(onDone: _close),
      );
    } else if (step == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final navigation = SetUpStepNavigation(
        onNext: () => _go(1),
        onBack: () => _go(-1),
        onNotNow: _close,
        onSkip: step == SetUpStep.photos
            ? () => setState(() => _done = true)
            : null,
      );
      body = KeyedSubtree(
        key: ValueKey(step),
        child: (widget.stepBody ?? _stepBody)(step, navigation),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings_setUpDevice_title(deviceKindArg(deviceKindOf(context))),
        ),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _stepBody(SetUpStep step, SetUpStepNavigation navigation) =>
      switch (step) {
        SetUpStep.account => SetUpAccountStep(navigation: navigation),
        SetUpStep.sync => SetUpSyncStep(navigation: navigation),
        SetUpStep.backups => SetUpBackupsStep(navigation: navigation),
        SetUpStep.photos => SetUpPhotosStep(navigation: navigation),
      };
}
