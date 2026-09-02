import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';
import 'package:submersion/features/media/presentation/helpers/set_time_seed.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/byte_format.dart';
import 'package:submersion/shared/utils/file_reveal.dart';

/// Everything the app knows about where one media item came from, whether it
/// is backed up, and where its bytes are being served from right now.
///
/// Each block also offers the fixes relevant to what it reports, so a problem
/// surfaced here can be acted on here. Those actions are entry points into
/// machinery that already exists; the only capability added for the panel is
/// checking a single item's source.
class MediaInfoPanel extends ConsumerWidget {
  const MediaInfoPanel({super.key, required this.item, this.scrollController});

  final MediaItem item;

  /// Supplied when hosted in a DraggableScrollableSheet, which owns scrolling.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Re-read the row rather than rendering the snapshot handed to the sheet.
    // mediaProvenanceProvider is keyed by the MediaItem VALUE and derives
    // everything from it, so invalidating that alone would recompute from the
    // same stale object: Check now would write isOrphaned to the database and
    // the Status row would never move. The passed item is the seed and the
    // fallback for the frame before the read lands.
    final live = ref.watch(mediaByIdProvider(item.id)).value ?? item;
    final provenance = ref.watch(mediaProvenanceProvider(live));
    final units = UnitFormatter(ref.watch(settingsProvider));

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.media_info_title, style: _titleStyle(context)),
        const SizedBox(height: 16),
        _FileSection(item: live, units: units),
        const SizedBox(height: 12),
        _OriginSection(item: live, origin: provenance.origin, units: units),
        const SizedBox(height: 12),
        _BackupSection(item: live, backup: provenance.backup, units: units),
        const SizedBox(height: 12),
        _ServingSection(item: live),
      ],
    );
  }

  static TextStyle? _titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;
}

/// A titled card of label/value rows, matching the dive detail convention.
///
/// [actions] render as a trailing wrap so a block that surfaces a problem
/// also offers the fix, rather than sending the reader somewhere else.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...children,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: actions),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FileSection extends ConsumerWidget {
  const _FileSection({required this.item, required this.units});

  final MediaItem item;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unknown = l10n.media_info_unknown;
    // The dive's profile decides whether the stored position is inside the
    // dive window and gives the Set-time dialog its range (issue #1090).
    final diveId = item.diveId;
    final profile = diveId == null
        ? const <DiveProfilePoint>[]
        : ref.watch(diveProvider(diveId)).value?.profile ??
              const <DiveProfilePoint>[];
    final profileLength = MediaDiveWindow.profileLengthSeconds(profile);
    final enrichment = item.enrichment;
    final positioned = enrichment?.isWithinDiveWindow(profileLength) ?? false;
    final String timeInDive;
    if (!positioned) {
      timeInDive = unknown;
    } else {
      final formatted = formatElapsedMmSs(enrichment!.elapsedSeconds!);
      timeInDive = enrichment.isManual
          ? l10n.media_timeInDive_manual(formatted)
          : formatted;
    }
    final width = item.width;
    final height = item.height;
    final size = item.contentSizeBytes;
    final lat = item.latitude;
    final lon = item.longitude;

    return _Section(
      title: l10n.media_info_fileSection,
      actions: [
        // Pinning needs a profile to pin against.
        if (diveId != null && profile.isNotEmpty)
          _SetTimeButton(
            item: item,
            profile: profile,
            initialElapsedSeconds: setTimeSeedFor(
              item,
              profileLengthSeconds: profileLength,
            ),
          ),
      ],
      children: [
        DiveDetailRow(
          label: l10n.media_info_filename,
          value: item.originalFilename ?? unknown,
        ),
        DiveDetailRow(
          label: l10n.media_info_type,
          value: mediaTypeLabel(l10n, item.mediaType),
        ),
        DiveDetailRow(
          label: l10n.media_info_dimensions,
          // Pixels are unit-system invariant, so this is one of the few
          // displayed quantities the diver's unit settings do not touch.
          value: (width != null && height != null)
              ? '$width x $height'
              : unknown,
        ),
        DiveDetailRow(
          label: l10n.media_info_size,
          value: size == null ? unknown : formatBytes(size),
        ),
        DiveDetailRow(
          label: l10n.media_info_taken,
          // takenAt is non-nullable on the row, so there is no unknown case.
          value: units.formatDateTime(item.takenAt, l10n: l10n),
        ),
        if (diveId != null)
          DiveDetailRow(label: l10n.media_timeInDive_label, value: timeInDive),
        if (lat != null && lon != null)
          DiveDetailRow(
            label: l10n.media_info_coordinates,
            value: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
          ),
      ],
    );
  }
}

/// Opens the Set-time dialog and applies the diver's choice (issue #1090).
class _SetTimeButton extends ConsumerWidget {
  const _SetTimeButton({
    required this.item,
    required this.profile,
    required this.initialElapsedSeconds,
  });

