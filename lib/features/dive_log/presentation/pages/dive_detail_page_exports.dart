part of 'dive_detail_page.dart';

/// The dive detail page's export actions: the overflow menu's export sheet and
/// everything it can start.
mixin _DiveDetailPageExports on ConsumerState<DiveDetailPage> {
  /// Key for capturing the profile chart as an image for PNG export
  final GlobalKey _profileChartExportKey = GlobalKey();

  /// Key for capturing the entire dive details page as an image for PNG export
  final GlobalKey _pageExportKey = GlobalKey();

  /// Whether an export is currently in progress
  bool _isExportingProfile = false;

  /// Whether a page export is currently in progress
  bool _isExportingPage = false;

  /// Export the profile chart as a PNG image and share it
  Future<void> _exportProfileChart(Dive dive, Rect? shareAnchor) async {
    if (!demoSealGuard(context, DemoSealedFeature.export)) return;
    // Show options bottom sheet
    final action = await showModalBottomSheet<_ProfileExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_exportImage_titleProfile,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.diveLog_exportImage_saveToPhotos),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToPhotosDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToPhotos),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.diveLog_exportImage_saveToFiles),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToFilesDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToFile),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.diveLog_exportImage_share),
              subtitle: Text(context.l10n.diveLog_exportImage_shareDescription),
              onTap: () => Navigator.pop(context, _ProfileExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    _isExportingProfile = true;

    try {
      // Wait for the next frame to ensure the chart is fully rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _profileChartExportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_captureFailed),
            ),
          );
        }
        return;
      }

      // Capture at 2x resolution for better quality
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_generateFailed),
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Generate filename with dive number and date
      final dateStr =
          '${dive.dateTime.year}-${dive.dateTime.month.toString().padLeft(2, '0')}-${dive.dateTime.day.toString().padLeft(2, '0')}';
      final diveNum = dive.diveNumber?.toString() ?? dive.id.substring(0, 8);
      final fileName = 'dive_profile_${diveNum}_$dateStr.png';

      final exportService = ExportService();

      switch (action) {
        case _ProfileExportAction.saveToPhotos:
          await exportService.saveImageToPhotos(pngBytes, fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToPhotos),
              ),
            );
          }
        case _ProfileExportAction.saveToFile:
          final savedPath = await exportService.saveImageToFile(
            pngBytes,
            fileName,
          );
          if (mounted && savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToFiles),
              ),
            );
          }
        case _ProfileExportAction.share:
          await exportService.exportImageAsPng(
            pngBytes,
            fileName,
            sharePositionOrigin: shareAnchor,
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
          ),
        );
      }
    } finally {
      _isExportingProfile = false;
    }
  }

  /// Export the entire dive details page as a PNG image
  Future<void> _exportDiveDetailsPage(Dive dive, Rect? shareAnchor) async {
    if (!demoSealGuard(context, DemoSealedFeature.export)) return;
    // Show options bottom sheet
    final action = await showModalBottomSheet<_ProfileExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_exportImage_titleDetails,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.diveLog_exportImage_saveToPhotos),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToPhotosDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToPhotos),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.diveLog_exportImage_saveToFiles),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToFilesDescription,
              ),
              onTap: () =>
                  Navigator.pop(context, _ProfileExportAction.saveToFile),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.diveLog_exportImage_share),
              subtitle: Text(context.l10n.diveLog_exportImage_shareDescription),
              onTap: () => Navigator.pop(context, _ProfileExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    _isExportingPage = true;

    try {
      // Wait for the next frame to ensure the content is fully rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _pageExportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_captureFailed),
            ),
          );
        }
        return;
      }

      // Capture at 2x resolution for better quality
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveLog_exportImage_generateFailed),
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Generate filename with dive number and date
      final dateStr =
          '${dive.dateTime.year}-${dive.dateTime.month.toString().padLeft(2, '0')}-${dive.dateTime.day.toString().padLeft(2, '0')}';
      final diveNum = dive.diveNumber?.toString() ?? dive.id.substring(0, 8);
      final fileName = 'dive_details_${diveNum}_$dateStr.png';

      final exportService = ExportService();

      switch (action) {
        case _ProfileExportAction.saveToPhotos:
          await exportService.saveImageToPhotos(pngBytes, fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToPhotos),
              ),
            );
          }
        case _ProfileExportAction.saveToFile:
          final savedPath = await exportService.saveImageToFile(
            pngBytes,
            fileName,
          );
          if (mounted && savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_savedToFiles),
              ),
            );
          }
        case _ProfileExportAction.share:
          await exportService.exportImageAsPng(
            pngBytes,
            fileName,
            sharePositionOrigin: shareAnchor,
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
          ),
        );
      }
    } finally {
      _isExportingPage = false;
    }
  }

  /// Export the dive as a PDF with save/share options
  Future<void> _exportDivePdf(Dive dive, Rect? shareAnchor) async {
    if (!demoSealGuard(context, DemoSealedFeature.export)) return;
    // Show options bottom sheet
    final action = await showModalBottomSheet<_PdfExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_exportImage_titlePdf,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.diveLog_exportImage_saveToFiles),
              subtitle: Text(
                context.l10n.diveLog_exportImage_saveToFilesDescription,
              ),
              onTap: () => Navigator.pop(context, _PdfExportAction.saveToFile),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.diveLog_exportImage_share),
              subtitle: Text(context.l10n.diveLog_exportImage_shareDescription),
              onTap: () => Navigator.pop(context, _PdfExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    // Same template picker as the Transfer page, so a single-dive export is
    // the document the diver chose rather than a fixed legacy layout.
    if (!mounted) return;
    final pdfOptions = await PdfExportDialog.show(context);
    // A null return means the diver cancelled, not that anything failed.
    if (pdfOptions == null) return;

    // Show loading dialog while generating PDF
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.diveLog_exportImage_generatingPdf),
          ],
        ),
      ),
    );

    try {
      final exportService = ref.read(exportServiceProvider);
      final settings = ref.read(settingsProvider);
      // The detail page already holds the dive's profile, so the chart does
      // not need another query.
      final profiles = dive.profile.isEmpty
          ? null
          : {dive.id: PdfProfileSeries.downsampled(dive.profile)};

      // getDiveById does not hydrate the buddy junction, but this page already
      // resolves it for its own Buddies section; #1017 wants them in the PDF.
      //
      // Best-effort: these enrich the document rather than define it, so a
      // failed lookup degrades to a plainer export instead of no export.
      var exportDive = dive;
      List<Certification>? certifications;
      Diver? diver;
      Uint8List? diverPhoto;
      try {
        final buddies = await ref.read(buddiesForDiveProvider(dive.id).future);
        if (buddies.isNotEmpty) exportDive = dive.copyWith(buddies: buddies);
        if (pdfOptions.includeCertificationCards) {
          certifications = await ref.read(allCertificationsProvider.future);
        }
        diver = await ref.read(currentDiverProvider.future);
        // The portrait travels with the diver: passing one without the other
        // leaves the Detailed front matter on its placeholder frame.
        diverPhoto = await ref.read(diverPhotoLoaderProvider)(diver?.photoPath);
      } catch (_) {
        // Export the dive as loaded.
      }
      // Awaited, not read from the page's snapshot: an export started while
      // the types load would otherwise print every name rebuilt from its id.
      final diveTypesById = await diveTypesByIdOrEmpty(
        ref.read(diveTypesByIdProvider.future),
      );

      final result = await exportService.generateDivePdfBytes(
        [exportDive],
        dates: PdfDateFormatter(
          dateFormat: settings.dateFormat,
          timeFormat: settings.timeFormat,
        ),
        units: UnitFormatter(settings),
        options: pdfOptions,
        profiles: profiles,
        certifications: certifications,
        diver: diver,
        diverPhoto: diverPhoto,
        diveTypesById: diveTypesById,
        diveRolesById: await diveRoleMapOrEmpty(
          ref.read(diveRoleMapProvider.future),
        ),
        // The diver's own gear arrangement (#3748).
        gearArrangement: await resolveEquipmentArrangement(ref.read),
      );

      // Close loading dialog BEFORE opening file picker to avoid navigator lock issues
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      switch (action) {
        case _PdfExportAction.saveToFile:
          final savedPath = await exportService.savePdfToFile(
            result.bytes,
            result.fileName,
          );
          if (mounted && savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.diveLog_exportImage_pdfSaved),
              ),
            );
          }
        case _PdfExportAction.share:
          await exportService.sharePdfBytes(
            result.bytes,
            result.fileName,
            sharePositionOrigin: shareAnchor,
          );
      }
    } catch (e) {
      // Try to close loading dialog if it's still open
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog may already be closed
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
          ),
        );
      }
    }
  }

  /// [shareAnchor] is the overflow button this sheet was opened from.
  ///
  /// The sheet pops itself before either export runs, so it cannot be the
  /// anchor for the iPad popover. The button that opened it is still mounted,
  /// which is also where iOS normally points a toolbar-initiated share sheet.
  void _showExportOptions(Dive dive, Rect? shareAnchor) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                dive.isPlanned
                    ? context.l10n.diveLog_planned_bannerTitle
                    : context.l10n.diveLog_export_titleDiveNumber(
                        dive.diveNumber ?? 0,
                      ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(context.l10n.diveLog_export_pdfLogbookEntry),
              subtitle: Text(context.l10n.diveLog_export_pdfDescription),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _exportDivePdf(dive, shareAnchor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(context.l10n.diveLog_export_csv),
              subtitle: Text(context.l10n.diveLog_export_csvDescription),
              onTap: () {
                final saveTitle =
                    context.l10n.settings_export_saveDivesCsvDialogTitle;
                Navigator.of(sheetContext).pop();
                // getDiveById does not hydrate the buddy junction, which the
                // Buddy and Dive Master columns read (#1861). Unlike the PDF
                // route's best-effort enrichment, a failed lookup fails the
                // export: those columns are data, and blanking them silently
                // would ship a wrong file.
                Future<List<Dive>> csvDives() async {
                  final buddies = await ref.read(
                    buddiesForDiveProvider(dive.id).future,
                  );
                  return [dive.copyWith(buddies: buddies)];
                }

                CsvExportUnits csvUnitsFor(ExportChoice choice) =>
                    CsvExportUnits.forMode(
                      choice.csvUnitMode,
                      ref.read(settingsProvider),
                    );

                _handleSingleDiveExport(
                  title: context.l10n.diveLog_export_csv,
                  offerCsvUnits: true,
                  shareFn: (choice) async => ref
                      .read(exportServiceProvider)
                      .exportDivesToCsv(
                        await csvDives(),
                        units: csvUnitsFor(choice),
                        diveTypesById: await diveTypesByIdOrEmpty(
                          ref.read(diveTypesByIdProvider.future),
                        ),
                      ),
                  saveFn: (choice) async => ref
                      .read(exportServiceProvider)
                      .saveDivesCsvToFile(
                        await csvDives(),
                        dialogTitle: saveTitle,
                        units: csvUnitsFor(choice),
                        diveTypesById: await diveTypesByIdOrEmpty(
                          ref.read(diveTypesByIdProvider.future),
                        ),
                      ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(context.l10n.diveLog_export_uddf),
              subtitle: Text(context.l10n.diveLog_export_uddfDescription),
              onTap: () {
                final sites = [if (dive.site != null) dive.site!];
                Navigator.of(sheetContext).pop();
                _handleSingleDiveExport(
                  title: context.l10n.diveLog_export_uddf,
                  offerRawData: true,
                  offerDiveContent: true,
                  shareFn: (choice) async => ref
                      .read(exportServiceProvider)
                      .exportDivesToUddf(
                        [dive],
                        sites: sites,
                        options: choice.options,
                        dataSources: await ref.read(uddfSourceFetchProvider)([
                          dive.id,
                        ], choice.options),
                        extras: await ref.read(uddfDivesExtrasFetchProvider)([
                          dive.id,
                        ], choice.options),
                        certificationCatalog: await ref.read(
                          allCustomCertificationsCatalogProvider.future,
                        ),
                      ),
                  saveFn: (choice) async => ref
                      .read(exportServiceProvider)
                      .saveDivesToUddfFile(
                        [dive],
                        sites: sites,
                        options: choice.options,
                        dataSources: await ref.read(uddfSourceFetchProvider)([
                          dive.id,
                        ], choice.options),
                        extras: await ref.read(uddfDivesExtrasFetchProvider)([
                          dive.id,
                        ], choice.options),
                        certificationCatalog: await ref.read(
                          allCustomCertificationsCatalogProvider.future,
                        ),
                      ),
                );
              },
            ),
            const Divider(height: 1),
            // Only offered when there is a chart to capture. The profile
            // section does not build for an empty profile, and the diver can
            // hide or fold it, so the RepaintBoundary _exportProfileChart
            // reads may not exist, and then the export could only fail.
            if (_profileChartExportKey.currentContext != null)
              ListTile(
                leading: const Icon(Icons.show_chart),
                title: Text(context.l10n.diveLog_export_profileAsImage),
                subtitle: Text(
                  context.l10n.diveLog_export_profileAsImageDescription,
                ),
                trailing: _isExportingProfile
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isExportingProfile
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _exportProfileChart(dive, shareAnchor);
                      },
              ),
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(context.l10n.diveLog_export_pageAsImage),
              subtitle: Text(
                context.l10n.diveLog_export_pageAsImageDescription,
              ),
              trailing: _isExportingPage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isExportingPage
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _exportDiveDetailsPage(dive, shareAnchor);
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Ask where the export should go, then run the matching delivery.
  ///
  /// The save path deliberately runs without the progress dialog: the system
  /// save panel must not open while a modal route is up (see [_exportDivePdf],
  /// which pops its dialog before calling the picker for the same reason).
  /// Generating a single dive's CSV/UDDF is in-memory work, so there is nothing
  /// to report progress on.
  ///
  /// Every pop of the progress dialog must pass `rootNavigator: true`.
  /// [showDialog] defaults to `useRootNavigator: true`, but a bare
  /// `Navigator.of(context)` resolves to the ShellRoute's navigator instead.
  /// In master-detail layouts this page is embedded in the shell's only route,
  /// so a bare pop removes that route and leaves a black screen under a modal
  /// that can no longer be dismissed.
  Future<void> _handleSingleDiveExport({
    required String title,
    required Future<String> Function(ExportChoice choice) shareFn,
    required Future<String?> Function(ExportChoice choice) saveFn,
    bool offerRawData = false,
    bool offerDiveContent = false,
    bool offerCsvUnits = false,
  }) async {
    final choice = await showExportDestinationSheetWithOptions(
      context,
      title: title,
      showRawDataToggle: offerRawData,
      showDiveContentToggles: offerDiveContent,
      showCsvUnitsToggle: offerCsvUnits,
      initialCsvUnitMode: ref.read(csvUnitModeProvider),
    );
    if (choice == null || !mounted) return;
    if (offerCsvUnits) {
      unawaited(ref.read(csvUnitModeProvider.notifier).set(choice.csvUnitMode));
    }
    final destination = choice.destination;

    final showProgress = destination == ExportDestination.share;
    if (showProgress) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Text(context.l10n.diveLog_export_exporting),
            ],
          ),
        ),
      );
    }

    try {
      final path = switch (destination) {
        ExportDestination.share => await shareFn(choice),
        ExportDestination.saveToFile => await saveFn(choice),
      };
      if (!mounted) return;
      if (showProgress) Navigator.of(context, rootNavigator: true).pop();
      // A null path means the save panel was dismissed, not a failure.
      if (path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_export_success),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        if (showProgress) Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_export_failed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Actions available for profile chart export
enum _ProfileExportAction { saveToPhotos, saveToFile, share }

/// Actions available for PDF export
enum _PdfExportAction { saveToFile, share }
