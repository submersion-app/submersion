import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';
import 'package:submersion/features/species_id/domain/services/labels_menu_model.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the viewer's toolbar needs for the marine life labels action
/// (issue #4825): what a tap does (null when [item] is not looked at on
/// this device), whether labels are drawn, the ring while it is being
/// analysed, and how far analysis has got, as the icon's colour (issue
/// #4926) and, through [labelsButtonLabel], its tooltip (issue #4958).
/// Read while the toolbar builds, so it follows them.
///
/// [showing] says whether [item] is still the one on screen in the viewer
/// still open; a notice on what an Analyse found waits for it.
({
  void Function(BuildContext anchor)? onPressed,
  bool on,
  ToolbarRing? ring,
  ToolbarTone? tone,
  LabelsButtonStatus? status,
})
marineLifeLabelsAction(
  WidgetRef ref,
  MediaItem item,
  GeoPoint? location, {
  bool Function()? showing,
}) {
  // A Lightroom-linked video is only its poster here, never scanned.
  // Shown wherever results can be (issue #4876), analysed here or not.
  final applies =
      marineLifeLabelsShown &&
      (item.mediaType == MediaType.photo ||
          (item.mediaType == MediaType.video &&
              item.sourceType != MediaSourceType.serviceConnector &&
              videoLabelsShown(defaultTargetPlatform)));
  final on = ref.watch(labelModeNotifierProvider) != LabelMode.off;
  if (!applies) {
    return (onPressed: null, on: on, ring: null, tone: null, status: null);
  }
  // Kept read while the toolbar shows, so the menu opens on what is known,
  // and the icon's colour follows it. Only the state is watched: the status
  // reloads on every write to the logbook's identifications, and a reload
  // that leaves the state as it was rebuilds nothing.
  final state = ref.watch(
    mediaAnalysisStatusProvider(
      AnalysisTarget(item, location),
    ).select((status) => status.value?.state),
  );
  final busy = ref.watch(mediaIdentificationBusyProvider(item.id)).value;
  final progress = ref
      .watch(mediaIdentificationProgressProvider(item.id))
      .value;
  final status = labelsButtonStatus(state: state, busy: busy ?? false);
  return (
    onPressed: (anchor) => unawaited(
      showMarineLifeLabelsMenu(
        anchor,
        ref,
        item: item,
        location: location,
        showing: showing,
      ),
    ),
    on: on,
    // A video fills its ring as it is scanned; a photo's spins.
    ring: busy ?? false ? ToolbarRing(progress) : null,
    tone: switch (status) {
      LabelsButtonStatus.notAnalysed => null,
      LabelsButtonStatus.analysing => ToolbarTone.active,
      // Both still have work for Analyse to do.
      LabelsButtonStatus.partial ||
      LabelsButtonStatus.outdated => ToolbarTone.warn,
      LabelsButtonStatus.analysed => ToolbarTone.ok,
    },
    status: status,
  );
}

/// The labels button's tooltip for [status] (issue #4958): its name and
/// how far analysis has got, which its colour shows without saying.
String labelsButtonLabel(AppLocalizations l10n, LabelsButtonStatus status) =>
    switch (status) {
      LabelsButtonStatus.notAnalysed => l10n.media_labels_buttonNotAnalysed,
      LabelsButtonStatus.analysing => l10n.media_labels_buttonAnalysing,
      LabelsButtonStatus.partial => l10n.media_labels_buttonPartlyAnalysed,
      LabelsButtonStatus.outdated => l10n.media_labels_buttonOutdated,
      LabelsButtonStatus.analysed => l10n.media_labels_buttonAnalysed,
    };

enum _Pick { names, allLife, off, analyse }

