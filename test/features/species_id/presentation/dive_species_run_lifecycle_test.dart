import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/presentation/providers/dive_species_run_providers.dart';

/// Records what the app's lifecycle told the run.
class _SpyRun extends DiveSpeciesRun {
  _SpyRun()
    : super(
        mediaForDive: (_) async => const [],
        diveLocation: (_) async => (exists: true, site: null, entry: null),
        request: (_, _) async => RunItemOutcome.done,
        cancel: (_) {},
        applyAll: (_, _) async => 0,
        databaseGeneration: () => 0,
      );

  final calls = <String>[];

  @override
  void appPaused() => calls.add('paused');

  @override
  void appResumed() => calls.add('resumed');
}

/// A Find species run pauses only when the app goes to the background
/// (issue #4727): on a Mac a minimised or covered window is hidden, and the
/// models run fine there.
void main() {
  test('a hidden or inactive window does not pause a run; the background '
      'does, and coming back resumes it', () {
    final run = _SpyRun();
    addTearDown(run.dispose);
    final lifecycle = RunLifecycle(run);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(run.calls, isEmpty);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.detached);
    expect(run.calls, ['paused', 'resumed']);
  });
}
