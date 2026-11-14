import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_register.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_site_catalogue.dart';
import 'site_picker_built_in_harness.dart';

/// The register section on its own, where a test can move the anchor
/// without the picker reading the new place first.
class _Host extends StatefulWidget {
  const _Host(this.catalogue);

  final FakeSiteCatalogue catalogue;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  GeoPoint anchor = saltPier;

  late final section = SitePickerRegisterSection(
    catalogue: () => widget.catalogue,
    setState: setState,
    isMounted: () => mounted,
    currentAnchor: () => anchor,
    radiusMeters: 50000,
  );

  void moveTo(GeoPoint point) => setState(() => anchor = point);

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final row in section.rows(
        context,
        userSites: const [],
        anchor: anchor,
        anchorIsInferred: false,
        placeLabel: null,
        formatDistance: (meters) => '${meters.round()} m',
        busy: false,
        onTap: (_) {},
        onDetails: (_) {},
      ))
        row(),
    ],
  );
}

void main() {
  testWidgets('a count belongs to the place it was counted for', (
    tester,
  ) async {
    final catalogue = FakeSiteCatalogue([
      registerSite('w1', 'Zulu Trader', north: 200),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _Host(catalogue)),
      ),
    );
    final host = tester.state<_HostState>(find.byType(_Host));
    await host.section.load(saltPier);
    await tester.pump();
    expect(find.text('Show charted wrecks and reefs (1)'), findsOneWidget);

    // The dive's area moves to a lake; the new place is not counted yet.
    host.moveTo(const GeoPoint(47.5, 9.5));
    await tester.pump();

    expect(find.textContaining('Show charted wrecks'), findsNothing);

    await host.section.load(const GeoPoint(47.5, 9.5));
    await tester.pump();
    expect(find.textContaining('Show charted wrecks'), findsNothing);
  });
}
