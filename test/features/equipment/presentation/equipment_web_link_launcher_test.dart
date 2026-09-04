import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        // Pinned: flutter_test forwards the HOST machine's locale list, so an
        // unpinned MaterialApp resolves to a translated UI on a non-English
        // dev machine and every English assertion below fails.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('hands the link to the launcher and stays quiet on success', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    final launched = <Uri>[];

    await launchEquipmentWebLink(
      context,
      Uri.parse('https://shop.example.com/mk25'),
      launch: (uri) async {
        launched.add(uri);
        return true;
      },
    );
    await tester.pump();

    expect(launched, [Uri.parse('https://shop.example.com/mk25')]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('offers to copy the link when the platform refuses', (
    tester,
  ) async {
    final context = await pumpHost(tester);

    await launchEquipmentWebLink(
      context,
      Uri.parse('https://shop.example.com/mk25'),
      launch: (_) async => false,
    );
    await tester.pump();

    expect(find.text('Could not open the link'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
  });

  testWidgets('a throwing launcher is a refusal, not a crash', (tester) async {
    final context = await pumpHost(tester);

    await launchEquipmentWebLink(
      context,
      Uri.parse('https://shop.example.com/mk25'),
      launch: (_) async => throw MissingPluginException(),
    );
    await tester.pump();

    expect(find.text('Could not open the link'), findsOneWidget);
  });

  testWidgets('the copy action puts the link on the clipboard', (tester) async {
    final context = await pumpHost(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await launchEquipmentWebLink(
      context,
      Uri.parse('https://shop.example.com/mk25'),
      launch: (_) async => false,
    );
    // pumpAndSettle, not pump: the snackbar is still sliding up after one
    // frame, so its action sits below the 600px test viewport and the tap
    // misses.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pump();

    expect(copied, 'https://shop.example.com/mk25');
  });
}