  final MediaItem item;
  final List<DiveProfilePoint> profile;
  final int initialElapsedSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.push_pin_outlined),
      label: Text(context.l10n.media_timeInDive_setAction),
      onPressed: () async {
        final choice = await showSetMediaTimeDialog(
          context,
          profile: profile,
          initialElapsedSeconds: initialElapsedSeconds,
          isPinned: item.manualElapsedSeconds != null,
          settings: ref.read(settingsProvider),
        );
        if (choice == null || !context.mounted) return;
        await ref.read(mediaTimePinnerProvider).apply(item, choice);
      },
    );
  }
}

class _OriginSection extends ConsumerWidget {
  const _OriginSection({
    required this.item,
    required this.origin,
    required this.units,
  });

  final MediaItem item;
  final OriginFacts origin;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final deviceId = origin.originDeviceId;
    final thisDevice = ref.watch(currentDeviceIdProvider).value;
    final pointer = origin.pointer;
    final isLocalFile = origin.sourceType == MediaSourceType.localFile;

    return _Section(
      title: l10n.media_info_originSection,
      actions: [
        _CheckNowButton(item: item),
        // The repair engine's file candidate only makes sense for a row that
        // points at a path, so this is not offered for a missing gallery
        // asset, where picking a file would relink it to the wrong source
        // type.
        if (origin.health == OriginHealth.missing && isLocalFile)
          _LocateButton(item: item),
        if (pointer != null && isLocalFile && canRevealInFileManager)
          TextButton(
            // Explicitly unawaited: revealInFileManager swallows its own
            // failures, so there is nothing to surface and nothing to wait
            // for before the sheet stays put.
            onPressed: () => unawaited(revealInFileManager(pointer)),
            child: Text(l10n.media_info_actionReveal),
          ),
        if (pointer != null) _CopyReferenceButton(pointer: pointer),
      ],
      children: [
        DiveDetailRow(
          label: l10n.media_info_source,
          value: sourceTypeLabel(l10n, origin.sourceType),
        ),
        if (origin.pointer != null)
          DiveDetailRow(
            label: l10n.media_info_reference,
            value: origin.pointer!,
          ),
        // Omitted entirely when null. Null means this source type does not
        // track an origin device, NOT that the link was made here, so
        // rendering "This device" would state a fact the app never recorded
        // and would do it on every gallery photo.
        if (deviceId != null)
          DiveDetailRow(
            label: l10n.media_info_linkedOn,
            // Until this device's own id resolves, "another device" would be
            // a guess, so an unresolved id reads as this device: the row was
            // stamped locally in the overwhelmingly common case.
            value: (thisDevice == null || deviceId == thisDevice)
                ? l10n.media_info_thisDevice
                : l10n.media_info_otherDevice,
          ),
        DiveDetailRow(
          label: l10n.media_info_status,
          value: switch (origin.health) {
            OriginHealth.healthy => l10n.media_info_statusFound,
            OriginHealth.missing => l10n.media_info_statusMissing,
            OriginHealth.neverVerified => l10n.media_info_statusUnchecked,
          },
        ),
        if (origin.lastVerifiedAt != null)
          DiveDetailRow(
            label: '',
            value: l10n.media_info_lastChecked(
              units.formatDateTime(origin.lastVerifiedAt, l10n: l10n),
            ),
          ),
      ],
    );
  }
}

class _BackupSection extends ConsumerWidget {
  const _BackupSection({
    required this.item,
    required this.backup,
    required this.units,
  });

  final MediaItem item;
  final BackupFacts backup;
  final UnitFormatter units;

  /// Whether to offer an upload at all.
  ///
  /// Hidden while pending or transferring: the answer to "is it uploading"
  /// is already on screen, and a second nudge would only re-enqueue what is
  /// already queued.
  bool get _offerUpload =>
      backup.eligible &&
      backup.storeAttached &&
      backup.tier != BackupTier.full &&
      backup.queueState != 'pending' &&
      backup.queueState != 'transferring';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final identity = ref.watch(mediaStoreIdentityProvider).value;

