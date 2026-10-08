import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final mission = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );

  test('every issue type has a sentence', () {
    for (final type in MissionIssueType.values) {
      final text = missionIssueText(
        l10n,
        MissionIssue(
          type: type,
          severity: MissionIssueSeverity.blocking,
          legId: 'L1',
          memberId: 'm1',
        ),
        mission,
      );
      expect(text, isNotEmpty, reason: type.name);
    }
  });

  test('a member issue names the diver, a leg issue names the leg', () {
    expect(
      missionIssueText(
        l10n,
        const MissionIssue(
          type: MissionIssueType.scooterUnspecified,
          severity: MissionIssueSeverity.blocking,
          memberId: 'm1',
        ),
        mission,
      ),
      "Sam's scooter needs a speed and burn time",
    );
    expect(
      missionIssueText(
        l10n,
        const MissionIssue(
          type: MissionIssueType.legTooShort,
          severity: MissionIssueSeverity.blocking,
          legId: 'L1',
        ),
        mission,
      ),
      'Leg 1 is too short to travel',
    );
  });
}
