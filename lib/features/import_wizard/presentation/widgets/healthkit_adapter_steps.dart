import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';

/// Riverpod [StateProvider] signalling whether HealthKit permissions have been
/// granted and the wizard may advance to the date range step.
final healthKitPermissionsGrantedProvider = StateProvider<bool>((ref) => false);

/// Riverpod [StateProvider] signalling whether a date range has been selected
/// and the wizard may advance to the fetch step.
final healthKitDateRangeSelectedProvider = StateProvider<bool>((ref) => true);

/// Riverpod [StateProvider] signalling whether dives have been fetched from
/// HealthKit and the wizard may advance to the review step.
final healthKitDivesFetchedProvider = StateProvider<bool>((ref) => false);

/// Riverpod [StateProvider] holding the user-selected date range for the
/// HealthKit fetch. Defaults to the last 30 days.
final healthKitDateRangeProvider = StateProvider<DateTimeRange>(
  (ref) => DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  ),
);

// =============================================================================
// Step widgets
// =============================================================================

/// Permissions step for the HealthKit import wizard.
///
/// Checks whether HealthKit permissions have already been granted. If not,
/// presents a button to request them. Sets [healthKitPermissionsGrantedProvider]
/// to true when permissions are granted.
class HealthKitPermissionsStep extends ConsumerStatefulWidget {
  const HealthKitPermissionsStep({super.key, required this.healthService});

  final HealthImportService healthService;

  @override
  ConsumerState<HealthKitPermissionsStep> createState() =>
      _HealthKitPermissionsStepState();
}

class _HealthKitPermissionsStepState
    extends ConsumerState<HealthKitPermissionsStep> {
  bool _isChecking = true;
  bool _isRequesting = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = await widget.healthService.hasPermissions();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _permissionsGranted = granted;
        });
        if (granted) {
          ref.read(healthKitPermissionsGrantedProvider.notifier).state = true;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    try {
      final granted = await widget.healthService.requestPermissions();
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _permissionsGranted = granted;
        });
        ref.read(healthKitPermissionsGrantedProvider.notifier).state = granted;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionsGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'HealthKit Access Granted',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can proceed to the next step.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.health_and_safety,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'HealthKit Access Required',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Submersion needs access to your Apple Health data to import '
              'dives recorded by your Apple Watch.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety),
              label: Text(
                _isRequesting ? 'Requesting...' : 'Grant HealthKit Access',
              ),
              onPressed: _isRequesting ? null : _requestPermissions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Date range step for the HealthKit import wizard.
///
/// Presents start and end date pickers defaulting to the last 30 days.
/// Sets [healthKitDateRangeSelectedProvider] to true when both dates are
/// selected (which they are by default). Updates
/// [healthKitDateRangeProvider] whenever the user changes a date.
class HealthKitDateRangeStep extends ConsumerStatefulWidget {
  const HealthKitDateRangeStep({super.key});

  @override
  ConsumerState<HealthKitDateRangeStep> createState() =>
      _HealthKitDateRangeStepState();
}

class _HealthKitDateRangeStepState
    extends ConsumerState<HealthKitDateRangeStep> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
    // Both dates are initialized so canAdvance starts true.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
        ref.read(healthKitDateRangeProvider.notifier).state = DateTimeRange(
          start: _startDate,
          end: _endDate,
        );
      }
    });
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: _endDate,
    );
    if (selected != null && mounted) {
      setState(() => _startDate = selected);
      ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
      ref.read(healthKitDateRangeProvider.notifier).state = DateTimeRange(
        start: _startDate,
        end: _endDate,
      );
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _endDate = selected);
      ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
      ref.read(healthKitDateRangeProvider.notifier).state = DateTimeRange(
        start: _startDate,
        end: _endDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select Date Range', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Choose the date range to search for dives in Apple Health.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DatePickerButton(
                  label: 'From',
                  date: _startDate,
                  dateText: dateFormat.format(_startDate),
                  onTap: _selectStartDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DatePickerButton(
                  label: 'To',
                  date: _endDate,
                  dateText: dateFormat.format(_endDate),
                  onTap: _selectEndDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple date picker button used by [HealthKitDateRangeStep].
class DatePickerButton extends StatelessWidget {
  const DatePickerButton({
    super.key,
    required this.label,
    required this.date,
    required this.dateText,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(dateText, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetch step for the HealthKit import wizard.
///
/// Reads the date range from [healthKitDateRangeProvider] and calls
/// [HealthImportService.fetchDives]. Shows a progress spinner while fetching.
/// When complete, calls [onDivesFetched] and sets
/// [healthKitDivesFetchedProvider] to true, triggering auto-advance.
class HealthKitFetchStep extends ConsumerStatefulWidget {
  const HealthKitFetchStep({
    super.key,
    required this.healthService,
    required this.onDivesFetched,
  });

  final HealthImportService healthService;
  final void Function(List<ImportedDive> dives) onDivesFetched;

  @override
  ConsumerState<HealthKitFetchStep> createState() => _HealthKitFetchStepState();
}

class _HealthKitFetchStepState extends ConsumerState<HealthKitFetchStep> {
  bool _isFetching = false;
  bool _hasFetched = false;
  int _diveCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDives();
    });
  }

  Future<void> _fetchDives() async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _error = null;
    });

    try {
      final range = ref.read(healthKitDateRangeProvider);
      final startDate = range.start;
      final endDate = range.end;

      final dives = await widget.healthService.fetchDives(
        startDate: startDate,
        endDate: endDate,
      );

      widget.onDivesFetched(dives);

      if (mounted) {
        setState(() {
          _isFetching = false;
          _hasFetched = true;
          _diveCount = dives.length;
        });
        ref.read(healthKitDivesFetchedProvider.notifier).state = true;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetching = false;
          _error = 'Failed to fetch dives: $e';
        });
        widget.onDivesFetched([]);
        ref.read(healthKitDivesFetchedProvider.notifier).state = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isFetching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Fetching dives from Apple Health...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text('Fetch Failed', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_hasFetched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Found $_diveCount dive${_diveCount == 1 ? '' : 's'}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Proceeding to review...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