/// The labels menu for [item], anchored to [anchor] (issue #4825): what
/// the app has found on it, the labels mode, and Analyse or Analyse again.
/// Once an Analyse finishes, a brief notice says what it found when that
/// would draw no name (issue #4872), while [showing] (by default, while
/// [anchor] is mounted) says [item] is still on screen.
Future<void> showMarineLifeLabelsMenu(
  BuildContext anchor,
  WidgetRef ref, {
  required MediaItem item,
  required GeoPoint? location,
  bool Function()? showing,
}) async {
  final l10n = anchor.l10n;
  // Where the menu opens, measured before anything is awaited.
  final button = anchor.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchor).overlay!.context.findRenderObject()! as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
  // Read ahead while the toolbar shows; waited for when it has not
  // answered yet, so the menu never offers the wrong action.
  final statusOf = mediaAnalysisStatusProvider(AnalysisTarget(item, location));
  var status = ref.read(statusOf).value;
  if (status == null) {
    try {
      status = await ref
          .read(statusOf.future)
          .timeout(const Duration(seconds: 2));
    } on Object {
      // Unread or failed: the menu still opens, offering Analyse.
      status = null;
    }
  }
  if (!anchor.mounted) return;
  final MediaAnalysisStatus known =
      status ?? (state: MediaAnalysisState.notAnalysed, found: 0);
  final model = labelsMenuModel(
    state: known.state,
    found: known.found,
    busy: ref.read(mediaIdentificationBusyProvider(item.id)).value ?? false,
    progress: ref.read(mediaIdentificationProgressProvider(item.id)).value,
  );
  final mode = ref.read(labelModeNotifierProvider);
  // Held now: the toolbar (and the ref with it) can go while the menu is
  // open, when the controls hide or the page moves on, and the pick must
  // still count.
  final modes = ref.read(labelModeNotifierProvider.notifier);
  final service = ref.read(mediaIdentificationServiceProvider);
  final canAnalyse =
      marineLifeIdEnabled &&
      (item.mediaType == MediaType.photo ||
          visionVideoRuns(defaultTargetPlatform));
  final tell = _AnalysedTeller(
    messenger: ScaffoldMessenger.maybeOf(anchor),
    l10n: l10n,
    repository: ref.read(mediaIdentificationRepositoryProvider),
    level: ref.read(levelInForceProvider),
    mode: mode,
    modes: modes,
    showing: showing ?? () => anchor.mounted,
  );
  CheckedPopupMenuItem<_Pick> modeItem(
    String key,
    _Pick pick,
    LabelMode itsMode,
    String text,
  ) => CheckedPopupMenuItem<_Pick>(
    key: ValueKey('labels_menu_$key'),
    value: pick,
    checked: mode == itsMode,
    child: Text(text),
  );
  final picked = await showMenu<_Pick>(
    context: anchor,
    position: position,
    items: [
      PopupMenuItem<_Pick>(
        key: const ValueKey('labels_menu_status'),
        enabled: false,
        child: Text(_statusText(anchor, l10n, model)),
      ),
      modeItem('names', _Pick.names, LabelMode.names, l10n.media_labels_names),
      modeItem(
        'all_life',
        _Pick.allLife,
        LabelMode.allLife,
        l10n.media_labels_allLife,
      ),
      modeItem('off', _Pick.off, LabelMode.off, l10n.media_labels_off),
      // Only where the models run (issue #4876): elsewhere the labels are
      // another device's results, and nothing here can look again.
      if (canAnalyse) ...[
        const PopupMenuDivider(),
        PopupMenuItem<_Pick>(
          key: const ValueKey('labels_menu_analyse'),
          value: _Pick.analyse,
          enabled: model.actionEnabled,
          child: Row(
            children: [
              const Icon(Icons.refresh),
              const SizedBox(width: 12),
              Text(
                model.action == AnalyseAction.analyseAgain
                    ? l10n.media_labels_analyseAgain
                    : l10n.media_labels_analyse,
              ),
            ],
          ),
        ),
      ],
    ],
  );
  if (picked == null) return;
  switch (picked) {
    case _Pick.names:
      await modes.setMode(LabelMode.names);
    case _Pick.allLife:
      await modes.setMode(LabelMode.allLife);
    case _Pick.off:
      await modes.setMode(LabelMode.off);
    case _Pick.analyse:
      // Read as the request starts: an analysis stores long after.
      final before = tell.runOf(item);
      unawaited(
        service
            .request(
              item,
              location: location,
              byHand: true,
              fresh: model.action == AnalyseAction.analyseAgain,
            )
            .then((_) async => tell(item, before: await before)),
      );
  }
}

/// Says what an Analyse the diver asked for found, once it has finished,
/// when that would draw no name (issue #4872). Holds what it needs from
/// the menu's moment, as the toolbar may be gone by then.
class _AnalysedTeller {
  const _AnalysedTeller({
    required this.messenger,
    required this.l10n,
    required this.repository,
    required this.level,
    required this.mode,
    required this.modes,
    required this.showing,
  });

  final ScaffoldMessengerState? messenger;
  final AppLocalizations l10n;
  final MediaIdentificationRepository repository;
  final LevelInForce? level;
  final LabelMode mode;
  final LabelModeNotifier modes;
  final bool Function() showing;

  /// What is stored for [item] now, or null (none, or not read).
  Future<MediaIdentificationRun?> runOf(MediaItem item) async {
    try {
      return await repository.runFor(item.id);
    } on Object {
      return null;
    }
  }

  /// Never throws: a notice that cannot be worked out is left unsaid.
  /// Said only when the Analyse changed what is stored since [before]:
  /// one that failed or was skipped leaves an earlier analysis, which is
  /// not this tap's to report.
  Future<void> call(
    MediaItem item, {
    required MediaIdentificationRun? before,
  }) async {
    final messenger = this.messenger;
    if (messenger == null || !showing()) return;
    try {
      final run = await repository.runFor(item.id);
      // Never analysed (dropped, or unreadable), or a video left part way:
      // nothing to say of it.
      if (run == null ||
          run == before ||
          (item.mediaType == MediaType.video && !run.scanComplete)) {
        return;
      }
      final found = await identificationsAtLevel(repository, item.id, level);
      final notice = analysedNotice(found);
      if (notice == null || !showing()) return;
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('labels_analysed_notice'),
          // Brief, action or not: it must never sit over the next page.
          persist: false,
          content: Text(switch (notice) {
            AnalysedNotice.nothingFound => l10n.media_labels_statusFound(0),
            AnalysedNotice.noneNamed => l10n.media_labels_foundNoneNamed(
              foundCount(found),
            ),
          }),
          // All life draws the unnamed ones already.
          action:
              notice == AnalysedNotice.noneNamed && mode != LabelMode.allLife
              ? SnackBarAction(
                  label: l10n.media_labels_showAllLife,
                  onPressed: () => unawaited(modes.setMode(LabelMode.allLife)),
                )
              : null,
        ),
      );
    } on Object {
      // Left unsaid.
    }
  }
}

String _statusText(
  BuildContext context,
  AppLocalizations l10n,
  LabelsMenuModel model,
) => switch (model.line) {
  LabelsStatusLine.noModel => l10n.media_labels_statusNoModel,
  LabelsStatusLine.notAnalysed => l10n.media_labels_statusNotAnalysed,
  LabelsStatusLine.analysing => l10n.media_labels_statusAnalysing,
  LabelsStatusLine.analysingPercent => l10n.media_labels_statusAnalysingPercent(
    NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    ).format(model.progress ?? 0),
  ),
  LabelsStatusLine.found => l10n.media_labels_statusFound(model.found),
  LabelsStatusLine.partlyFound => l10n.media_labels_statusPartlyFound(
    model.found,
  ),
};
