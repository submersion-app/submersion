import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/data/services/dive_time_migration_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

class FixDiveTimesPage extends ConsumerStatefulWidget {
  const FixDiveTimesPage({super.key});

  @override
  ConsumerState<FixDiveTimesPage> createState() => _FixDiveTimesPageState();
}

class _FixDiveTimesPageState extends ConsumerState<FixDiveTimesPage> {
  final TextEditingController _offsetController = TextEditingController();
  final TextEditingController _rangeStartController = TextEditingController();
  final TextEditingController _rangeEndController = TextEditingController();

  List<DiveTimePreview> _dives = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = false;
  bool _isApplying = false;
  int _offsetHours = 0;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  late final DiveTimeMigrationService _migrationService;

  @override
  void initState() {
    super.initState();
    _migrationService = DiveTimeMigrationService(
      DatabaseService.instance.database,
    );
    _loadDives();
  }

  @override
  void dispose() {
    _offsetController.dispose();
    _rangeStartController.dispose();
    _rangeEndController.dispose();
    super.dispose();
  }

  Future<void> _loadDives() async {
    setState(() => _isLoading = true);
    try {
      final dives = await _migrationService.getDivesForPreview(
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
      );
      if (mounted) {
        setState(() {
          _dives = dives;
          // Remove selected IDs that are no longer in the list.
          _selectedIds.removeWhere((id) => !dives.any((d) => d.id == id));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings_fixDiveTimes_loadError('$e')),
          ),
        );
      }
    }
  }

  void _onOffsetChanged(String value) {
    final parsed = parseUserInt(value);
    setState(() => _offsetHours = parsed ?? 0);
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _dives.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_dives.map((d) => d.id));
      }
    });
  }

  void _toggleDive(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _pickRangeStart(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _rangeStart ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _rangeStart = DateTime.utc(picked.year, picked.month, picked.day);
      _rangeStartController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    await _loadDives();
  }

  Future<void> _pickRangeEnd(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _rangeEnd ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      // End of day in UTC.
      _rangeEnd = DateTime.utc(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
        59,
      );
      _rangeEndController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    await _loadDives();
  }

  void _clearDateRange() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
      _rangeStartController.clear();
      _rangeEndController.clear();
    });
    _loadDives();
  }

  Future<void> _applyOffset() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settings_fixDiveTimes_noSelection)),
      );
      return;
    }
    if (_offsetHours == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settings_fixDiveTimes_zeroOffset)),
      );
      return;
    }

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() => _isApplying = true);
    try {
      await _migrationService.applyOffset(
        diveIds: _selectedIds.toList(),
        hours: _offsetHours,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settings_fixDiveTimes_applied(
                _selectedIds.length,
                '$_offsetHours',
                _offsetHours.abs(),
              ),
            ),
          ),
        );
        setState(() {
          _selectedIds.clear();
          _offsetHours = 0;
          _offsetController.clear();
          _isApplying = false;
        });
        await _loadDives();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply offset: $e')));
      }
    }
  }

  Future<bool> _showConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings_fixDiveTimes_confirmTitle),
        content: Text(
          context.l10n.settings_fixDiveTimes_confirmBody(
            _selectedIds.length,
            '$_offsetHours',
            _offsetHours.abs(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.settings_fixDiveTimes_confirmApply),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final formatter = UnitFormatter(settings);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allSelected =
        _dives.isNotEmpty && _selectedIds.length == _dives.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_fixDiveTimes_title),
        actions: [
          if (_dives.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                allSelected
                    ? context.l10n.settings_fixDiveTimes_deselectAll
                    : context.l10n.settings_fixDiveTimes_selectAll,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            rangeStartController: _rangeStartController,
            rangeEndController: _rangeEndController,
            offsetController: _offsetController,
            onPickStart: () => _pickRangeStart(context),
            onPickEnd: () => _pickRangeEnd(context),
            onClearRange: _clearDateRange,
            onOffsetChanged: _onOffsetChanged,
            hasDateRange: _rangeStart != null || _rangeEnd != null,
          ),
          if (_selectedIds.isNotEmpty && _offsetHours != 0)
            _PreviewBanner(
              selectedCount: _selectedIds.length,
              offsetHours: _offsetHours,
              colorScheme: colorScheme,
              theme: theme,
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dives.isEmpty
                ? _EmptyState(
                    hasFilter: _rangeStart != null || _rangeEnd != null,
                  )
                : ListView.builder(
                    itemCount: _dives.length,
                    itemBuilder: (context, index) {
                      final dive = _dives[index];
                      final isSelected = _selectedIds.contains(dive.id);
                      return _DiveListItem(
                        dive: dive,
                        isSelected: isSelected,
                        offsetHours: _offsetHours,
                        formatter: formatter,
                        onChanged: (v) => _toggleDive(dive.id, v ?? false),
                        colorScheme: colorScheme,
                        theme: theme,
                      );
                    },
                  ),
          ),
          _ApplyBar(
            selectedCount: _selectedIds.length,
            offsetHours: _offsetHours,
            isApplying: _isApplying,
            onApply: _applyOffset,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Filter Bar
// ============================================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.rangeStartController,
    required this.rangeEndController,
    required this.offsetController,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearRange,
    required this.onOffsetChanged,
    required this.hasDateRange,
  });

  final TextEditingController rangeStartController;
  final TextEditingController rangeEndController;
  final TextEditingController offsetController;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearRange;
  final ValueChanged<String> onOffsetChanged;
  final bool hasDateRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settings_fixDiveTimes_dateRangeFilter,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: rangeStartController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.settings_fixDiveTimes_from,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: rangeEndController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.settings_fixDiveTimes_to,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: onPickEnd,
                ),
              ),
              if (hasDateRange) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: context.l10n.settings_fixDiveTimes_clearRange,
                  onPressed: onClearRange,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.settings_fixDiveTimes_hourOffset,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: offsetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: context.l10n.settings_fixDiveTimes_hoursField,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onOffsetChanged,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.l10n.settings_fixDiveTimes_offsetHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// Preview Banner
