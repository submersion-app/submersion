import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The compact cards beside the profile chart sit in a narrow column on
/// desktop. Their header carries the title, the "@ mm:ss" cursor time, a
/// status badge or view controls, and the info icon, and must fit that
/// column: before the title gave way, adding the info icon overflowed the
/// Deco Status, Oxygen Toxicity and Tissue Loading headers. Gas Switches
/// shares the column and the same title widget.
const _comp = TissueCompartment(
  compartmentNumber: 1,
  halfTimeN2: 4.0,
  halfTimeHe: 1.51,
  mValueAN2: 1.2599,
  mValueBN2: 0.5050,
  mValueAHe: 1.7424,
  mValueBHe: 0.4245,
);

const _noDeco = DecoStatus(
  compartments: [_comp],
  ndlSeconds: 11022,
  ceilingMeters: 0.0,
  ttsSeconds: 120,
  gfLow: 0.5,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 10.0,
  ambientPressureBar: 2.0,
);

const _critical = O2Exposure(
  cnsStart: 0,
  cnsEnd: 110,
  otu: 43,
  otuStart: 0,
  maxPpO2: 1.7,
  maxPpO2Depth: 28,
);

Widget _host(double width, Widget child) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  // The test font draws every glyph a full em wide, far wider than the app's
  // font, so these widths overflowed the old headers while the card bodies
  // still fit. Narrower than this, the bodies' metric tiles overflow under the
  // test font too, and the test would no longer be about the header.
  for (final width in [300.0, 400.0]) {
    testWidgets('Deco Status header fits a $width px card', (tester) async {
      await tester.pumpWidget(
        _host(
          width,
          const CompactDecoStatusCard(status: _noDeco, subtitle: '31:00'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('@ 31:00'), findsOneWidget);
      expect(find.text('Deco Status'), findsOneWidget);
      expect(find.byTooltip('About Deco Status'), findsOneWidget);
    });
  }

  // The CRITICAL badge sits beside the title here, so the O2 body's wider
  // tiles set the floor at 400 under the test font.
  testWidgets('Oxygen Toxicity header fits a 400 px card', (tester) async {
    await tester.pumpWidget(
      _host(
        400,
        const CompactO2ToxicityPanel(exposure: _critical, subtitle: '31:00'),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('@ 31:00'), findsOneWidget);
    expect(find.text('Oxygen Toxicity'), findsOneWidget);
    expect(find.byTooltip('About Oxygen Toxicity'), findsOneWidget);
  });

  // The view menu, 3D button and info icon leave the title little room.
  testWidgets('Tissue Loading header fits a 400 px card', (tester) async {
    await tester.pumpWidget(
      _host(
        400,
        CompactTissueLoadingCard(
          status: _noDeco,
          subtitle: '31:00',
          onOpen3dView: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('@ 31:00'), findsOneWidget);
    expect(find.text('Tissue Loading'), findsOneWidget);
    expect(find.byTooltip('About Tissue Loading'), findsOneWidget);
  });

  // Gas Switches has no cursor time or badge, only the title and the info
  // icon, so it needs a narrower card than the others to reach its limit:
  // under the test font its old fixed title, icon and info slot needed 262 px.
  testWidgets('Gas Switches header fits a 220 px card', (tester) async {
    await tester.pumpWidget(
      _host(
        220,
        const GasSwitchEfficiencyCard(
          efficiency: GasSwitchEfficiency(
            evaluated: true,
            windows: [],
            totalExtraDecoSeconds: 0,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Gas switches'), findsOneWidget);
    expect(find.byTooltip('About Gas switches'), findsOneWidget);
  });
}
