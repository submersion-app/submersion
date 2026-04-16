import 'package:flutter/material.dart';

import 'package:submersion/core/domain/models/dive_comparison_result.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/overlaid_profile_chart.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shared comparison card for dive duplicate resolution.
///
/// Used by the unified import wizard's duplicate resolution step and the
/// file import flow.  Fetches the existing dive and profile
/// from Riverpod providers and renders the hybrid comparison layout.
///
/// ## Modes
///
/// **Immediate-action mode** (default, backwards compatible): provide
/// [onSkip], [onImportAsNew], and/or [onConsolidate] callbacks. Each button
/// fires its callback immediately when tapped.
///
/// **Tri-state selector mode**: provide [selectedAction], [onActionChanged],
/// and optionally [availableActions]. Buttons render as toggles — the active
/// action uses a filled style and inactive ones use outlined style. Tapping a
/// button calls [onActionChanged] with the corresponding [DuplicateAction].
class DiveComparisonCard extends ConsumerWidget {
  final IncomingDiveData incoming;
  final String existingDiveId;
  final double matchScore;
  final String existingLabel;
  final String incomingLabel;

  // --- Immediate-action mode callbacks (backwards compatible) ---
  final VoidCallback? onSkip;
  final VoidCallback? onImportAsNew;
  final VoidCallback? onConsolidate;

  // --- Tri-state selector mode parameters ---

  /// When non-null, enables tri-state selector mode. The value indicates the
  /// currently selected action for this card.
  final DuplicateAction? selectedAction;

  /// Called when the user taps an action button in tri-state mode.
  final void Function(DuplicateAction)? onActionChanged;

  /// Which action buttons to show. When null, all three are shown.
  /// In immediate-action mode this has no effect.
  final Set<DuplicateAction>? availableActions;

  /// When true, skips the outer [Card] wrapper and renders content directly.
  ///
  /// Use this when the comparison card is embedded inside another card to
  /// avoid a nested card outline (grey line artifact).
  final bool embedded;

  /// Whether the enclosing row still needs an explicit user decision.
  ///
  /// When `true` AND [selectedAction] is `null`, a "Choose an action" label is
  /// rendered above the action-button row to make the required decision
  /// visually prominent. Has no effect in immediate-action mode.
  final bool isPending;

  const DiveComparisonCard({
    super.key,
    required this.incoming,
    required this.existingDiveId,
    required this.matchScore,
    this.existingLabel = 'Existing',
    this.incomingLabel = 'Downloaded',
    this.onSkip,
    this.onImportAsNew,
    this.onConsolidate,
    this.selectedAction,
    this.onActionChanged,
    this.availableActions,
    this.embedded = false,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final existingAsync = ref.watch(diveProvider(existingDiveId));
    final profileAsync = ref.watch(diveProfileProvider(existingDiveId));

    final content = existingAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Error loading dive data'),
      ),
      data: (existingDive) {
        if (existingDive == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Existing dive not found'),
          );
        }

        // Look up the personalized computer name from data sources.
        final dataSources =
            ref.watch(diveDataSourcesProvider(existingDiveId)).valueOrNull ??
            [];
        final primarySource = dataSources.isEmpty
            ? null
            : dataSources.firstWhere(
                (source) => source.isPrimary,
                orElse: () => dataSources.first,
              );
        final existingComputerName = primarySource?.computerId != null
            ? ref
                  .watch(diveComputerByIdProvider(primarySource!.computerId!))
                  .valueOrNull
                  ?.displayName
            : null;

        final comparison = compareForConsolidation(
          existingDive,
          incoming,
          existingComputerName: existingComputerName,
        );
        final existingProfile = profileAsync.valueOrNull ?? [];
        final diveNum = existingDive.diveNumber;
        final effectiveExistingLabel = diveNum != null
            ? '$existingLabel (#$diveNum)'
            : existingLabel;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overlaid Profiles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OverlaidProfileChart(
                existingProfile: existingProfile,
                incomingProfile: incoming.profile,
                existingLabel: _computerLabel(
                  null,
                  existingDive.diveComputerModel,
                  existingDive.diveComputerSerial,
                ),
                incomingLabel: _computerLabel(
                  incoming.computerName,
                  incoming.computerModel,
                  incoming.computerSerial,
                ),
                height: 80,
              ),
            ),

