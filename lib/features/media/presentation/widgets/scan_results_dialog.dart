import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Result returned from the scan results dialog.
class ScanDialogResult {
  /// Whether the user confirmed the linking action.
  final bool confirmed;

  /// Photos selected for linking, keyed by dive.
  /// Only includes dives the user has checked.
  final Map<Dive, List<AssetInfo>> selectedPhotos;

  const ScanDialogResult({
    required this.confirmed,
    required this.selectedPhotos,
  });

  /// Result when user cancels the dialog.
  static const ScanDialogResult cancelled = ScanDialogResult(
    confirmed: false,
    selectedPhotos: {},
  );
}

/// Bottom sheet dialog that shows scan results with selection options.
///
/// Displays photos matched to dives with checkboxes to select which
/// dives' photos should be linked. All dives are checked by default.
class ScanResultsDialog extends StatefulWidget {
  final ScanResult scanResult;

  const ScanResultsDialog({super.key, required this.scanResult});

  @override
  State<ScanResultsDialog> createState() => _ScanResultsDialogState();
}

class _ScanResultsDialogState extends State<ScanResultsDialog> {
  /// Track which dives are selected for linking.
  late Map<Dive, bool> _selectedDives;

  @override
  void initState() {
    super.initState();
    // Initialize all dives as selected
    _selectedDives = Map.fromEntries(
      widget.scanResult.matchedByDive.keys.map((dive) => MapEntry(dive, true)),
    );
  }

  /// Count total photos from selected dives.
  int get _selectedCount {
    int count = 0;
    for (final entry in widget.scanResult.matchedByDive.entries) {
      if (_selectedDives[entry.key] == true) {
        count += entry.value.length;
      }
    }
    return count;
  }

  /// Build the map of selected photos for the result.
  Map<Dive, List<AssetInfo>> _buildSelectedPhotos() {
    final Map<Dive, List<AssetInfo>> result = {};
    for (final entry in widget.scanResult.matchedByDive.entries) {
      if (_selectedDives[entry.key] == true) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  void _onLink() {
    final result = ScanDialogResult(
      confirmed: true,
      selectedPhotos: _buildSelectedPhotos(),
    );
    Navigator.of(context).pop(result);
  }

  void _onCancel() {
    Navigator.of(context).pop(ScanDialogResult.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scanResult = widget.scanResult;

    // Check for empty state
    if (scanResult.totalNewPhotos == 0) {
      return _buildEmptyState(colorScheme, textTheme);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          _buildHandleBar(colorScheme),
          const SizedBox(height: 8),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.media_scanResults_foundNewPhotos(
                scanResult.totalNewPhotos,
              ),
              style: textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),

          // Already linked message
          if (scanResult.alreadyLinkedCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.media_scanResults_alreadyLinked(
                  scanResult.alreadyLinkedCount,
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Dive list with checkboxes
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // Matched dives
                  ..._buildDiveItems(colorScheme, textTheme),

                  // Unmatched photos warning
                  if (scanResult.unmatched.isNotEmpty)
                    _buildUnmatchedWarning(colorScheme, textTheme),
                ],
              ),
            ),
          ),

          // Action buttons
          const Divider(height: 1),
          _buildActionButtons(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHandleBar(ColorScheme colorScheme) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDiveItems(ColorScheme colorScheme, TextTheme textTheme) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();
    final sortedDives = widget.scanResult.matchedByDive.keys.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return sortedDives.map((dive) {
      final photoCount = widget.scanResult.matchedByDive[dive]?.length ?? 0;
      final isSelected = _selectedDives[dive] == true;

      // Build dive subtitle
      final siteName =
          dive.site?.name ?? context.l10n.media_scanResults_unknownSite;
      final dateStr = dateFormat.format(dive.dateTime);
      final timeStr = timeFormat.format(dive.effectiveEntryTime);

      return CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            _selectedDives[dive] = value ?? false;
          });
        },
        title: Text(
          dive.diveNumber != null
              ? context.l10n.media_scanResults_diveNumber(dive.diveNumber!)
              : siteName,
          style: textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dive.diveNumber != null)
              Text(
                siteName,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$dateStr at $timeStr',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$photoCount',
            style: textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }).toList();
  }

  Widget _buildUnmatchedWarning(ColorScheme colorScheme, TextTheme textTheme) {
    final unmatchedCount = widget.scanResult.unmatched.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: colorScheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.media_scanResults_unmatchedWarning(unmatchedCount),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    final selectedCount = _selectedCount;
    final hasSelection = selectedCount > 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _onCancel,
              child: Text(context.l10n.media_scanResults_cancelButton),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: hasSelection ? _onLink : null,
              child: Text(
                hasSelection
                    ? context.l10n.media_scanResults_linkCountButton(
                        selectedCount,
                      )
                    : context.l10n.media_scanResults_linkButton,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    final hasAlreadyLinked = widget.scanResult.alreadyLinkedCount > 0;
    final message = hasAlreadyLinked
        ? context.l10n.media_scanResults_allPhotosLinked
        : context.l10n.media_scanResults_noPhotosFound;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          _buildHandleBar(colorScheme),
          const SizedBox(height: 24),

          // Checkmark icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasAlreadyLinked ? Icons.check : Icons.photo_library_outlined,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),

          // Message
          Text(message, style: textTheme.titleMedium),
          const SizedBox(height: 8),

          if (hasAlreadyLinked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.l10n.media_scanResults_allPhotosLinkedDescription(
                  widget.scanResult.alreadyLinkedCount,
                ),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // OK button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(ScanDialogResult.cancelled),
                child: Text(context.l10n.media_scanResults_okButton),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Shows the scan results dialog as a bottom sheet.
///
/// Returns a [ScanDialogResult] indicating whether the user confirmed
/// and which photos were selected for linking.
Future<ScanDialogResult> showScanResultsDialog({
  required BuildContext context,
  required ScanResult scanResult,
}) async {
  final result = await showModalBottomSheet<ScanDialogResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) =>
          ScanResultsDialog(scanResult: scanResult),
    ),
  );

  return result ?? ScanDialogResult.cancelled;
}
