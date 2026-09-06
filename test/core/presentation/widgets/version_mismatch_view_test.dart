import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database_provenance.dart';
import 'package:submersion/core/presentation/widgets/version_mismatch_view.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  // Pinned: flutter_test forwards the HOST machine's locale list, so an
  // unpinned MaterialApp resolves to a translated UI on a non-English dev
  // machine and every English assertion below finds nothing.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

VersionMismatchView buildView(
  UpdateChannel channel, {
  DatabaseProvenanceRecord? provenance,
}) => VersionMismatchView(
  databaseVersion: 154,
  appVersion: 153,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onDownloadLatest: () {},
  onClose: () {},
  provenance: provenance,
  channelOverride: channel,
);

void main() {
  testWidgets('store channel hides the GitHub download affordances', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.appstore)));

    // A store user cannot act on a GitHub link, so neither the button nor
    // the raw URL should be offered (issue #1089).
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.textContaining('app store'), findsOneWidget);
  });

  testWidgets('github channel keeps the download button and URL', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text(VersionMismatchView.latestReleaseUrl), findsOneWidget);
  });

  group('the build that wrote the database (issue #1593)', () {
    testWidgets('says nothing when the file records nothing', (tester) async {
      // Every database written before schema v194, which is exactly the fleet
      // stranded by #1568. The screen has to read correctly without it.
      await tester.pumpWidget(host(buildView(UpdateChannel.github)));
      expect(find.textContaining('last upgraded by'), findsNothing);
    });

    testWidgets('names the build and the train that upgraded the file', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          buildView(
            UpdateChannel.github,
            provenance: DatabaseProvenanceRecord.parse(const {
              'app_version': '1.7.8.8200',
              'release_train': 'beta',
              'upgrade_app_version': '1.7.7.8064',
              'upgrade_release_train': 'beta',
              'upgrade_written_at': '2026-09-05T10:00:00.000Z',
            }),
          ),
        ),
      );

      // The UPGRADE entry, not the most recent open: the build that put the
      // file on a rung this app cannot read is the one worth naming.
      expect(
        find.textContaining('Submersion 1.7.7.8064 (beta)'),
        findsOneWidget,
      );
      expect(find.textContaining('1.7.8.8200'), findsNothing);
    });

    testWidgets('falls back to the last build that opened the file', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          buildView(
            UpdateChannel.github,
            provenance: DatabaseProvenanceRecord.parse(const {
              'app_version': '1.7.8.8200',
              'release_train': 'stable',
              'written_at': '2026-09-05T10:00:00.000Z',
            }),
          ),
        ),
      );
      expect(
        find.textContaining('Submersion 1.7.8.8200 (stable)'),
        findsOneWidget,
      );
    });

    testWidgets('renders a train name this build has never heard of', (
      tester,
    ) async {
      // The train is written verbatim rather than translated precisely so a
      // build older than the train can still name it.
      await tester.pumpWidget(
        host(
          buildView(
            UpdateChannel.github,
            provenance: DatabaseProvenanceRecord.parse(const {
              'upgrade_app_version': '9.9.9.9999',
              'upgrade_release_train': 'nightly',
            }),
          ),
        ),
      );
      expect(
        find.textContaining('Submersion 9.9.9.9999 (nightly)'),
        findsOneWidget,
      );
    });

    testWidgets('drops the date when the file recorded none', (tester) async {
      await tester.pumpWidget(
        host(
          buildView(
            UpdateChannel.github,
            provenance: DatabaseProvenanceRecord.parse(const {
              'upgrade_app_version': '1.7.7.8064',
              'upgrade_written_at': 'last Tuesday',
            }),
          ),
        ),
      );
      final text = tester
          .widgetList<Text>(find.textContaining('1.7.7.8064'))
          .single
          .data!;
      expect(text, contains('Submersion 1.7.7.8064'));
      expect(text, endsWith('.'));
      expect(text, isNot(contains(' on ')));
    });

    testWidgets('says nothing when the file names no build at all', (
      tester,
    ) async {
      // A schema version and a timestamp with no version cannot answer the
      // question the line asks, so the line stays away.
      await tester.pumpWidget(
        host(
          buildView(
            UpdateChannel.github,
            provenance: DatabaseProvenanceRecord.parse(const {
              'schema_version': '210',
              'written_at': '2026-09-05T10:00:00.000Z',
            }),
          ),
        ),
      );
      expect(find.textContaining('last upgraded by'), findsNothing);
    });
  });
}
