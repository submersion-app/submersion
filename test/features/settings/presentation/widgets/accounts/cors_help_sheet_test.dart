import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/cors_diagnoser.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/cors_help_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What a browser user sees when the store refuses it (issue #4121): the
/// verdict, why, and the rule to add, ready to copy.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  const origin = 'https://dives.example.com';

  Future<void> pumpSheet(WidgetTester tester, CorsDiagnosis diagnosis) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCorsHelpSheet(context, diagnosis),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the verdict, explains it and prints the rule', (
    tester,
  ) async {
    const diagnosis = CorsDiagnosis(
      verdict: CorsVerdict.blockedByCors,
      kind: StoreKind.minio,
      origin: origin,
    );
    await pumpSheet(tester, diagnosis);
    expect(find.text(en.web_cors_title_blockedByCors), findsOneWidget);
    expect(find.text(en.web_cors_explain_blockedByCors), findsOneWidget);
    expect(find.textContaining('mc admin config set'), findsOneWidget);
    expect(find.textContaining(origin), findsOneWidget);
    expect(find.text(en.web_cors_copyRule), findsOneWidget);
  });

  testWidgets('a refusal has no rule to copy', (tester) async {
    const diagnosis = CorsDiagnosis(
      verdict: CorsVerdict.forbidden,
      kind: StoreKind.awsS3,
      origin: origin,
    );
    await pumpSheet(tester, diagnosis);
    expect(find.text(en.web_cors_title_forbidden), findsOneWidget);
    expect(find.text(en.web_cors_copyRule), findsNothing);
    expect(find.textContaining('AllowedOrigins'), findsNothing);
  });

  testWidgets('Copy rule puts the rule on the clipboard and says so', (
    tester,
  ) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const diagnosis = CorsDiagnosis(
      verdict: CorsVerdict.writeBlockedByCors,
      kind: StoreKind.awsS3,
      origin: origin,
    );
    await pumpSheet(tester, diagnosis);
    await tester.tap(find.text(en.web_cors_copyRule));
    await tester.pumpAndSettle();
    expect(copied, diagnosis.ruleTemplate);
    expect(copied, contains('"PUT"'));
    expect(find.text(en.web_cors_copied), findsOneWidget);
  });
}
