import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/computer_source_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

DiveDataSource _reading({
  required String id,
  required bool isPrimary,
  String? model,
  bool linked = true,
}) {
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: linked ? 'computer-$id' : null,
    isPrimary: isPrimary,
    computerModel: model,
    importedAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
  );
}

void main() {
  testWidgets('renders title, description and primary badge', (tester) async {
    final readings = [
      _reading(id: 'a', isPrimary: true, model: 'Perdix AI'),
      _reading(id: 'b', isPrimary: false, model: 'Suunto D5'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ComputerSourceSelectionSheet(readings: readings)),
      ),
    );
    expect(find.text('Choose starting profile'), findsOneWidget);
    expect(
      find.text("Select which computer's profile to edit from."),
      findsOneWidget,
    );
    expect(find.text('Perdix AI'), findsOneWidget);
    expect(find.text('Suunto D5'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
  });

  testWidgets('tapping a reading pops it as the result', (tester) async {
    final readings = [
      _reading(id: 'a', isPrimary: true, model: 'Perdix AI'),
      _reading(id: 'b', isPrimary: false, model: 'Suunto D5'),
    ];
    DiveDataSource? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<DiveDataSource>(
                    context: context,
                    builder: (_) =>
                        ComputerSourceSelectionSheet(readings: readings),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suunto D5'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'b');
  });

  group('startableProfileSources (#3066)', () {
    SourceProfile profile(String id, {required bool hasSamples}) =>
        SourceProfile(
          sourceId: id,
          computerId: null,
          isEdited: false,
          points: hasSamples
              ? const [DiveProfilePoint(timestamp: 0, depth: 1.0)]
              : const [],
        );

    test('keeps sources with samples, linked to a computer or not', () {
      // A file import carries no computerId but has its own samples.
      final sources = [
        _reading(id: 'a', isPrimary: true),
        _reading(id: 'b', isPrimary: false, linked: false),
      ];
      final profiles = {
        'a': profile('a', hasSamples: true),
        'b': profile('b', hasSamples: true),
      };
      expect(
        [for (final s in startableProfileSources(sources, profiles)) s.id],
        ['a', 'b'],
      );
    });

    test('drops sources the editor has no samples for', () {
      final sources = [
        _reading(id: 'a', isPrimary: true),
        _reading(id: 'b', isPrimary: false),
        _reading(id: 'c', isPrimary: false),
      ];
      final profiles = {
        'a': profile('a', hasSamples: true),
        'b': profile('b', hasSamples: false),
      };
      expect(
        [for (final s in startableProfileSources(sources, profiles)) s.id],
        ['a'],
      );
    });
  });
}
