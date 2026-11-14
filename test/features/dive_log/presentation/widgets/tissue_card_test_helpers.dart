import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Shared by the Tissue Loading card's test files.

const testCompartment = TissueCompartment(
  compartmentNumber: 1,
  halfTimeN2: 4.0,
  halfTimeHe: 1.51,
  mValueAN2: 1.2599,
  mValueBN2: 0.5050,
  mValueAHe: 1.7424,
  mValueBHe: 0.4245,
);

const testStatus = DecoStatus(
  compartments: [testCompartment],
  ndlSeconds: 600,
  ceilingMeters: 0.0,
  ttsSeconds: 0,
  gfLow: 0.4,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 10.0,
  ambientPressureBar: 2.0,
);

/// A status carrying all 16 Buhlmann compartments at surface saturation.
DecoStatus sixteenCompartmentStatus() => DecoStatus(
  compartments: BuhlmannAlgorithm().compartments,
  ndlSeconds: 600,
  ceilingMeters: 0.0,
  ttsSeconds: 0,
  gfLow: 0.4,
  gfHigh: 0.85,
  decoStops: const [],
  currentDepthMeters: 0.0,
  ambientPressureBar: 1.0,
);

Widget buildCard({
  DecoStatus status = testStatus,
  List<DecoStatus>? decoStatuses,
  bool expandVisualization = false,
  VoidCallback? onOpen3dView,
  bool scrollable = false,
  ThemeData? theme,
  TextDirection? textDirection,
  String? subtitle,
  List<int>? profileTimestamps,
}) {
  final card = CompactTissueLoadingCard(
    status: status,
    decoStatuses: decoStatuses,
    profileTimestamps: profileTimestamps,
    expandVisualization: expandVisualization,
    onOpen3dView: onOpen3dView,
    subtitle: subtitle,
  );
  final body = scrollable ? SingleChildScrollView(child: card) : card;
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: MaterialApp(
      // The assertions read English strings; pin the locale so they do not
      // depend on the host's.
      locale: const Locale('en'),
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Both real hosts (dive detail, current dive load page) scroll, so a
      // test that grows the card (the inline explanation) scrolls too.
      // An explicit direction keeps the English strings while laying the
      // card out right to left, as Arabic and Hebrew do.
      home: Scaffold(
        body: textDirection == null
            ? body
            : Directionality(textDirection: textDirection, child: body),
      ),
    ),
  );
}