    return _Section(
      title: l10n.media_info_backupSection,
      actions: [
        if (_offerUpload)
          _BackUpButton(item: item, isRetry: backup.queueState == 'failed'),
      ],
      children: [
        DiveDetailRow(
          label: l10n.media_info_store,
          value: identity?.displayHint ?? l10n.media_info_storeNotConnected,
        ),
        if (_summary(l10n) case final summary?)
          DiveDetailRow(label: '', value: summary),
        if (backup.originalUploadedAt != null)
          DiveDetailRow(
            label: '',
            value: l10n.media_info_uploadedOn(
              units.formatDateTime(backup.originalUploadedAt, l10n: l10n),
            ),
          ),
        if (_queueLine(l10n) != null)
          DiveDetailRow(label: '', value: _queueLine(l10n)!),
      ],
    );
  }

  /// Precedence matters: an ineligible source is not "not backed up", it is
  /// something the pipeline would never carry, and saying otherwise reads as
  /// a problem the user could fix.
  /// Null when the row above has already said everything there is to say.
  ///
  /// With no store attached the store row falls back to the same
  /// not-connected string this used to return, so the panel printed the
  /// identical sentence twice.
  String? _summary(AppLocalizations l10n) {
    if (!backup.eligible) return l10n.media_info_notEligible;
    if (!backup.storeAttached) return null;
    return switch (backup.tier) {
      BackupTier.full => l10n.media_info_backupFull,
      BackupTier.thumbOnly => l10n.media_info_backupThumbOnly,
      BackupTier.renditionOnly => l10n.media_info_backupRenditionOnly,
      BackupTier.none => l10n.media_info_backupNone,
    };
  }

  /// A settled row says nothing new, so 'done' and an absent row both read as
  /// no queue line at all.
  String? _queueLine(AppLocalizations l10n) => switch (backup.queueState) {
    'pending' => l10n.media_info_queuePending,
    'transferring' => l10n.media_info_queueTransferring,
    'failed' => l10n.media_info_queueFailed(
      backup.queueError ?? l10n.media_info_unknown,
    ),
    _ => null,
  };
}

class _ServingSection extends ConsumerWidget {
  const _ServingSection({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recorder = ref.watch(mediaServingRecorderProvider);

    // Read through a ListenableBuilder rather than a provider. Riverpod 3
    // auto-pause trips an assertion on providers that self-invalidate from a
    // listener the framework cannot see, and the repo's fix for that
    // (Ref.invalidateSelfWhen) takes a Stream, which a ChangeNotifier is not.
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final facts = ServingFacts.from(
          recorder.lastFor(item.id, thumbnail: false),
        );
        return _Section(
          title: l10n.media_info_servingSection,
          children: [
            DiveDetailRow(label: '', value: _summary(l10n, facts)),
            if (facts.observed &&
                facts.storeFallbackUsed &&
                facts.servedFrom != null)
              DiveDetailRow(
                label: '',
                value: l10n.media_info_servingFallbackNote,
              ),
          ],
        );
      },
    );
  }

  String _summary(AppLocalizations l10n, ServingFacts facts) {
    if (!facts.observed) return l10n.media_info_servingUnobserved;
    final from = facts.servedFrom;
    if (from == null) return l10n.media_info_servingFailed;
    // Exhaustive with no default arm, so a new ServedFrom value becomes a
    // compile error rather than a silently wrong label.
    final source = switch (from) {
      ServedFrom.localDisk => l10n.media_info_servedLocalDisk,
      ServedFrom.platformGallery => l10n.media_info_servedGallery,
      ServedFrom.storeCache => l10n.media_info_servedStoreCache,
      ServedFrom.storeNetwork => l10n.media_info_servedStoreNetwork,
      ServedFrom.networkUrl => l10n.media_info_servedNetworkUrl,
      ServedFrom.connectorCache => l10n.media_info_servedConnectorCache,
      ServedFrom.connectorNetwork => l10n.media_info_servedConnectorNetwork,
      ServedFrom.embedded => l10n.media_info_servedEmbedded,
    };
    final tier = switch (facts.servedTier) {
      ServedTier.original => null,
      ServedTier.thumbnail => l10n.media_info_servingTierThumbnail,
      ServedTier.rendition => l10n.media_info_servingTierRendition,
    };
    return tier == null ? source : '$source ($tier)';
  }
}

/// Checks the item's source and reports what it found.
///
/// The verifier writes `isOrphaned` and `lastVerifiedAt`, and the panel reads
/// its origin facts off the row, so the result reaches the display through
/// the repository rather than through local state.
class _CheckNowButton extends ConsumerStatefulWidget {
  const _CheckNowButton({required this.item});

  final MediaItem item;

  @override
  ConsumerState<_CheckNowButton> createState() => _CheckNowButtonState();
}

class _CheckNowButtonState extends ConsumerState<_CheckNowButton> {
  bool _busy = false;

