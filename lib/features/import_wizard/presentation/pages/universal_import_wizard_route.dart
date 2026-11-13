import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';

/// The file import wizard, with a [UniversalAdapter] built from Riverpod.
///
/// Public so both the router's `/transfer/import-wizard` route and the
/// import wizard nav shortcut (#2936) build the same page.
class UniversalImportWizardRoute extends ConsumerWidget {
  const UniversalImportWizardRoute({super.key, this.garminImport});

  /// The `source` query value that opens the wizard straight into the
  /// Garmin device import (issue #4223).
  static const garminDeviceSource = 'garmin-device';

  static const _computerParam = 'computer';
  static const _readAllParam = 'all';

  /// Where Connect New Computer's Garmin entry sends the diver: the watch's
  /// own serial finds its download marker.
  static const garminDeviceImportLocation =
      '/transfer/import-wizard?source=$garminDeviceSource';

  /// Where a saved Garmin's download screen sends the diver: its marker,
  /// or with [readAll] every activity ("Re-import all dives").
  static String garminDeviceImportLocationFor({
    String? computerId,
    bool readAll = false,
  }) => Uri(
    path: '/transfer/import-wizard',
    queryParameters: {
      'source': garminDeviceSource,
      _computerParam: ?computerId,
      if (readAll) _readAllParam: '1',
    },
  ).toString();

  /// The Garmin download [uri] asks for; null for a plain file import.
  static GarminImportRequest? garminImportFrom(Uri uri) {
    final query = uri.queryParameters;
    if (query['source'] != garminDeviceSource) return null;
    return GarminImportRequest(
      computerId: query[_computerParam],
      readAll: query[_readAllParam] == '1',
    );
  }

  /// Opens the wizard straight into this Garmin download (issue #4223).
  final GarminImportRequest? garminImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedImportWizard(
      adapter: UniversalAdapter(ref: ref, garminImport: garminImport),
    );
  }
}
