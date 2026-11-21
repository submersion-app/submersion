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
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/services/labels_menu_model.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the viewer's toolbar needs for the marine life labels action
/// (issue #4825): what a tap does (null when [item] is not looked at on
/// this device), whether labels are drawn, and the ring while it is being
/// analysed. Read while the toolbar builds, so it follows them.
({void Function(BuildContext anchor)? onPressed, bool on, ToolbarRing? ring})
marineLifeLabelsAction(WidgetRef ref, MediaItem item, GeoPoint? location) {
  // A Lightroom-linked video is only its poster here, never scanned.
  final applies =
      marineLifeIdEnabled &&
      (item.mediaType == MediaType.photo ||
          (item.mediaType == MediaType.video &&
              item.sourceType != MediaSourceType.serviceConnector &&
              visionVideoRuns(defaultTargetPlatform)));
  final on = ref.watch(labelModeProvider) != LabelMode.off;
  if (!applies) return (onPressed: null, on: on, ring: null);
  // Kept read while the toolbar shows, so the menu opens on what is known.
  ref.watch(mediaAnalysisStatusProvider(AnalysisTarget(item, location)));
  final busy = ref.watch(mediaIdentificationBusyProvider(item.id)).value;
  final progress = ref
      .watch(mediaIdentificationProgressProvider(item.id))
      .value;
  return (
    onPressed: (anchor) => unawaited(
      showMarineLifeLabelsMenu(anchor, ref, item: item, location: location),
    ),
    on: on,
    // A video fills its ring as it is scanned; a photo's spins.
    ring: busy ?? false ? ToolbarRing(progress) : null,
  );
}

enum _Pick { names, allLife, off, analyse }

/// The labels menu for [item], anchored to [anchor] (issue #4825): what
/// the app has found on it, the labels mode, and Analyse or Analyse again.
Future<void> showMarineLifeLabelsMenu(
  BuildContext anchor,
  WidgetRef ref, {
  required MediaItem item,
  required GeoPoint? location,
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
  final mode = ref.read(labelModeProvider);
  // Held now: the toolbar (and the ref with it) can go while the menu is
  // open, when the controls hide or the page moves on, and the pick must
  // still count.
  final modes = ref.read(labelModeProvider.notifier);
  final service = ref.read(mediaIdentificationServiceProvider);
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
      unawaited(
        service.request(
          item,
          location: location,
          byHand: true,
          fresh: model.action == AnalyseAction.analyseAgain,
        ),
      );
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
};
