import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/import_progress_dialog.dart';
import 'package:submersion/features/transfer/presentation/widgets/csv_export_dialog.dart';
import 'package:submersion/features/transfer/presentation/widgets/pdf_export_dialog.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_list_content.dart';

/// Main transfer page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with section list on left,
/// selected section content on right.
/// On narrower screens (<800px): Shows section list with navigation.
class TransferPage extends ConsumerWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'transfer',
        masterBuilder: (context, onItemSelected, selectedId) =>
            TransferListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, sectionId) =>
            _buildSectionContent(context, ref, sectionId),
        summaryBuilder: (context) => const _TransferSummaryWidget(),
      );
    }

    // Mobile: Check for selected section via query param
    String? selectedSection;
    try {
      selectedSection = GoRouterState.of(
        context,
      ).uri.queryParameters['selected'];
    } catch (_) {
      // GoRouter not available (e.g., in tests)
    }

    if (selectedSection != null) {
      // Show section detail page
      return _TransferSectionDetailPage(sectionId: selectedSection, ref: ref);
    }

    // Mobile: Show section list
    return const TransferMobileContent();
  }

  /// Builds the appropriate section content based on section ID.
  Widget _buildSectionContent(
    BuildContext context,
    WidgetRef ref,
    String sectionId,
  ) {
    switch (sectionId) {
      case 'import':
        return _ImportSectionContent(ref: ref);
      case 'export':
        return _ExportSectionContent(ref: ref);
      case 'computers':
        return _ComputersSectionContent(ref: ref);
      default:
        return Center(
          child: Text(context.l10n.transfer_unknownSection(sectionId)),
        );
    }
  }
}

/// Mobile content showing section list for navigation.
class TransferMobileContent extends StatelessWidget {
  const TransferMobileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.transfer_appBar_title)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: transferSections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = transferSections[index];
          return _MobileTransferTile(section: section);
        },
      ),
    );
  }
}

/// Mobile detail page for transfer sections accessed via query params.
class _TransferSectionDetailPage extends ConsumerWidget {
  final String sectionId;
  final WidgetRef ref;

  const _TransferSectionDetailPage({
    required this.sectionId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the section title
    final section = transferSections
        .where((s) => s.id == sectionId)
        .firstOrNull;
    final title =
        section?.titleBuilder(context) ?? context.l10n.transfer_appBar_title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.transfer_detail_backTooltip,
          onPressed: () => context.go('/transfer'),
        ),
      ),
      body: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (sectionId) {
      case 'import':
        return _ImportSectionContent(ref: ref);
      case 'export':
        return _ExportSectionContent(ref: ref);
      case 'computers':
        return _ComputersSectionContent(ref: ref);
      default:
        return Center(
          child: Text(context.l10n.transfer_unknownSection(sectionId)),
        );
    }
  }
}

class _MobileTransferTile extends StatelessWidget {
  final TransferSection section;

