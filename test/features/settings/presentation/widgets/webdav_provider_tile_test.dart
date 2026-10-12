import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_provider_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<({List<String> calls})> pump(
    WidgetTester tester,
    WebDavConfig? config,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [webdavConfigProvider.overrideWith((ref) async => config)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WebDavProviderTile(
              isSelected: false,
              onSelect: () => calls.add('select'),
              onEdit: () => calls.add('edit'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (calls: calls);
  }

  testWidgets('unconfigured: generic subtitle, tap opens the editor', (
    tester,
  ) async {
    final r = await pump(tester, null);
    expect(find.text('Any WebDAV server'), findsOneWidget);
    await tester.tap(find.text('WebDAV'));
    expect(r.calls, ['edit']);
  });

  testWidgets('configured: account label, tap selects', (tester) async {
    final r = await pump(
      tester,
      WebDavConfig(
        serverUrl: 'https://dav.test/dav',
        username: 'alice',
        password: 'secret',
      ),
    );
    expect(find.text('alice @ dav.test'), findsOneWidget);
    await tester.tap(find.text('WebDAV'));
    expect(r.calls, ['select']);
  });
}
