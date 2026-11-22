import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The setup wizard's offer of the species identification model (issue
/// #4881), after the Photos step on a device that can run it. The size line
/// is the confirmation: Download starts the download in the background and
/// moves on at once, and Settings > Data > Photos & videos > Species
/// identification shows how it goes. Skip moves on and leaves every later
/// offer in place.
class SpeciesModelStep extends ConsumerStatefulWidget {
  const SpeciesModelStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  ConsumerState<SpeciesModelStep> createState() => _SpeciesModelStepState();
}

class _SpeciesModelStepState extends ConsumerState<SpeciesModelStep> {
  /// Windows may fetch a hardware engine with the pack; the step says so,
  /// as the Settings confirmation does.
  var _fetchesEngine = false;

  /// The step's own check has answered. Until then only a download under
  /// way shows as it is: any other state left from an earlier visit to
  /// Settings may be stale, and the check would overwrite a download
  /// started meanwhile.
  var _checked = false;

  /// The hardware engine question has answered. Its line is the
  /// confirmation that the download fetches an engine too, so Download
  /// waits for it as well; a failed question counts as no engine.
  var _engineAsked = false;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(speciesPackControllerProvider.notifier);
    // After the first frame: refresh() sets the controller's state, which a
    // build must not do.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_check(controller));
    });
    unawaited(_askAboutEngine(controller));
  }

  Future<void> _askAboutEngine(SpeciesPackController controller) async {
    var fetches = false;
    try {
      fetches = await controller.downloadFetchesHardwareEngine();
    } on Object {
      fetches = false;
    }
    if (!mounted) return;
    setState(() {
      _fetchesEngine = fetches;
      _engineAsked = true;
    });
  }

  Future<void> _check(SpeciesPackController controller) async {
    await controller.refresh();
    if (mounted) setState(() => _checked = true);
  }

  void _download() {
    unawaited(ref.read(speciesPackControllerProvider.notifier).download());
    widget.onNext();
  }

  /// Phones and tablets: a 633 MB download over a cellular plan is worth a
  /// word first.
  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(speciesPackControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: textTheme.bodyMedium),
    );

    final skip = TextButton(
      onPressed: widget.onNext,
      child: Text(l10n.settings_setUpDevice_skip),
    );
    // The size is not known yet, or a state left from an earlier Settings
    // visit may be stale until the step's own check answers, or the hardware
    // engine question is still open: show the check, not a dead Download
    // or a failure that no longer holds.
    final (List<Widget>, String, VoidCallback?, Widget?) checking = (
      [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
      l10n.setup_speciesModel_download,
      null,
      skip,
    );
    final (
      List<Widget> body,
      String primary,
      VoidCallback? onPrimary,
      Widget? secondary,
    ) = switch (state) {
      PackDownloading() || PackInstalling() => (
        [line(l10n.setup_speciesModel_downloading)],
        l10n.settings_setUpDevice_next,
        widget.onNext,
        null,
      ),
      // Any other state may be one left from an earlier visit to Settings,
      // such as a failure while offline: wait for the step's own check.
      _ when !_checked => checking,
      PackChecking() => checking,
      PackNotInstalled() when !_engineAsked => checking,
      PackNotInstalled(:final bytes, :final resumable) => (
        [
          line(l10n.setup_speciesModel_size(formatBytes(bytes))),
          if (_mobile) line(l10n.setup_speciesModel_wifi),
          if (_fetchesEngine) line(l10n.setup_speciesModel_hardware),
        ],
        resumable
            ? l10n.settings_speciesId_resume(formatBytes(bytes))
            : l10n.settings_speciesId_download(formatBytes(bytes)),
        _download,
        skip,
      ),
      PackInstalled() => (
        [line(l10n.setup_speciesModel_installed)],
        l10n.settings_setUpDevice_next,
        widget.onNext,
        null,
      ),
      // Offline, a server error, or no pack this device can take: the
      // diver finds it later in Settings.
      PackFailed() ||
      PackNotPublished() ||
      PackNotForThisDevice() ||
      PackNeedsAppUpdate() ||
      PackUnsupported() => (
        [line(l10n.setup_speciesModel_later)],
        l10n.settings_setUpDevice_next,
        widget.onNext,
        null,
      ),
    };

    return SetUpStepScaffold(
      title: l10n.setup_speciesModel_title,
      intro: visionVideoRuns(defaultTargetPlatform)
          ? l10n.setup_speciesModel_intro
          : l10n.setup_speciesModel_introPhotos,
      backLabel: l10n.common_action_back,
      onBack: widget.onBack,
      primaryLabel: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              iconForSpeciesCategory(SpeciesCategory.fish),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: body,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
