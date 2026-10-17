import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_connection_section.dart';

import '../../../../helpers/test_app.dart';

const _library = SharedLibrary(
  id: 'L',
  name: 'Reef Survey',
  connectedAccountId: 'a',
  prefix: 'puget-sound',
);

ConnectedAccount _account(AccountKind kind, String label) => ConnectedAccount(
  id: 'a',
  kind: kind,
  label: label,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _app(LibraryConnectionDetails details) => testAppRouter(
  router: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: LibraryConnectionSection(library: _library)),
      ),
      GoRoute(
        path: '/settings/shared-libraries/:id/connection',
        builder: (_, state) => Text('change ${state.pathParameters['id']}'),
      ),
    ],
  ),
  overrides: [
    libraryConnectionDetailsProvider('L').overrideWith((ref) async => details),
  ],
  locale: const Locale('en'),
);

void main() {
  testWidgets('an S3 account shows its label, bucket and folder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        LibraryConnectionDetails(
          account: _account(AccountKind.s3, 'group-sites @ s3.example.com'),
          prefix: 'puget-sound',
          bucket: 'group-sites',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connection on this device'), findsOneWidget);
    expect(find.text('group-sites @ s3.example.com'), findsOneWidget);
    expect(find.text('S3 account, bucket group-sites'), findsOneWidget);
    expect(find.text('submersion-sites/puget-sound'), findsOneWidget);
  });

  testWidgets('a WebDAV account shows its server', (tester) async {
    await tester.pumpWidget(
      _app(
        LibraryConnectionDetails(
          account: _account(AccountKind.webdav, 'ann @ dav.example.com'),
          prefix: '',
          server: 'https://dav.example.com/dav',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('WebDAV account, https://dav.example.com/dav'),
      findsOneWidget,
    );
    expect(find.text('submersion-sites'), findsOneWidget);
  });

  testWidgets('a missing account is named, and the connection can change', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const LibraryConnectionDetails(account: null, prefix: 'reef')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This account is no longer on this device'),
      findsOneWidget,
    );
    await tester.tap(find.text('Change connection'));
    await tester.pumpAndSettle();
    expect(find.text('change L'), findsOneWidget);
  });
}
