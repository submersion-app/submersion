import 'package:flutter/material.dart';

import 'package:submersion/core/database/database_provenance.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Startup screen shown when the database on disk was written by a newer
/// version of the app than the one running (schema `user_version` exceeds
/// [appVersion]). The database has not been opened or modified at this point;
/// the only safe paths forward are updating the app or restoring an older
/// backup after updating.
class VersionMismatchView extends StatelessWidget {
  const VersionMismatchView({
    super.key,
    required this.databaseVersion,
    required this.appVersion,
    required this.textColor,
    required this.subtitleColor,
    required this.onDownloadLatest,
    required this.onClose,
    this.provenance,
    this.channelOverride,
  });

  /// Canonical download location, shown on screen and opened by the button.
  ///
  /// Deliberately owned here rather than passed in: the view renders this exact
  /// string as the manual fallback, and the caller launches the same constant,
  /// so the displayed address and the opened address cannot drift apart.
  static const String latestReleaseUrl =
      'https://github.com/submersion-app/submersion/releases/latest';

  final int databaseVersion;
  final int appVersion;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onDownloadLatest;
  final VoidCallback onClose;

  /// What the database says about the build that wrote it, when it says
  /// anything (issue #1593). Null for every database written before schema
  /// v194, which is the whole fleet stranded by #1568, so the screen has to
  /// read correctly without it.
  final DatabaseProvenanceRecord? provenance;

  /// Test seam: UpdateChannelConfig.current reads a compile-time constant,
  /// which a test binary cannot vary.
  final UpdateChannel? channelOverride;

  @override
  Widget build(BuildContext context) {
    // A store build cannot act on a GitHub download link, and its update
    // arrives on the store's schedule (possibly still in review), so it gets
    // a different instruction and no download affordances (issue #1089).
    final channel = channelOverride ?? UpdateChannelConfig.current;
    final isStore = UpdateChannelConfig.isStoreChannel(channel);

    final writtenBy = _writtenByLine(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update, size: 64, color: Colors.orange),
          const SizedBox(height: 24),
          Text(
            context.l10n.startup_versionMismatch_title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.startup_versionMismatch_body(
              databaseVersion,
              appVersion,
            ),
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          if (writtenBy != null) ...[
            const SizedBox(height: 12),
            Text(
              writtenBy,
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            isStore
                ? context.l10n.startup_versionMismatch_storeInstructions
                : context.l10n.startup_versionMismatch_instructions,
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          if (!isStore) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onDownloadLatest,
              child: Text(context.l10n.startup_versionMismatch_download),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.startup_versionMismatch_manualLink,
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            SelectableText(
              latestReleaseUrl,
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClose,
            child: Text(context.l10n.common_action_close),
          ),
        ],
      ),
    );
  }

  /// "Your data was last upgraded by Submersion 1.7.7.8064 (beta) on 5 Sep
  /// 2026", or null when the file cannot name a build.
  ///
  /// Prefers the UPGRADE entry over the last-open entry: the build that put
  /// the file on a rung this app cannot read is the one worth naming, and it
  /// is not necessarily the one that touched the file most recently.
  ///
  /// Prefers it only when it can actually NAME a build, though. The recorder
  /// never inherits a fact it could not determine, so an upgrade run by an
  /// open that could not resolve its version (a headless isolate has no
  /// plugin registrant) records rungs and a timestamp but no version at all.
  /// Insisting on that entry there would suppress the whole line while the
  /// file is still naming a build in its last-open entry, which is worse than
  /// naming the slightly less precise one.
  ///
  /// The train is rendered verbatim in parentheses rather than translated.
  /// It is an identifier written into the database by a build that may be
  /// newer than this one, so a train name that did not exist when these
  /// strings were translated must still render.
  String? _writtenByLine(BuildContext context) {
    final record = provenance;
    if (record == null) return null;

    DatabaseProvenanceEntry? entry;
    for (final candidate in [record.lastUpgrade, record.lastOpen]) {
      if (candidate?.appVersion != null) {
        entry = candidate;
        break;
      }
    }
    final version = entry?.appVersion;
    if (entry == null || version == null) return null;

    final train = entry.releaseTrain;
    final label = train == null ? version : '$version ($train)';

    final writtenAt = entry.writtenAt;
    if (writtenAt == null) {
      return context.l10n.startup_versionMismatch_writtenByUndated(label);
    }
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(writtenAt.toLocal());
    return context.l10n.startup_versionMismatch_writtenBy(label, date);
  }
}
