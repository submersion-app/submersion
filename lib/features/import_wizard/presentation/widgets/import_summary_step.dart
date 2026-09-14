import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_file_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_summary_diver_outcomes.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/missing_dives_card.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The summary step shown after the import completes.
///
/// Shows a success view with per-entity import counts, consolidated and
/// skipped summaries, and "Done" / "View Dives" action buttons.
///
/// On error, shows an error icon and message with a "Done" button.
///
/// While the import is still running, shows a loading indicator.
class ImportSummaryStep extends ConsumerWidget {
  /// Called when the user taps the "Done" button.
  final VoidCallback onDone;

  /// Called when the user taps the "View Dives" button.
  final VoidCallback onViewDives;

  const ImportSummaryStep({
    super.key,
    required this.onDone,
    required this.onViewDives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardNotifierProvider);
    final result = state.importResult;

    if (result == null) {
      final error = state.error;
      if (error != null) {
        return _ErrorView(errorMessage: error, onDone: onDone);
      }
      return const Center(child: CircularProgressIndicator());
    }

    // A failure after some profiles already imported keeps the success view,
    // with the error above what landed (issue #1893).
    if (result.errorMessage != null && result.diverOutcomes.isEmpty) {
      return _ErrorView(errorMessage: result.errorMessage!, onDone: onDone);
    }

    return _SuccessView(
      importedCounts: result.importedCounts,
      consolidatedCount: result.consolidatedCount,
      updatedCount: result.updatedCount,
      skippedCount: result.skippedCount,
      attachedPhotoCount: result.attachedPhotoCount,
      unmatchedPhotoCount: result.unmatchedPhotoCount,
      importedDiveIds: result.importedDiveIds,
      fileOutcomes: result.fileOutcomes,
      notices: result.notices,
      diverOutcomes: result.diverOutcomes,
      partialError: result.errorMessage,
      onDone: onDone,
      onViewDives: onViewDives,
    );
  }
}

// ---------------------------------------------------------------------------
// Success view
// ---------------------------------------------------------------------------

class _SuccessView extends StatelessWidget {
  final Map<ImportEntityType, int> importedCounts;
  final int consolidatedCount;
  final int updatedCount;
  final int skippedCount;
  final int attachedPhotoCount;
  final int unmatchedPhotoCount;
  final List<String> importedDiveIds;
  final List<ImportFileOutcome> fileOutcomes;
  final List<ImportNotice> notices;
  final List<DiverImportOutcome> diverOutcomes;
  final String? partialError;
  final VoidCallback onDone;
  final VoidCallback onViewDives;

