part of 'unified_import_wizard.dart';

/// The unified import wizard shell.
///
/// Accepts an [ImportSourceAdapter] and orchestrates the full import flow:
/// acquisition steps (source-specific), review, import progress, and summary.
///
/// The adapter is a per-session object: it accumulates acquisition state
/// (a dive computer download, a picked file) that the later steps consume.
/// The wizard therefore pins the adapter it is first built with and keeps
/// using it even if an ancestor rebuilds this widget with a different
/// instance. Route builders create their adapter in `build`, so a provider
/// re-emitting mid-session (the dive computer download route watches the
/// computer record, which the download itself writes on completion) would
/// otherwise swap in a fresh, empty adapter between the download and the
/// Review step.
class UnifiedImportWizard extends StatefulWidget {
  const UnifiedImportWizard({
    super.key,
    required this.adapter,
    this.initialPageOverride,
    this.notifierFactoryOverride,
  });

  /// The adapter this widget was built with. The session adapter is the one
  /// the wizard was FIRST built with; see the class doc.
  final ImportSourceAdapter adapter;

  /// Optional starting page for widget tests that need to exercise behavior
  /// on pages past the acquisition/review flow (e.g. the cancel dialog on
  /// the import-progress page) without driving the full adapter through
  /// [ImportSourceAdapter.buildBundle] and [performImport].
  @visibleForTesting
  final int? initialPageOverride;

  /// Optional notifier factory for tests that need to inject a pre-configured
  /// [ImportWizardNotifier] (e.g. one whose state already has
  /// `isCancellationRequested: true` so the "already cancelling" dialog
  /// branch can be exercised).
  @visibleForTesting
  final ImportWizardNotifier Function(Ref ref)? notifierFactoryOverride;

  @override
  State<UnifiedImportWizard> createState() => _UnifiedImportWizardState();
}

class _UnifiedImportWizardState extends State<UnifiedImportWizard> {
  /// The session adapter, captured once. Deliberately not refreshed in
  /// didUpdateWidget: a replacement instance carries none of the state the
  /// acquisition steps already committed to this one.
  late final ImportSourceAdapter _adapter = widget.adapter;

  @override
  Widget build(BuildContext context) {
    return RunningImportGate(
      title: _adapter.displayName,
      child: ProviderScope(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            widget.notifierFactoryOverride ??
                (ref) => ImportWizardNotifier(
                  _adapter,
                  tagRepository: ref.read(tagRepositoryProvider),
                  ruleEngine: ref.read(ruleEngineProvider),
                  gpsTrackMatchService: ref.read(gpsTrackMatchServiceProvider),
                  equipmentDefaulter: DiveEquipmentDefaulter(),
                  healthMetrics: ref.read(diveHealthMetricsServiceProvider),
                  job: ref.read(importJobProvider.notifier),
                  // Only the universal adapters read through a container
                  // that outlives the wizard (#3554); every other source
                  // stops when the wizard goes away.
                  continuesWithoutWizard: _adapter is UniversalAdapter,
                ),
          ),
        ],
        child: _withScanScope(
          _UnifiedImportWizardBody(
            adapter: _adapter,
            initialPageOverride: widget.initialPageOverride,
          ),
        ),
      ),
    );
  }

  Widget _withScanScope(Widget body) => _adapter is DiveComputerAdapter
      ? DiveComputerScanScope(child: body)
      : body;
}
