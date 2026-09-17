import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Runs [payload] through [UniversalAdapter] the way the import wizard does:
/// buildBundle, checkDuplicates, then performImport. Every repository is the
/// real one over the current test database; only the parsed payload, the
/// active diver and the settings are supplied. Every item the review does
/// not flag is selected, and each flagged duplicate gets [duplicateAction].
///
/// [diver] must already exist in the database. Call from a testWidgets body
/// after setUpTestDatabase.
Future<UnifiedImportResult> importThroughWizard(
  WidgetTester tester, {
  required ImportPayload payload,
  required Diver diver,
  DuplicateAction duplicateAction = DuplicateAction.skip,
}) async {
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope per import, so a second import in one test never
      // reads the first one's payload or cached lists.
      key: UniqueKey(),
      overrides: [
        universalImportNotifierProvider.overrideWith(
          (ref) => _PayloadImportNotifier(ref, payload),
        ),
        settingsProvider.overrideWith((ref) => _DefaultSettings()),
        currentDiverProvider.overrideWith((ref) async => diver),
        // The review's duplicate check reads the diver's gear and tags
        // through these; the other libraries stay empty.
        allEquipmentProvider.overrideWith(
          (ref) => EquipmentRepository().getAllEquipment(diverId: diver.id),
        ),
        tagsProvider.overrideWith(
          (ref) => TagRepository().getAllTags(diverId: diver.id),
        ),
        allTripsProvider.overrideWith((ref) async => []),
        sitesProvider.overrideWith((ref) async => []),
        allBuddiesProvider.overrideWith((ref) async => []),
        allDiveCentersProvider.overrideWith((ref) async => []),
        allCertificationsProvider.overrideWith((ref) async => []),
        diveTypesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final result = await tester.runAsync(() async {
    final bundle = await adapter.checkDuplicates(await adapter.buildBundle());
    final selections = <ImportEntityType, Set<int>>{};
    final actions = <ImportEntityType, Map<int, DuplicateAction>>{};
    for (final MapEntry(key: type, value: group) in bundle.groups.entries) {
      selections[type] = {
        for (var i = 0; i < group.items.length; i++)
          if (!group.duplicateIndices.contains(i)) i,
      };
      actions[type] = {
        for (final i in group.duplicateIndices) i: duplicateAction,
      };
    }
    return adapter.performImport(bundle, selections, actions);
  });
  return result!;
}

class _PayloadImportNotifier extends UniversalImportNotifier {
  _PayloadImportNotifier(super.ref, ImportPayload payload) {
    state = state.copyWith(payload: payload);
  }
}

class _DefaultSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _DefaultSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
