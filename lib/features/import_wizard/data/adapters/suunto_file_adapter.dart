import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_dive_import_core.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_file_step.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Signals that the file step has read at least one dive.
final suuntoFileDivesReadyProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for Suunto app "export as JSON" files (issue
/// #1445): the same dive pipeline as the Suunto Cloud import, fed from
/// files instead of a signed-in account, so a dive's DiveRoute arrives
/// with it.
class SuuntoFileAdapter extends SuuntoDiveImportCore {
  SuuntoFileAdapter({
    required super.importService,
    required super.computerRepository,
    required super.diveRepository,
    required super.consolidationService,
    required super.diverId,
    super.routeWriter,
    super.ref,
    this.initialFiles = const [],
  });

  /// Files handed over by the universal wizard, a share or a drop, read as
  /// soon as the file step opens.
  final List<SuuntoJsonFile> initialFiles;

  /// What the file step last read, kept here because the wizard rebuilds
  /// the step when the diver comes back to it.
  List<SuuntoFileReadResult> _readResults = const [];

  /// Takes the file step's results: keeps them for a return to the step and
  /// loads their dives for import.
  void setReadResults(List<SuuntoFileReadResult> results) {
    _readResults = List.unmodifiable(results);
    setParsedDives([
      for (final r in results)
        if (r.dive != null) r.dive!,
    ]);
  }

  @override
  int? get sourceFileCount => _readResults.isEmpty ? null : _readResults.length;

  @override
  void resetState() {
    super.resetState();
    _readResults = const [];
    ref?.invalidate(suuntoFileDivesReadyProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.suuntoFile;

  @override
  String get displayName => 'Suunto JSON';

  @override
  String get defaultTagName => 'Suunto Import ${todayIsoDate()}';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Files',
      icon: Icons.description_outlined,
      builder: (context) => SuuntoFileStep(
        initialFiles: initialFiles,
        previousResults: _readResults,
        onRead: setReadResults,
      ),
      canAdvance: suuntoFileDivesReadyProvider,
      // The diver reviews which files were read (and why any were skipped)
      // before moving on, so the step never advances on its own.
      autoAdvance: false,
    ),
  ];
}