// ============================================================================

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.selectedCount,
    required this.offsetHours,
    required this.colorScheme,
    required this.theme,
  });

  final int selectedCount;
  final int offsetHours;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final direction = offsetHours > 0 ? '+$offsetHours' : '$offsetHours';
    return Container(
      width: double.infinity,
      color: colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.settings_fixDiveTimes_preview(
          selectedCount,
          direction,
          offsetHours.abs(),
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ============================================================================
// Dive List Item
// ============================================================================

class _DiveListItem extends StatelessWidget {
  const _DiveListItem({
    required this.dive,
    required this.isSelected,
    required this.offsetHours,
    required this.formatter,
    required this.onChanged,
    required this.colorScheme,
    required this.theme,
  });

  final DiveTimePreview dive;
  final bool isSelected;
  final int offsetHours;
  final UnitFormatter formatter;
  final ValueChanged<bool?> onChanged;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final currentTime = formatter.formatDateTimeBullet(dive.dateTime);
    final diveLabel = dive.diveNumber != null
        ? context.l10n.settings_fixDiveTimes_diveNumber(dive.diveNumber!)
        : context.l10n.settings_fixDiveTimes_diveFallback;
    final siteLabel = dive.siteName != null ? ' — ${dive.siteName}' : '';

    String? previewText;
    if (isSelected && offsetHours != 0) {
      final shiftedMs = DiveTimeMigrationService.computeShiftedEpoch(
        dive.dateTime.millisecondsSinceEpoch,
        offsetHours,
      );
      final shiftedDt = DateTime.fromMillisecondsSinceEpoch(
        shiftedMs,
        isUtc: true,
      );
      final newTime = formatter.formatDateTimeBullet(shiftedDt);
      previewText = '$currentTime  ->  $newTime';
    }

    return CheckboxListTile(
      value: isSelected,
      onChanged: onChanged,
      title: Text(
        '$diveLabel$siteLabel',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: previewText != null
          ? Text(
              previewText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
              ),
            )
          : Text(
              currentTime,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

// ============================================================================
// Apply Bar
// ============================================================================

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({
    required this.selectedCount,
    required this.offsetHours,
    required this.isApplying,
    required this.onApply,
    required this.colorScheme,
  });

  final int selectedCount;
  final int offsetHours;
  final bool isApplying;
  final VoidCallback onApply;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final canApply = selectedCount > 0 && offsetHours != 0 && !isApplying;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canApply ? onApply : null,
            icon: isApplying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              selectedCount == 0
                  ? context.l10n.settings_fixDiveTimes_selectDivesHint
                  : offsetHours == 0
                  ? context.l10n.settings_fixDiveTimes_enterOffsetHint
                  : context.l10n.settings_fixDiveTimes_apply(selectedCount),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Empty State
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? context.l10n.settings_fixDiveTimes_emptyFiltered
                  : context.l10n.settings_fixDiveTimes_empty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