  const _SuccessView({
    required this.importedCounts,
    required this.consolidatedCount,
    this.updatedCount = 0,
    required this.skippedCount,
    this.attachedPhotoCount = 0,
    this.unmatchedPhotoCount = 0,
    this.importedDiveIds = const [],
    this.fileOutcomes = const [],
    this.notices = const [],
    this.diverOutcomes = const [],
    this.partialError,
    required this.onDone,
    required this.onViewDives,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalImported = importedCounts.values.fold<int>(
      0,
      (sum, v) => sum + v,
    );
    final hasActivity =
        totalImported > 0 || consolidatedCount > 0 || updatedCount > 0;
    final l10n = context.l10n;
    // "Import notes" explain dives that imported. Dives that did not (rows
    // whose date could not be read, dives a parser could not read) get their
    // own card.
    final fileNotices = [
      for (final notice in notices)
        if (_fileNoticeWording(l10n, notice) case final wording?)
          (notice: notice, wording: wording),
    ];

    final String title;
    final IconData icon;
    final Color iconColor;
    final Color iconBg;
    if (hasActivity) {
      if (totalImported > 0) {
        title = l10n.universalImport_title_successImported;
      } else if (updatedCount > 0) {
        title = l10n.universalImport_title_successUpdated;
      } else {
        title = l10n.universalImport_title_successConsolidated;
      }
      icon = Icons.check;
      iconColor = theme.colorScheme.onPrimaryContainer;
      iconBg = theme.colorScheme.primaryContainer;
    } else {
      title = l10n.universalImport_title_noDivesImported;
      icon = Icons.info_outline;
      iconColor = theme.colorScheme.onSurfaceVariant;
      iconBg = theme.colorScheme.surfaceContainerHighest;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              key: const Key('import_summary_success_title'),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (!hasActivity && skippedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.universalImport_label_allDivesSkipped,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            for (final entry in importedCounts.entries)
              if (entry.value > 0)
                _CountRow(
                  icon: _iconForType(entry.key),
                  label: _labelForType(l10n, entry.key),
                  count: entry.value,
                ),
            if (updatedCount > 0)
              _CountRow(
                icon: Icons.sync,
                label: l10n.universalImport_label_replacedSourceData,
                count: updatedCount,
                key: const Key('import_summary_updated_row'),
              ),
            if (consolidatedCount > 0)
              _CountRow(
                icon: Icons.merge,
                label: l10n.universalImport_label_consolidated,
                count: consolidatedCount,
                key: const Key('import_summary_consolidated_row'),
              ),
            if (attachedPhotoCount > 0)
              _CountRow(
                icon: Icons.photo_library_outlined,
                label: l10n.universalImport_label_photosAttached,
                count: attachedPhotoCount,
                key: const Key('import_summary_photos_row'),
              ),
            if (unmatchedPhotoCount > 0)
              _CountRow(
                icon: Icons.hide_image_outlined,
                label: l10n.universalImport_label_photosUnmatched,
                count: unmatchedPhotoCount,
                key: const Key('import_summary_unmatched_photos_row'),
              ),
            if (skippedCount > 0)
              _CountRow(
                icon: Icons.skip_next,
                label: l10n.universalImport_label_skipped,
                count: skippedCount,
                key: const Key('import_summary_skipped_row'),
              ),
            for (final notice in notices)
              if (notice.kind.reportsMissingDives) ...[
                const SizedBox(height: 8),
                MissingDivesCard(
                  key: Key(switch (notice.kind) {
                    ImportNoticeKind.divesSkipped =>
                      'import_summary_dives_skipped',
                    _ => 'import_summary_unreadable_dates',
                  }),
                  notice: notice,
                ),
              ],
            if (importedDiveIds.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final count =
                      ref
                          .watch(
                            importedDivesOpenFindingsCountProvider(
                              importedDivesFindingsKey(importedDiveIds),
                            ),
                          )
                          .value ??
                      0;
                  if (count == 0) return const SizedBox.shrink();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.rule),
                    title: Text(l10n.dataQuality_summary_flagged(count)),
                    trailing: TextButton(
                      onPressed: () => context.push(
                        '/dives/quality?dive=${importedDiveIds.join(',')}',
                      ),
                      child: Text(l10n.dataQuality_summary_review),
                    ),
                  );
                },
              ),
            if (partialError != null ||
                ImportSummaryDiverOutcomes.isWorthShowing(diverOutcomes)) ...[
              const SizedBox(height: 16),
              ImportSummaryDiverOutcomes(
                outcomes: diverOutcomes,
                errorMessage: partialError,
              ),
            ],
            if (fileNotices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                key: const Key('import_summary_notices'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.universalImport_summary_noticesTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final entry in fileNotices)
                    _NoticeCard(notice: entry.notice, wording: entry.wording),
                ],
              ),
            ],
            if (fileOutcomes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.universalImport_summary_filesTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final outcome in fileOutcomes)
                _FileOutcomeRow(outcome: outcome),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onDone,
                  child: Text(l10n.universalImport_action_done),
                ),
                if (hasActivity) ...[
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: onViewDives,
                    child: Text(l10n.universalImport_action_viewDives),
                  ),
                ],
              ],
            ),
            Consumer(
              builder: (context, ref, _) {
                if (importedDiveIds.isEmpty) return const SizedBox.shrink();
                final eligible = ref.watch(
                  eligibleImportedDivesProvider(
                    ImportedDiveIds(importedDiveIds),
                  ),
                );
                return eligible.maybeWhen(
                  data: (ids) => ids.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: Text(
                              context.l10n.importSummary_matchSitesButton(
                                ids.length,
                              ),
                            ),
                            onPressed: () =>
                                context.push('/dives/match-sites', extra: ids),
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(ImportEntityType type) {
    switch (type) {
      case ImportEntityType.dives:
        return Icons.scuba_diving;
      case ImportEntityType.sites:
        return Icons.location_on;
      case ImportEntityType.buddies:
        return Icons.people;
      case ImportEntityType.equipment:
        return Icons.build;
      case ImportEntityType.trips:
        return Icons.luggage;
      case ImportEntityType.certifications:
        return Icons.verified;
      case ImportEntityType.diveCenters:
        return Icons.store;
      case ImportEntityType.tags:
        return Icons.label;
      case ImportEntityType.diveTypes:
        return Icons.category;
      case ImportEntityType.equipmentSets:
        return Icons.inventory;
      case ImportEntityType.courses:
        return Icons.school;
      case ImportEntityType.media:
        return Icons.photo_library;
    }
  }

  String _labelForType(AppLocalizations l10n, ImportEntityType type) {
    switch (type) {
      case ImportEntityType.dives:
        return l10n.diveImport_uddf_dives;
      case ImportEntityType.sites:
        return l10n.diveImport_uddf_sites;
      case ImportEntityType.buddies:
        return l10n.diveImport_uddf_buddies;
      case ImportEntityType.equipment:
        return l10n.diveImport_uddf_equipment;
      case ImportEntityType.trips:
        return l10n.diveImport_uddf_trips;
      case ImportEntityType.certifications:
        return l10n.diveImport_uddf_certifications;
      case ImportEntityType.diveCenters:
        return l10n.diveImport_uddf_diveCenters;
      case ImportEntityType.tags:
        return l10n.diveImport_uddf_tags;
      case ImportEntityType.diveTypes:
        return l10n.diveImport_uddf_diveTypes;
      case ImportEntityType.equipmentSets:
        return l10n.diveImport_uddf_equipmentSets;
      case ImportEntityType.courses:
        return l10n.diveImport_uddf_tabCourses;
      case ImportEntityType.media:
        return l10n.diveImport_uddf_media;
    }
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onDone;

  const _ErrorView({required this.errorMessage, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              key: const Key('import_summary_error_message'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: onDone,
              child: Text(context.l10n.universalImport_action_done),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-file outcome row (bulk imports)
// ---------------------------------------------------------------------------

/// Title, body and optional follow-up action for an import notes card.
typedef _FileNoticeWording = ({
  String title,
  String body,
  ({String label, String route})? action,
});

/// The wording for an import notes card, or null for a kind shown elsewhere.
/// Dives that did not import at all are reported by [MissingDivesCard].
_FileNoticeWording? _fileNoticeWording(
  AppLocalizations l10n,
  ImportNotice notice,
) {
  final names = notice.names.join(', ');
  return switch (notice.kind) {
    ImportNoticeKind.divesSkipped || ImportNoticeKind.unreadableDates => null,
    ImportNoticeKind.profileUnreadable => (
      title: l10n.universalImport_summary_noticeProfileUnreadableTitle,
      body: l10n.universalImport_summary_noticeProfileUnreadableBody,
      action: null,
    ),
    ImportNoticeKind.macdiveProfileUndecodable => (
      title: l10n.universalImport_summary_noticeMacdiveProfileUndecodableTitle,
      body: l10n.universalImport_summary_noticeMacdiveProfileUndecodableBody,
      action: null,
    ),
    ImportNoticeKind.profileUndecodableOnPlatform => (
      title:
          l10n.universalImport_summary_noticeProfileUndecodableOnPlatformTitle,
      body: l10n.universalImport_summary_noticeProfileUndecodableOnPlatformBody,
      action: null,
    ),
    ImportNoticeKind.noTankPressure => (
      title: l10n.universalImport_summary_noticeNoTankPressureTitle,
      body: l10n.universalImport_summary_noticeNoTankPressureBody,
      action: null,
    ),
    ImportNoticeKind.unknownTransmitter => (
      title: l10n.universalImport_summary_noticeUnknownTransmitterTitle,
      body: l10n.universalImport_summary_noticeUnknownTransmitterBody,
      action: (
        label: l10n.universalImport_summary_noticeAssignTransmitters,
        route: '/transmitters',
      ),
    ),
    ImportNoticeKind.columnsNotImported => (
      title: l10n.universalImport_summary_noticeColumnsNotImportedTitle,
      body: l10n.universalImport_summary_noticeColumnsNotImportedBody(names),
      action: null,
    ),
    ImportNoticeKind.valuesNotConverted => (
      title: l10n.universalImport_summary_noticeValuesNotConvertedTitle,
      body: l10n.universalImport_summary_noticeValuesNotConvertedBody(
        notice.count,
      ),
      action: null,
    ),
    ImportNoticeKind.photosSkipped => (
      title: l10n.universalImport_summary_noticePhotosSkippedTitle,
      body: l10n.universalImport_summary_noticePhotosSkippedBody(notice.count),
      action: null,
    ),
    ImportNoticeKind.macdiveXmlOmitsCertsAndService => (
      title: l10n.universalImport_summary_noticeMacdiveXmlCertsTitle,
      body: l10n.universalImport_summary_noticeMacdiveXmlCertsBody,
      action: null,
    ),
    ImportNoticeKind.macdiveLogbooksNotImported => (
      title: l10n.universalImport_summary_noticeMacdiveLogbooksTitle,
      body: l10n.universalImport_summary_noticeMacdiveLogbooksBody(names),
      action: null,
    ),
    // No action button: Dive Numbering is a dialog on the dive list, not
    // a route, so the body tells the diver where to find it.
    ImportNoticeKind.diveNumberConflict => (
      title: l10n.universalImport_summary_noticeDiveNumberConflictTitle,
      body: l10n.universalImport_summary_noticeDiveNumberConflictBody,
      action: null,
    ),
  };
}

/// Explains something the diver should know about an import that succeeded:
/// data the source did not contain, or items that could not come across.
///
/// Styled as information, not as a problem: the import itself worked, and the
/// gap is in the source rather than in the import. Uses the theme's surface
/// container rather than an error colour for exactly that reason.
class _NoticeCard extends StatelessWidget {
  final ImportNotice notice;
  final _FileNoticeWording wording;

  const _NoticeCard({required this.notice, required this.wording});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final (:title, :body, :action) = wording;

    // Kinds that count values, photos or columns carry the count or names in
    // their body instead.
    final String? countLine = notice.kind.countsImportedDives
        ? l10n.universalImport_summary_noticeAffectedDives(notice.count)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (countLine != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      countLine,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.tonal(
                        onPressed: () => context.push(action.route),
                        child: Text(action.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileOutcomeRow extends StatelessWidget {
  final ImportFileOutcome outcome;

  const _FileOutcomeRow({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final icon = switch (outcome.status) {
      ImportFileOutcomeStatus.imported => Icons.check_circle_outline,
      ImportFileOutcomeStatus.parseFailed => Icons.error_outline,
      ImportFileOutcomeStatus.needsIndividualImport => Icons.block,
      ImportFileOutcomeStatus.unsupported => Icons.help_outline,
    };
    final label = switch (outcome.status) {
      ImportFileOutcomeStatus.imported =>
        l10n.universalImport_summary_fileImported(outcome.importedDives),
      ImportFileOutcomeStatus.parseFailed =>
        l10n.universalImport_summary_fileParseFailed,
      ImportFileOutcomeStatus.needsIndividualImport =>
        l10n.universalImport_summary_fileNeedsIndividualImport,
      ImportFileOutcomeStatus.unsupported =>
        l10n.universalImport_summary_fileUnsupported,
    };

    final canImportAsRoute =
        outcome.isNavTrackRoute && outcome.filePath != null;
    // Why a file failed, verbatim from its parser. Only failures carry one.
    final reason = outcome.status == ImportFileOutcomeStatus.parseFailed
        ? outcome.error
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  outcome.fileName,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (canImportAsRoute)
                TextButton(
                  key: const ValueKey('import-summary-import-as-route'),
                  onPressed: () => _importAsRoute(context),
                  child: Text(l10n.universalImport_summary_importAsRoute),
                ),
            ],
          ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              // Indented past the icon so the reason sits under the name.
              padding: const EdgeInsetsDirectional.only(start: 28, top: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Re-reads the excluded file from its stored path and hands it to the
  /// route review page. The batch pipeline only reads bytes to detect the
  /// format and does not keep them, so a Seacraft ENC file flagged
  /// `needsIndividualImport` would otherwise be a dead end in this batch
  /// summary with no way to actually import it as a route.
  Future<void> _importAsRoute(BuildContext context) async {
    final path = outcome.filePath;
    if (path == null) return;
    final l10n = context.l10n;
    try {
      final bytes = await File(path).readAsBytes();
      if (!context.mounted) return;
      await navigateToNavTrackReview(
        context,
        bytes,
        fileName: outcome.fileName,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dropTarget_error_readFailed)));
    }
  }
}

// ---------------------------------------------------------------------------
// Count row
// ---------------------------------------------------------------------------

class _CountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _CountRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