  Future<void> _run() async {
    // Captured before the await: the messenger and the strings cannot be
    // read from a context that may have been unmounted by the time the
    // check returns.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(mediaItemVerifierProvider)
          .verify(widget.item);
      // The sheet can be dismissed while the check runs. ref after dispose
      // throws, and there is no one left to show a snack bar to.
      if (!mounted) return;
      final message = switch (result) {
        VerifyResult.available => l10n.media_info_checkFound,
        VerifyResult.notFound => l10n.media_info_checkMissing,
        // Everything below is a reachability problem, not data loss, and the
        // wording has to match what the verifier actually did: none of these
        // move the orphan flag, so "Source is missing" would tell the user
        // their photo is gone over a revoked permission, a disconnected
        // Lightroom account, or a file that lives on their other machine.
        VerifyResult.unauthenticated ||
        VerifyResult.fromOtherDevice ||
        VerifyResult.transientError ||
        VerifyResult.volumeOffline ||
        VerifyResult.accessDenied => l10n.media_info_checkUnavailable,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
      // Invalidate the ROW, not the provenance provider: provenance is keyed
      // by the item value, so re-reading the row is what actually re-keys it.
      ref.invalidate(mediaByIdProvider(widget.item.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: _busy ? null : _run,
    child: Text(context.l10n.media_info_actionCheckNow),
  );
}

/// Picks a replacement file and re-links through the repair engine.
class _LocateButton extends ConsumerWidget {
  const _LocateButton({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async {
      final applied = await replaceMediaLink(context, ref, item);
      // The picker and confirm dialog can outlive the sheet, and ref after
      // dispose throws, which would turn a plain user-cancel into an error.
      if (!context.mounted) return;
      // The repair writes the row, so re-read it: that is what re-keys the
      // provenance provider and lets the status line stop saying "missing".
      if (applied) ref.invalidate(mediaByIdProvider(item.id));
    },
    child: Text(context.l10n.media_info_actionLocate),
  );
}

/// Queues the item for upload, or re-arms a terminally failed row.
class _BackUpButton extends ConsumerWidget {
  const _BackUpButton({required this.item, required this.isRetry});

  final MediaItem item;

  /// Only the label differs. `enqueueRepairUpload` is idempotent and already
  /// re-arms a failed row via retry, so both cases are the same call.
  final bool isRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context);
      final queued = context.l10n.media_info_backupQueued;
      // Both providers are read before any await, so nothing touches ref
      // across an async gap that could outlive the sheet.
      final queue = ref.read(mediaTransferQueueRepositoryProvider);
      final runtimeFuture = ref.read(mediaStoreRuntimeProvider.future);

      try {
        await queue.enqueueRepairUpload(mediaId: item.id);
      } on Object {
        // Nothing was queued, so there is nothing to report.
        return;
      }

      // Kick the worker so a queued row starts moving rather than waiting
      // for the next incidental drain. Its failure is reported separately
      // from the enqueue on purpose: building the runtime reads the keychain
      // and can fail for reasons unrelated to this item, and the row IS
      // queued at that point. Folding the two together would swallow the
      // confirmation for work that really did get scheduled.
      try {
        final runtime = await runtimeFuture;
        unawaited(runtime?.worker?.drain() ?? Future<void>.value());
      } on Object {
        // The row is durable and the next drain will find it.
      }

      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(queued)));
    },
    child: Text(
      isRetry
          ? context.l10n.media_info_actionRetryUpload
          : context.l10n.media_info_actionBackUpNow,
    ),
  );
}

/// Copies the source pointer, which is often a path a reader wants to paste
/// into a terminal or a file dialog.
class _CopyReferenceButton extends StatelessWidget {
  const _CopyReferenceButton({required this.pointer});

  final String pointer;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context);
      final copied = context.l10n.media_info_referenceCopied;
      await Clipboard.setData(ClipboardData(text: pointer));
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(copied)));
    },
    child: Text(context.l10n.media_info_actionCopyPath),
  );
}

/// Localized name for a media type.
///
/// MediaType.name would render the raw enum identifier, so a signature would
/// read as "instructorSignature" in every language. MediaType.displayName is
/// hardcoded English, which is no better in a panel that is localized
/// everywhere else.
String mediaTypeLabel(AppLocalizations l10n, MediaType type) => switch (type) {
  MediaType.photo => l10n.media_info_typePhoto,
  MediaType.video => l10n.media_info_typeVideo,
  MediaType.document => l10n.media_info_typeDocument,
  MediaType.instructorSignature => l10n.media_info_typeSignature,
};

/// Localized name for a source type.
///
/// Reuses the existing media_source_* keys rather than adding a parallel set,
/// so the panel and the Media console's Sources view can never disagree about
/// what a source type is called.
String sourceTypeLabel(AppLocalizations l10n, MediaSourceType type) =>
    switch (type) {
      MediaSourceType.platformGallery => l10n.media_source_gallery,
      MediaSourceType.localFile => l10n.media_source_localFile,
      MediaSourceType.networkUrl => l10n.media_source_networkUrl,
      MediaSourceType.manifestEntry => l10n.media_source_manifest,
      MediaSourceType.serviceConnector => l10n.media_source_connector,
      MediaSourceType.mediaStore => l10n.media_source_mediaStore,
      MediaSourceType.signature => l10n.media_source_signature,
    };
