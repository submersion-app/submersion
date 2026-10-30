import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/features/settings/presentation/widgets/git_host_note.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, GitHostKind kind) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GitHostNote(hostKind: kind)),
    ),
  );

  const expected = {
    GitHostKind.github: 'fine-grained token',
    GitHostKind.gitlab: 'write_repository',
    GitHostKind.bitbucket: 'API token',
    GitHostKind.giteaLike: 'write:repository',
    GitHostKind.other: 'can push to this repository',
  };

  for (final MapEntry(key: kind, value: text) in expected.entries) {
    testWidgets('${kind.name}: says which token to create', (tester) async {
      await pump(tester, kind);
      expect(find.textContaining(text), findsOneWidget);
      // Every recognized host links its own token documentation; an unknown
      // host has nothing to link to.
      expect(
        find.byKey(const Key('git-token-help')),
        kind == GitHostKind.other ? findsNothing : findsOneWidget,
      );
    });
  }

  test('each recognized host links to its own token documentation', () {
    expect(
      GitHostNote.tokenDocsFor(GitHostKind.github)?.host,
      'docs.github.com',
    );
    expect(
      GitHostNote.tokenDocsFor(GitHostKind.gitlab)?.host,
      'docs.gitlab.com',
    );
    expect(
      GitHostNote.tokenDocsFor(GitHostKind.bitbucket)?.host,
      'support.atlassian.com',
    );
    expect(
      GitHostNote.tokenDocsFor(GitHostKind.giteaLike)?.host,
      'forgejo.org',
    );
    expect(GitHostNote.tokenDocsFor(GitHostKind.other), isNull);
  });
}
