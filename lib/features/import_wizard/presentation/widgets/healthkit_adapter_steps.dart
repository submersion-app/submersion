import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

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
  (ref) => healthKitWholeDayRange(
    DateTime.now().subtract(const Duration(days: 30)),
    DateTime.now(),
  ),
);

/// Widen a pair of picked dates to cover both days end to end.
///
/// The date pickers hand back midnight, and HealthKit matches samples with a
/// strict start-date predicate. Without this, picking the day of a dive as the
/// end date puts every dive that day *after* the range and finds nothing.
///
/// The end is the last instant of the day this API can express, not the last
/// instant of the day: the health plugin puts both bounds on the method
/// channel as `millisecondsSinceEpoch`, so anything finer than a millisecond
/// is truncated before HealthKit ever sees it. Spelling the end as
/// `23:59:59.999999` would send the very same integer.
DateTimeRange healthKitWholeDayRange(DateTime start, DateTime end) {
  return DateTimeRange(
    start: DateTime(start.year, start.month, start.day),
    end: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
  );
}

// =============================================================================
// Step widgets
// =============================================================================

/// How far the permissions step has got with HealthKit.
enum HealthKitPermissionUiState {
  /// Asking the platform what it knows.
  checking,

  /// The authorization sheet has been handed to the system.
  requesting,

  /// Access has been requested (or confirmed); the wizard may continue.
  ready,

  /// The platform confirms access is refused.
  refused,

  /// No health API on this platform.
  unavailable,
}

/// Permissions step for the HealthKit import wizard.
///
/// Asks the platform what it knows about read access and, when it will not
/// say, requests authorization outright. Apple never discloses read access and
/// only shows its sheet once, so requesting is both the only way to make
/// progress and safe to repeat: on later visits the system answers silently
/// and the step lands straight on the ready state.
class HealthKitPermissionsStep extends ConsumerStatefulWidget {
  const HealthKitPermissionsStep({super.key, required this.healthService});

  final HealthImportService healthService;

  @override
  ConsumerState<HealthKitPermissionsStep> createState() =>
      _HealthKitPermissionsStepState();
}

class _HealthKitPermissionsStepState
    extends ConsumerState<HealthKitPermissionsStep> {
  HealthKitPermissionUiState _state = HealthKitPermissionUiState.checking;

  @override
  void initState() {
    super.initState();
    _resolvePermissions();
  }

  Future<void> _resolvePermissions() async {
    HealthPermissionStatus status;
    try {
      status = await widget.healthService.permissionStatus();
    } catch (_) {
      status = HealthPermissionStatus.undetermined;
    }
    if (!mounted) return;

    switch (status) {
      case HealthPermissionStatus.unsupported:
        _setState(HealthKitPermissionUiState.unavailable);
      case HealthPermissionStatus.granted:
        _setState(HealthKitPermissionUiState.ready);
      case HealthPermissionStatus.denied:
        _setState(HealthKitPermissionUiState.refused);
      case HealthPermissionStatus.undetermined:
        await _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    _setState(HealthKitPermissionUiState.requesting);
    bool requested;
    try {
      requested = await widget.healthService.requestPermissions();
    } catch (_) {
      requested = false;
    }
    if (!mounted) return;
    _setState(
      requested
          ? HealthKitPermissionUiState.ready
          : HealthKitPermissionUiState.refused,
    );
  }

  void _setState(HealthKitPermissionUiState state) {
    setState(() => _state = state);
    ref.read(healthKitPermissionsGrantedProvider.notifier).state =
        state == HealthKitPermissionUiState.ready;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (_state) {
      case HealthKitPermissionUiState.checking:
        return const Center(child: CircularProgressIndicator());
      case HealthKitPermissionUiState.unavailable:
        return _Message(
          icon: Icons.info_outline,
          iconColor: theme.colorScheme.onSurfaceVariant,
          title: context.l10n.diveImport_healthkit_notAvailable,
          body: [context.l10n.diveImport_healthkit_notAvailableDescription],
        );
      case HealthKitPermissionUiState.ready:
        return _Message(
          icon: Icons.check_circle,
          iconColor: theme.colorScheme.primary,
          title: context.l10n.diveImport_healthkit_accessGranted,
          body: [
            context.l10n.diveImport_healthkit_accessGrantedBody,
            context.l10n.diveImport_healthkit_accessGrantedHint,
          ],
        );
      case HealthKitPermissionUiState.requesting:
      case HealthKitPermissionUiState.refused:
        return _Message(
          icon: Icons.health_and_safety,
          iconColor: theme.colorScheme.primary,
          title: context.l10n.diveImport_healthkit_accessRequired,
          body: [context.l10n.diveImport_healthkit_accessDescription],
          action: FilledButton.icon(
            icon: _state == HealthKitPermissionUiState.requesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety),
            // Neutral wording is a store requirement, not a style choice.
            // App Review rejected 1.7.4 under Guideline 5.1.1(iv) because this
            // button read "Grant HealthKit Access": a custom screen may not
            // urge the user toward the system authorization sheet. Apple named
            // "Continue" and "Next" as acceptable. Keep the label neutral, and
            // keep the headline a bare brand name, if this copy is revisited.
            label: Text(
              _state == HealthKitPermissionUiState.requesting
                  ? context.l10n.diveImport_healthkit_requesting
                  : context.l10n.diveImport_healthkit_grantAccess,
            ),
            onPressed: _state == HealthKitPermissionUiState.requesting
                ? null
                : _requestPermissions,
          ),
        );
    }
  }
}

/// Centred icon, headline, body paragraphs, and an optional action button.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 64, color: iconColor)),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            for (final paragraph in body) ...[
              const SizedBox(height: 8),
              Text(
                paragraph,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
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
        _publishRange();
      }
    });
  }

  void _publishRange() {
    ref.read(healthKitDateRangeProvider.notifier).state =
        healthKitWholeDayRange(_startDate, _endDate);
  }

  Future<void> _selectStartDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: _endDate,
    );
    if (selected != null && mounted) {
      setState(() => _startDate = selected);
      ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
      _publishRange();
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _endDate = selected);
      ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
      _publishRange();
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
          Text(
            context.l10n.diveImport_healthkit_selectDateRange,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveImport_healthkit_selectDateRangeBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DatePickerButton(
                  label: context.l10n.diveImport_healthkit_dateFrom,
                  date: _startDate,
                  dateText: dateFormat.format(_startDate),
                  onTap: _selectStartDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DatePickerButton(
                  label: context.l10n.diveImport_healthkit_dateTo,
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
        final message = context.l10n.diveImport_healthkit_fetchFailedBody('$e');
        setState(() {
          _isFetching = false;
          _error = message;
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
                context.l10n.diveImport_healthkit_fetchingDives,
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
              Text(
                context.l10n.diveImport_healthkit_fetchFailed,
                style: theme.textTheme.titleLarge,
              ),
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
        child: SingleChildScrollView(
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
                context.l10n.diveImport_healthkit_foundDives(_diveCount),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _diveCount == 0
                    ? context.l10n.diveImport_healthkit_foundNoDivesHint
                    : context.l10n.diveImport_healthkit_proceedingToReview,
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

    return const SizedBox.shrink();
  }
}
