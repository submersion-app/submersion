import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks a replacement file for [item] and routes the re-link through the
/// repair engine.
///
/// Extracted verbatim from `_DiveMediaSectionState._replaceLink` so the info
/// panel can offer the same flow. Behaviour is deliberately unchanged: the
/// picked file is hash-verified against the row's content identity, bookmark
/// regeneration stays engine-owned, and picking DIFFERENT bytes requires an
/// explicit confirm because accepting re-uploads them to the media store.
///
/// Returns whether a repair was applied. Refreshing any list is the caller's
/// concern: the dive section's refresh is dive-scoped and does not belong to
/// every caller.
///
/// Photo-only, matching the flow it came from: videos are not supported as
/// local-file media yet.
Future<bool> replaceMediaLink(
  BuildContext context,
  WidgetRef ref,
  MediaItem item, {

  /// Injectable so a test can drive the flow without a native dialog.
  Future<String?> Function()? pickPath,

  /// Injectable so a test can exercise the confirm branch without real disk
  /// I/O. flutter_test's fake async never completes a file read, and driving
  /// it through `runAsync` puts the resulting future in a different zone from
  /// the pumps that dismiss the dialog, which deadlocks.
  Future<({String hash, int sizeBytes})> Function(File)? hashFile,
}) async {
  // Read before the first await. The picker and the confirm dialog can both
  // outlive this widget, and touching ref afterwards throws once it is
  // disposed. Capturing here also means a repair the user already confirmed
  // still lands if they dismiss the sheet while it applies.
  final repairService = ref.read(mediaRepairServiceProvider);
  final picked = pickPath ?? _pickImagePath;
  final newPath = await picked();
  if (newPath == null) return false;

  final digest = await (hashFile ?? sha256OfFile)(File(newPath));
  final rowHash = item.contentHash;
  final sameBytes = rowHash == null || digest.hash == rowHash;

  if (!sameBytes) {
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.media_diveMediaSection_replaceEditedTitle),
        content: Text(ctx.l10n.media_diveMediaSection_replaceEditedContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.media_diveMediaSection_cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.media_diveMediaSection_replaceButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }

  await repairService.apply([
    RepairProposal(
      item: item,
      confidence: sameBytes ? RepairConfidence.exact : RepairConfidence.edited,
      candidate: RepairCandidate.file(
        path: newPath,
        sizeBytes: digest.sizeBytes,
        hash: digest.hash,
      ),
    ),
  ]);
  return true;
}

Future<String?> _pickImagePath() async {
  final result = await FilePicker.pickFile(type: FileType.image);
  return result?.path;
}
