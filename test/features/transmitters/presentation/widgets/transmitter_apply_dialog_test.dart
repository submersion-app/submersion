import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter_slot_preview.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_apply_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Apply dialog's slot matches (issue #4347).
void main() {
  final firstDownload = DateTime.utc(2026, 3, 12, 9);

  SlotCandidate candidate(String id, {bool older = false}) => SlotCandidate(
    tankId: '$id-t',
    diveId: id,
    computerId: 'perdix',
    olderThanFirstDownload: older,
    firstDownload: older ? firstDownload : null,
  );

  final slots = TransmitterSlotPreview(
    candidates: [
      candidate('a'),
      candidate('b', older: true),
      candidate('c', older: true),
    ],
    changedHandsDiveIds: const {'x'},
    noSlotDiveIds: const {'y', 'z'},
    computerNames: const {'perdix': 'Perdix 2'},
  );

  Future<Set<String>?> open(
    WidgetTester tester, {
    required TransmitterSlotPreview slots,
    int serialTanks = 2,
    int serialDives = 2,
    Future<void> Function(WidgetTester)? interact,
  }) async {
    Set<String>? result;
    var closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<Set<String>>(
                  context: context,
                  builder: (_) => TransmitterApplyDialog(
                    serialTanks: serialTanks,
                    serialDives: serialDives,
                    slots: slots,
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact?.call(tester);
    if (!closed) {
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
    }
    return result;
  }

  testWidgets('shows the serial and slot lines, the older note and the '
      'skipped dives', (tester) async {
    await open(
      tester,
      slots: slots,
      interact: (tester) async {
        expect(find.text('2 dives by serial number'), findsOneWidget);
        expect(find.text('3 dives by slot on Perdix 2'), findsOneWidget);
        expect(
          find.textContaining('2 of them are from before your first download'),
          findsOneWidget,
        );
        expect(find.textContaining('2026'), findsOneWidget);
        expect(
          find.textContaining('1 dive skipped: another transmitter'),
          findsOneWidget,
        );
        expect(find.text('2 dives have no slot information'), findsOneWidget);
        expect(
          find.textContaining('5 cylinders on 5 dives carry this transmitter'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('Apply returns every slot tank while the switch is on', (
    tester,
  ) async {
    final result = await open(tester, slots: slots);
    expect(result, {'a-t', 'b-t', 'c-t'});
  });

  testWidgets('turning the switch off leaves out the older dives', (
    tester,
  ) async {
    final result = await open(
      tester,
      slots: slots,
      interact: (tester) async {
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('3 cylinders on 3 dives carry this transmitter'),
          findsOneWidget,
        );
        expect(find.text('1 dive by slot on Perdix 2'), findsOneWidget);
      },
    );
    expect(result, {'a-t'});
  });

  testWidgets('with no slot matches the dialog is the serial one alone', (
    tester,
  ) async {
    final result = await open(
      tester,
      slots: TransmitterSlotPreview.empty,
      interact: (tester) async {
        expect(find.byType(Switch), findsNothing);
        expect(find.textContaining('by slot'), findsNothing);
        expect(find.textContaining('by serial'), findsNothing);
        expect(
          find.textContaining('2 cylinders on 2 dives carry this transmitter'),
          findsOneWidget,
        );
      },
    );
    expect(result, isEmpty);
  });

  testWidgets('a computer with no name gets a generic label, never its id', (
    tester,
  ) async {
    await open(
      tester,
      slots: TransmitterSlotPreview(candidates: [candidate('a')]),
      interact: (tester) async {
        expect(find.text('1 dive by slot on a dive computer'), findsOneWidget);
        expect(find.textContaining('perdix'), findsNothing);
      },
    );
  });

  testWidgets('cancel returns nothing', (tester) async {
    final result = await open(
      tester,
      slots: slots,
      interact: (tester) async {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
    expect(result, isNull);
  });
}