            // 3. Same Fields Summary
            if (comparison.sameFields.isNotEmpty)
              _buildSameSummary(context, comparison, units),

            // 4. Differences Table
            if (comparison.diffFields.isNotEmpty)
              _buildDiffTable(
                context,
                comparison,
                effectiveExistingLabel,
                units,
              ),

            // 5. Action Buttons
            _buildActionButtons(context, ref),
          ],
        );
      },
    );

    if (embedded) return content;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildSameSummary(
    BuildContext context,
    DiveComparisonResult comparison,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fieldNames = comparison.sameFields.map((f) => f.name).toList();
    final summary = fieldNames.join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.check, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Same: $summary',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffTable(
    BuildContext context,
    DiveComparisonResult comparison,
    String existingLabel,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIFFERENCES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Column headers
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('', style: theme.textTheme.labelSmall),
              ),
              Expanded(
                child: Text(
                  existingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  incomingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 4),
          // Diff rows
          ...comparison.diffFields.map(
            (field) => _buildDiffRow(context, field, units),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffRow(
    BuildContext context,
    DiffField field,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format values using UnitFormatter for unit-aware display.
    final existingStr =
        field.existingText ??
        (field.existingRaw != null
            ? _formatFieldValue(field.type, field.existingRaw, units)
            : null);
    final incomingStr =
        field.incomingText ??
        (field.incomingRaw != null
            ? _formatFieldValue(field.type, field.incomingRaw, units)
            : null);

    String formatValue(String? value) => value ?? 'not recorded';
    final hasExisting = existingStr != null;
    final hasIncoming = incomingStr != null;
    final isChanged = hasExisting && hasIncoming && field.name != 'computer';

    // Format incoming value with delta.
    String incomingDisplay = formatValue(incomingStr);
    if (field.delta != null && field.delta != 0) {
      final sign = field.delta! > 0 ? '+' : '';
      if (field.type == ComparisonFieldType.duration) {
        final deltaSec = field.delta!.round();
        final deltaMin = deltaSec ~/ 60;
        final remSec = deltaSec.abs() % 60;
        final deltaStr = deltaMin != 0
            ? '$sign${deltaMin}m${remSec > 0 ? ' ${remSec}s' : ''}'
            : '$sign${deltaSec}s';
        incomingDisplay = '$incomingStr ($deltaStr)';
      } else {
        incomingDisplay =
            '$incomingStr ($sign${field.delta!.toStringAsFixed(1)})';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              field.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              formatValue(existingStr),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              incomingDisplay,
              style: theme.textTheme.bodySmall?.copyWith(
                color: !hasIncoming
                    ? colorScheme.onSurfaceVariant
                    : (isChanged ? Colors.amber.shade700 : null),
                fontStyle: !hasIncoming ? FontStyle.italic : null,
                fontWeight: isChanged ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Tri-state selector mode is identified by the presence of an
    // [onActionChanged] callback. A pending row legitimately passes a null
    // [selectedAction] in this mode, so we cannot key off the action value.
    final isTriState = onActionChanged != null;

    // In tri-state mode, limit buttons to availableActions (default: all).
    bool showAction(DuplicateAction action) {
      if (!isTriState) return true;
      return availableActions == null || availableActions!.contains(action);
    }

    _ActionButtonStyle styleFor(
      DuplicateAction action,
      _ActionButtonStyle fallback,
    ) {
      if (!isTriState) return fallback;
      return selectedAction == action
          ? _ActionButtonStyle.filled
          : _ActionButtonStyle.outlined;
    }

    Color? colorFor(DuplicateAction action) {
      if (!isTriState) return null;
      return switch (action) {
        DuplicateAction.skip => colorScheme.error,
        DuplicateAction.importAsNew => Colors.green,
        DuplicateAction.consolidate => colorScheme.primary,
        DuplicateAction.replaceSource => Colors.orange,
      };
    }

    VoidCallback? callbackFor(DuplicateAction action, VoidCallback? legacyCb) {
      if (isTriState) return () => onActionChanged?.call(action);
      return legacyCb;
    }

    final buttons = <Widget>[];

    if (showAction(DuplicateAction.skip)) {
      buttons.add(
        _ActionButton(
          label: 'Skip',
          subtitle: 'Discard this download',
          onPressed: callbackFor(DuplicateAction.skip, onSkip),
          style: styleFor(DuplicateAction.skip, _ActionButtonStyle.text),
          color: colorFor(DuplicateAction.skip),
        ),
      );
    }

    if (showAction(DuplicateAction.importAsNew)) {
      buttons.add(
        _ActionButton(
          label: 'Import as New',
          subtitle: 'Save as separate dive',
          onPressed: callbackFor(DuplicateAction.importAsNew, onImportAsNew),
          style: styleFor(
            DuplicateAction.importAsNew,
            _ActionButtonStyle.outlined,
          ),
          color: colorFor(DuplicateAction.importAsNew),
        ),
      );
    }

    if (showAction(DuplicateAction.replaceSource)) {
      buttons.add(
        _ActionButton(
          label: context.l10n.universalImport_label_replaceSource,
          subtitle: context.l10n.universalImport_label_replaceSourceSubtitle,
          onPressed: callbackFor(DuplicateAction.replaceSource, null),
          style: styleFor(
            DuplicateAction.replaceSource,
            _ActionButtonStyle.outlined,
          ),
          color: colorFor(DuplicateAction.replaceSource),
        ),
      );
    }

    if (showAction(DuplicateAction.consolidate)) {
      buttons.add(
        _ActionButton(
          label: 'Consolidate',
          subtitle: 'Add as 2nd computer reading',
          onPressed: null, // Disabled — consolidation is under development.
          style: styleFor(
            DuplicateAction.consolidate,
            _ActionButtonStyle.outlined,
          ),
          color: colorFor(DuplicateAction.consolidate),
        ),
      );
    }

    // Show a "Choose an action" label when the enclosing row is pending and
    // no action has been selected yet — reinforces the pending visual cue and
    // makes the required decision prominent.
    final showChooseLabel = isPending && isTriState && selectedAction == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showChooseLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.l10n.universalImport_pending_chooseAction,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 4,
            children: buttons,
          ),
        ],
      ),
    );
  }

  /// Format a raw field value using UnitFormatter for unit-aware display.
  static String _formatFieldValue(
    ComparisonFieldType type,
    double? rawValue,
    UnitFormatter units,
  ) {
    if (rawValue == null) return '--';
    switch (type) {
      case ComparisonFieldType.depth:
        return units.formatDepth(rawValue);
      case ComparisonFieldType.temperature:
        return units.formatTemperature(rawValue);
      case ComparisonFieldType.duration:
        return '${(rawValue / 60).round()} min';
      case ComparisonFieldType.dateTime:
      case ComparisonFieldType.text:
        return rawValue.toString();
    }
  }

  String _computerLabel(String? name, String? model, String? serial) {
    final parts = <String>[];
    if (name != null && name.isNotEmpty) parts.add(name);
    if (model != null && model != name) parts.add(model);
    if (serial != null) parts.add('S/N: $serial');
    return parts.isEmpty ? 'Unknown' : parts.join(' \u00b7 ');
  }
}

enum _ActionButtonStyle { text, outlined, filled }

class _ActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;
  final _ActionButtonStyle style;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.subtitle,
    this.onPressed,
    required this.style,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isFilled = style == _ActionButtonStyle.filled;

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isFilled ? Colors.white : null,
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isFilled
                ? Colors.white.withValues(alpha: 0.85)
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );

    const minSize = Size(0, 48);

    // When the button is disabled (onPressed == null), skip the semantic
    // color/border so Material's default disabled styling takes over — keeps
    // the "not clickable" affordance visually clear.
    final isEnabled = onPressed != null;
    final effectiveColor = isEnabled ? color : null;
    switch (style) {
      case _ActionButtonStyle.text:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: minSize,
            foregroundColor: effectiveColor,
          ),
          child: child,
        );
      case _ActionButtonStyle.outlined:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            foregroundColor: effectiveColor,
            side: effectiveColor != null
                ? BorderSide(color: effectiveColor, width: 2.5)
                : null,
          ),
          child: child,
        );
      case _ActionButtonStyle.filled:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: minSize,
            backgroundColor: effectiveColor,
            foregroundColor: effectiveColor != null ? Colors.white : null,
          ),
          child: child,
        );
    }
  }
}
