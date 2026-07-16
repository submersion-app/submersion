import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_fetch_step.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// True once the divelogs.de fetch has installed a payload into the
/// universal import notifier; gates the wizard's auto-advance to review.
final divelogsPayloadReadyProvider = Provider<bool>(
  (ref) => ref.watch(universalImportNotifierProvider).payload != null,
);

/// HTTP client for divelogs.de calls; null means the real network client.
/// Overridable so widget tests can supply a MockClient.
final divelogsHttpClientProvider = Provider<http.Client?>((ref) => null);

/// Import source that pulls the user's logbook from divelogs.de.
///
/// Reuses the entire universal pipeline (bundle building, duplicate check,
/// commit); only acquisition differs: sign in and fetch instead of a file.
class DivelogsImportAdapter extends UniversalAdapter {
  DivelogsImportAdapter({required super.ref})
    : super(displayName: 'divelogs.de');

  @override
  ImportSourceType get sourceType => ImportSourceType.divelogs;

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Sign In',
      icon: Icons.travel_explore_outlined,
      builder: (context) => const DivelogsFetchStep(),
      canAdvance: divelogsPayloadReadyProvider,
      autoAdvance: true,
    ),
  ];
}
