import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

/// Riverpod [StateProvider] signalling whether the FIT file acquisition step
/// has loaded dives and may advance to the review step.
///
/// Set to `true` externally via [FitAdapter.setParsedDives] after files have
/// been parsed and loaded.
final fitAdapterCanAdvanceProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for Garmin FIT files.
///
/// Implements [ImportSourceAdapter] for the unified import wizard. Supports
/// dives only (no sites, equipment, etc.) and duplicate detection via fuzzy
/// matching. The [consolidate] action is not supported — only [skip] and
/// [importAsNew] are available.
///
/// Acquisition (file picking) is handled externally: call [setParsedDives]
/// with the list of [ImportedDive]s produced by [FitParserService] before
/// [buildBundle] is invoked.
class FitAdapter implements ImportSourceAdapter {
  FitAdapter({
    required FitParserService fitParser,
    required DiveMatcher diveMatcher,
    required ImportedDiveConverter converter,
    required DiveRepository diveRepository,
    required String diverId,
    AppSettings settings = const AppSettings(),
    String displayName = 'FIT Import',
    WidgetRef? ref,
  }) : _fitParser = fitParser,
       _diveMatcher = diveMatcher,
       _converter = converter,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _settings = settings,
       _displayName = displayName,
       _ref = ref;

  final FitParserService _fitParser;
  final DiveMatcher _diveMatcher;
  final ImportedDiveConverter _converter;
  final DiveRepository _diveRepository;
  final String _diverId;
  final AppSettings _settings;
  final String _displayName;
  final WidgetRef? _ref;

  List<ImportedDive> _parsedDives = [];

  /// Load the list of already-parsed [ImportedDive]s into this adapter.
  ///
  /// Must be called before [buildBundle]. The actual file-picking UI is
  /// provided by the [acquisitionSteps] placeholder; the parsed dives are
  /// set here to decouple file I/O from the adapter logic.
  void setParsedDives(List<ImportedDive> dives) {
    _parsedDives = List.unmodifiable(dives);
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  void resetState() {
    _parsedDives = [];
    _ref?.invalidate(fitAdapterCanAdvanceProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.fit;

  @override
  String get displayName => _displayName;

  @override
  String get defaultTagName {
    final name = _displayName.trim();
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final base = name.toLowerCase().endsWith('import') ? name : '$name Import';
    return '$base $date';
  }

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Select Files',
      icon: Icons.file_open,
      builder: (context) => _FitFilePickerStep(
        fitParser: _fitParser,
        onDivesParsed: (dives) {
          setParsedDives(dives);
        },
      ),
      canAdvance: fitAdapterCanAdvanceProvider,
      autoAdvance: false,
    ),
  ];

  @override
  Future<ImportBundle> buildBundle() async {
    final items = _parsedDives.map(_diveToEntityItem).toList();

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.fit,
        displayName: _displayName,
      ),
      groups: {ImportEntityType.dives: EntityGroup(items: items)},
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final diveGroup = bundle.groups[ImportEntityType.dives];
    if (diveGroup == null || diveGroup.items.isEmpty) return bundle;

    final existingDives = await _diveRepository.getAllDives(diverId: _diverId);

    final duplicateIndices = <int>{};
    final matchResults = <int, DiveMatchResult>{};

    for (var i = 0; i < _parsedDives.length; i++) {
      final imported = _parsedDives[i];
      DiveMatchResult? bestMatch;

      for (final existing in existingDives) {
        final existingSeconds = _diveSeconds(existing);
        final score = _diveMatcher.calculateMatchScore(
          wearableStartTime: imported.startTime,
          wearableMaxDepth: imported.maxDepth,
          wearableDurationSeconds: imported.durationSeconds,
          existingStartTime: existing.effectiveEntryTime,
          existingMaxDepth: existing.maxDepth ?? 0.0,
          existingDurationSeconds: existingSeconds,
        );

        if (score >= 0.5) {
          if (bestMatch == null || score > bestMatch.score) {
            bestMatch = DiveMatchResult(
              diveId: existing.id,
              score: score,
              timeDifferenceMs: imported.startTime
                  .difference(existing.effectiveEntryTime)
                  .inMilliseconds
                  .abs(),
              depthDifferenceMeters:
                  ((imported.maxDepth) - (existing.maxDepth ?? 0.0)).abs(),
              durationDifferenceSeconds:
                  (imported.durationSeconds - existingSeconds).abs(),
              siteName: existing.site?.name,
            );
          }
        }
      }

      if (bestMatch != null) {
        duplicateIndices.add(i);
        matchResults[i] = bestMatch;
      }
    }

    return ImportBundle(
      source: bundle.source,
      groups: {
        ...bundle.groups,
        ImportEntityType.dives: EntityGroup(
          items: diveGroup.items,
          duplicateIndices: duplicateIndices,
          matchResults: matchResults,
        ),
      },
    );
  }

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
  }) async {
    final baseSelections = Set<int>.from(
      selections[ImportEntityType.dives] ?? <int>{},
    );
    final diveActions = duplicateActions[ImportEntityType.dives] ?? {};

    // Build the final set of indices to import and count skips.
    // - Plain selections are imported unless overridden with skip.
    // - importAsNew action adds an index even if not in plain selections.
    // - skip action removes an index and increments skipped count.
    final indicesToImport = <int>{};
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
      } else {
        indicesToImport.add(index);
      }
    }

    for (final entry in diveActions.entries) {
      if (entry.value == DuplicateAction.importAsNew) {
        indicesToImport.add(entry.key);
      } else if (entry.value == DuplicateAction.skip &&
          !baseSelections.contains(entry.key)) {
        // skip action on an index not in selections — count it as skipped
        skipped++;
      }
    }

    final sortedIndices = indicesToImport.toList()..sort();
    final total = sortedIndices.length;
    var imported = 0;
    final importedDiveIds = <String>[];

    for (var i = 0; i < sortedIndices.length; i++) {
      final index = sortedIndices[i];

      if (index >= _parsedDives.length) continue;

      final importedDive = _parsedDives[index];
      final dive = _converter.convert(importedDive, diverId: _diverId);
      await _diveRepository.createDive(dive);

      imported++;
      importedDiveIds.add(dive.id);
      onProgress?.call(ImportPhase.dives, i + 1, total);
    }

    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: 0,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Use runtime (total time), not duration (bottom time), to match the
  /// incoming side which uses runtime ?? duration.
  static int _diveSeconds(Dive dive) {
    if (dive.runtime != null) return dive.runtime!.inSeconds;
    if (dive.exitTime != null && dive.entryTime != null) {
      return dive.exitTime!.difference(dive.entryTime!).inSeconds;
    }
    if (dive.bottomTime != null) return dive.bottomTime!.inSeconds;
    return 0;
  }

  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');

  EntityItem _diveToEntityItem(ImportedDive dive) {
    final dateStr = _dateFormatter.format(dive.startTime);
    final timeStr = _timeFormatter.format(dive.startTime);
    final title = '$dateStr \u2014 $timeStr';

    final units = UnitFormatter(_settings);
    final durationMin = dive.duration.inMinutes;
    final tempStr = dive.minTemperature != null
        ? ' \u00b7 ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
        : '';
    final subtitle =
        '${units.formatDepth(dive.maxDepth)} max \u00b7 $durationMin min$tempStr';

    final profile = dive.profile
        .map(
          (s) => DiveProfilePoint(
            timestamp: s.timeSeconds,
            depth: s.depth,
            temperature: s.temperature,
            heartRate: s.heartRate,
          ),
        )
        .toList();

    final diveData = IncomingDiveData(
      startTime: dive.startTime,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      durationSeconds: dive.durationSeconds,
      waterTemp: dive.minTemperature,
      profile: profile,
    );

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
  }
}

