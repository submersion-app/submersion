import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Media import review opens the shared site picker this way: no create
/// button and no device location lookup.
void main() {
  Widget host(
    void Function(SitePickerResult?) onPicked, {
    Future<List<DiveSite>> Function()? load,
  }) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        sitesProvider.overrideWith(
          (ref) =>
              load?.call() ??
              Future.value(const [
                DiveSite(id: 's1', name: 'Blue Hole'),
                DiveSite(id: 's2', name: 'Elphinstone'),
              ]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onPicked(
                await showSitePicker(context, useDeviceLocation: false),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('picking a site resolves it, with a search bar and no create', (
    tester,
  ) async {
    SitePickerResult? picked;
    await tester.pumpWidget(host((r) => picked = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('New Dive Site'), findsNothing);
    await tester.tap(find.text('Elphinstone'));
    await tester.pumpAndSettle();

    expect((picked! as SitePicked).site.id, 's2');
  });

  testWidgets('shows a spinner while sites are still loading', (tester) async {
    // Never completes: the sheet must not read as an empty picker.
    await tester.pumpWidget(
      host((_) {}, load: () => Completer<List<DiveSite>>().future),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('dismissing resolves null', (tester) async {
    SitePickerResult? picked = const SitePickerCleared();
    await tester.pumpWidget(host((r) => picked = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
}
