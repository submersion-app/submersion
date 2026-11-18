import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/presentation/change_log_value_format.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_entry_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// The feed's tile for a sitting (issue #4527): one that created its record
/// reads Added, and its subtitle names the cards without "Edited:".
void main() {
  final l = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());
  final operation = ChangeLogOperation(
    id: 'op',
    source: ChangeLogSource.manual,
    label: RecordEditLabel.encode(
      table: 'dives',
      id: 'd1',
      cardIds: ['header', 'notes'],
    ),
    rootTable: 'dives',
    rootId: 'd1',
    startedAt: DateTime(2026, 11, 17, 9, 30),
    endedAt: DateTime(2026, 11, 17, 9, 30),
  );

  Future<void> pumpTile(WidgetTester tester, ChangeLogAction? rootAction) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChangeLogEntryTile(
              operation: operation,
              preview: ChangeLogPreview(
                fields: const [],
                total: 0,
                rootAction: rootAction,
              ),
              formatter: ChangeLogValueFormatter(l10n: l, units: units),
              units: units,
              peerNames: const {},
              onTap: () {},
            ),
          ),
        ),
      );

  testWidgets('a sitting that created its dive reads Added, not Edited', (
    tester,
  ) async {
    await pumpTile(tester, ChangeLogAction.insert);
    expect(find.text(l.changeLog_action_added), findsOneWidget);
    expect(find.textContaining('Edited'), findsNothing);
    expect(
      find.textContaining('${l.diveLog_detail_section_header}, '),
      findsOneWidget,
    );
  });

  testWidgets('a sitting that edited its dive still reads Edited:', (
    tester,
  ) async {
    await pumpTile(tester, ChangeLogAction.update);
    expect(find.textContaining('Edited: '), findsOneWidget);
  });
}