// =============================================================================
// Private widgets
// =============================================================================

/// File picker step for the FIT import wizard.
///
/// Presents a button to select one or more .fit files, parses them with
/// [FitParserService], and invokes [onDivesParsed] with the results.
/// Sets [fitAdapterCanAdvanceProvider] to true once at least one dive is
/// successfully parsed.
class _FitFilePickerStep extends ConsumerStatefulWidget {
  const _FitFilePickerStep({
    required this.fitParser,
    required this.onDivesParsed,
  });

  final FitParserService fitParser;
  final void Function(List<ImportedDive> dives) onDivesParsed;

  @override
  ConsumerState<_FitFilePickerStep> createState() => _FitFilePickerStepState();
}

class _FitFilePickerStepState extends ConsumerState<_FitFilePickerStep> {
  bool _isParsing = false;
  int _totalFileCount = 0;
  int _skippedFileCount = 0;
  List<ImportedDive> _parsedDives = [];

  Future<void> _pickAndParseFiles() async {
    setState(() => _isParsing = true);

    try {
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['fit'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isParsing = false);
        return;
      }

      final fitFiles = result.files.where((f) {
        final ext = f.extension?.toLowerCase();
        return ext == 'fit';
      }).toList();

      if (fitFiles.isEmpty) {
        setState(() {
          _isParsing = false;
          _totalFileCount = result.files.length;
          _skippedFileCount = result.files.length;
          _parsedDives = [];
        });
        widget.onDivesParsed([]);
        return;
      }

      final fileBytesList = <Uint8List>[];
      final fileNames = <String>[];
      for (final file in fitFiles) {
        final path = file.path;
        if (path == null) continue;
        final bytes = await File(path).readAsBytes();
        fileBytesList.add(bytes);
        fileNames.add(file.name);
      }

      final dives = await widget.fitParser.parseFitFiles(
        fileBytesList,
        fileNames: fileNames,
      );

      widget.onDivesParsed(dives);

      if (mounted) {
        setState(() {
          _totalFileCount = fitFiles.length;
          _skippedFileCount = fitFiles.length - dives.length;
          _parsedDives = dives;
          _isParsing = false;
        });
      }

      ref.read(fitAdapterCanAdvanceProvider.notifier).state = dives.isNotEmpty;
    } catch (_) {
      if (mounted) {
        setState(() => _isParsing = false);
      }
      widget.onDivesParsed([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: _isParsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open),
            label: Text(_isParsing ? 'Parsing...' : 'Select Files'),
            onPressed: _isParsing ? null : _pickAndParseFiles,
          ),
        ),
        const SizedBox(height: 8),
        if (_totalFileCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _skippedFileCount > 0
                  ? 'Parsed ${_parsedDives.length} dive(s) from $_totalFileCount'
                        ' file(s) ($_skippedFileCount skipped)'
                  : 'Parsed ${_parsedDives.length} dive(s) from'
                        ' $_totalFileCount file(s)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: _parsedDives.isEmpty
              ? _buildEmptyState(context, theme)
              : _buildDiveList(theme),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.file_open,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('No dives loaded', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Select one or more .fit files exported from your Garmin device.',
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

  Widget _buildDiveList(ThemeData theme) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _parsedDives.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final dive = _parsedDives[index];
        final dateStr = _dateFormatter.format(dive.startTime);
        final timeStr = _timeFormatter.format(dive.startTime);
        final durationMin = dive.duration.inMinutes;

        return Card(
          child: ListTile(
            leading: const Icon(Icons.water),
            title: Text('$dateStr \u2014 $timeStr'),
            subtitle: Text(
              '${units.formatDepth(dive.maxDepth)} max \u00b7 $durationMin min',
            ),
          ),
        );
      },
    );
  }

  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');
}