  const _MobileTransferTile({required this.section});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = section.color ?? colorScheme.primary;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(section.icon, color: color, size: 24),
      ),
      title: Text(
        section.titleBuilder(context),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        section.subtitleBuilder(context),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => _navigateToSection(context, section.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToSection(BuildContext context, String sectionId) {
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    context.go('$currentPath?selected=$sectionId');
  }
}

// ============================================================================
// SECTION CONTENT WIDGETS
// ============================================================================

/// Import section content
class _ImportSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _ImportSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.transfer_import_sectionHeader,
          ),
          const SizedBox(height: 8),
          // Universal Import (primary entry point)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              label: context.l10n.transfer_import_autoDetectSemanticLabel,
              child: InkWell(
                onTap: () => context.push('/transfer/import-wizard'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_fix_high,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.transfer_import_autoDetectTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.transfer_import_autoDetectSubtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legacy import options
          _buildSectionHeader(
            context,
            context.l10n.transfer_import_byFormatHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: Text(context.l10n.transfer_import_csvTitle),
                  subtitle: Text(context.l10n.transfer_import_csvSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handleImport(
                    context,
                    ref,
                    () => ref
                        .read(exportNotifierProvider.notifier)
                        .importDivesFromCsv(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(context.l10n.transfer_import_uddfTitle),
                  subtitle: Text(context.l10n.transfer_import_uddfSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/transfer/uddf-import'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_open),
                  title: Text(context.l10n.transfer_import_fitTitle),
                  subtitle: Text(context.l10n.transfer_import_fitSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/transfer/fit-import'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            context.l10n.transfer_import_aboutTitle,
            context.l10n.transfer_import_aboutContent,
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() importFn,
  ) async {
    var dialogShown = false;

    void showDialogIfNeeded(ExportState state) {
      if (!dialogShown &&
          state.importPhase != null &&
          state.status == ExportStatus.exporting &&
          context.mounted) {
        dialogShown = true;
        ImportProgressDialog.show(context);
      }
    }

    try {
      final subscription = ref.listenManual(
        exportNotifierProvider,
        (previous, next) => showDialogIfNeeded(next),
        fireImmediately: true,
      );

      try {
        await importFn();
      } finally {
        subscription.close();
      }

      if (context.mounted) {
        final state = ref.read(exportNotifierProvider);
        if (state.status != ExportStatus.idle) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message ??
                    context.l10n.transfer_import_operationCompleted,
              ),
              backgroundColor: state.status == ExportStatus.success
                  ? Colors.green
                  : Colors.red,
            ),
          );
        }
        ref.read(exportNotifierProvider.notifier).reset();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.transfer_import_operationFailed('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Export section content
class _ExportSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _ExportSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.transfer_export_sectionHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(context.l10n.transfer_export_pdfTitle),
                  subtitle: Text(context.l10n.transfer_export_pdfSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handlePdfExport(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(context.l10n.transfer_export_uddfTitle),
                  subtitle: Text(context.l10n.transfer_export_uddfSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_uddfTitle,
                    shareAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .exportDivesToUddf(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveUddfToFile(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: Text(context.l10n.transfer_export_csvTitle),
                  subtitle: Text(context.l10n.transfer_export_csvSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handleCsvExport(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(
            context,
            context.l10n.transfer_export_multiFormatHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: Text(context.l10n.transfer_export_excelTitle),
                  subtitle: Text(context.l10n.transfer_export_excelSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_excelTitle,
                    shareAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .exportToExcel(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveExcelToFile(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: Text(context.l10n.transfer_export_kmlTitle),
                  subtitle: Text(context.l10n.transfer_export_kmlSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_kmlTitle,
                    shareAction: () =>
                        ref.read(exportNotifierProvider.notifier).exportToKml(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveKmlToFile(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            context.l10n.transfer_export_aboutTitle,
            context.l10n.transfer_export_aboutContent,
          ),
        ],
      ),
    );
  }

  /// Handle PDF export with options dialog, then share/save options.
  Future<void> _handlePdfExport(BuildContext context, WidgetRef ref) async {
    // Show the PDF export options dialog first
    final options = await PdfExportDialog.show(context);

    // User cancelled or context no longer valid
    if (options == null || !context.mounted) return;

    // Now show share/save options
    _showExportOptions(
      context,
      ref,
      title: context.l10n.transfer_export_pdfTitle,
      shareAction: () =>
          ref.read(exportNotifierProvider.notifier).exportDivesToPdf(options),
      saveAction: () =>
          ref.read(exportNotifierProvider.notifier).savePdfToFile(options),
    );
  }

  /// Handle CSV export with type selection dialog, then share/save options.
  Future<void> _handleCsvExport(BuildContext context, WidgetRef ref) async {
    final type = await CsvExportDialog.show(context);
    if (type == null || !context.mounted) return;

    final notifier = ref.read(exportNotifierProvider.notifier);
    switch (type) {
      case CsvExportType.dives:
        _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionDivesTitle,
          shareAction: () => notifier.exportDivesToCsv(),
          saveAction: () => notifier.saveDivesCsvToFile(),
        );
      case CsvExportType.sites:
        _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionSitesTitle,
          shareAction: () => notifier.exportSitesToCsv(),
          saveAction: () => notifier.saveSitesCsvToFile(),
        );
      case CsvExportType.equipment:
        _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionEquipmentTitle,
          shareAction: () => notifier.exportEquipmentToCsv(),
          saveAction: () => notifier.saveEquipmentCsvToFile(),
        );
    }
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() exportFn,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.transfer_export_progressExporting),
          ],
        ),
      ),
    );

    try {
      await exportFn();
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            final state = ref.read(exportNotifierProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message ?? context.l10n.transfer_export_completed,
                ),
                backgroundColor: state.status == ExportStatus.success
                    ? Colors.green
                    : Colors.red,
              ),
            );
            ref.read(exportNotifierProvider.notifier).reset();
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.transfer_export_failed('$e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  /// Show export options dialog (Share vs Save to File).
  void _showExportOptions(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Future<void> Function() shareAction,
    required Future<void> Function() saveAction,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(context.l10n.transfer_export_optionShareTitle),
                subtitle: Text(
                  context.l10n.transfer_export_optionShareSubtitle,
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _handleExport(context, ref, shareAction);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(context.l10n.transfer_export_optionSaveTitle),
                subtitle: Text(context.l10n.transfer_export_optionSaveSubtitle),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _handleExport(context, ref, saveAction);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dive Computers section content
class _ComputersSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _ComputersSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computersAsync = ref.watch(allDiveComputersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.transfer_computers_sectionHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bluetooth_searching),
                  title: Text(context.l10n.transfer_computers_connectTitle),
                  subtitle: Text(
                    context.l10n.transfer_computers_connectSubtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dive-computers/discover'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: Text(context.l10n.transfer_computers_manageTitle),
                  subtitle: computersAsync.when(
                    data: (computers) => Text(
                      computers.isEmpty
                          ? context.l10n.transfer_computers_noComputersSaved
                          : context.l10n.transfer_computers_savedCount(
                              computers.length,
                            ),
                    ),
                    loading: () =>
                        Text(context.l10n.transfer_computers_loading),
                    error: (e, st) =>
                        Text(context.l10n.transfer_computers_errorLoading),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dive-computers'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(
            context,
            context.l10n.transfer_computers_appleWatchHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.watch),
              title: Text(context.l10n.transfer_computers_appleWatchTitle),
              subtitle: Text(
                context.l10n.transfer_computers_appleWatchSubtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/wearable-import'),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            context.l10n.transfer_computers_aboutTitle,
            context.l10n.transfer_computers_aboutContent,
          ),
        ],
      ),
    );
  }
}

/// Summary widget shown when no section is selected (desktop)
class _TransferSummaryWidget extends StatelessWidget {
  const _TransferSummaryWidget();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.sync_alt,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.transfer_summary_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.transfer_summary_description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.transfer_summary_selectSection,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

Widget _buildSectionHeader(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    ),
  );
}

Widget _buildInfoCard(BuildContext context, String title, String content) {
  return Card(
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
