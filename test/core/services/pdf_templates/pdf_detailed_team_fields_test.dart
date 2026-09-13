import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// The Team section follows the same junction-authoritative rule as the dive
/// list's Buddy and Dive Master columns (`dive_field_extractor.dart`): once the
/// `dive_buddies` junction holds anyone, the legacy `Dive.buddy` and
/// `Dive.diveMaster` text is stale and must not print (#1864).
void main() {
  final epoch = DateTime(2024, 1, 1);

  BuddyWithRole person(String name, String roleId, String roleName) =>
      BuddyWithRole(
        buddy: Buddy(id: name, name: name, createdAt: epoch, updatedAt: epoch),
        role: DiveRole(
          id: roleId,
          name: roleName,
          isBuiltIn: true,
          createdAt: epoch,
          updatedAt: epoch,
        ),
      );

  final alice = person('Alice', DiveRole.buddyId, 'Buddy');
  final guido = person('Guido', DiveRole.diveMasterId, 'Dive Master');

  Dive teamDive({List<BuddyWithRole> buddies = const [], String? diveMaster}) =>
      Dive(
        id: 'd1',
        diveNumber: 42,
        dateTime: DateTime(2026, 8, 17, 11, 7),
        maxDepth: 18.0,
        buddies: buddies,
        diveMaster: diveMaster,
      );

  Future<List<int>> render(Dive dive) => PdfTemplateDetailed().buildPdf(
    dives: [dive],
    pageSize: PdfPageSize.a4,
    dates: PdfDateFormatter(
      dateFormat: DateFormatPreference.ddmmyyyy,
      timeFormat: TimeFormat.twentyFourHour,
    ),
    units: const UnitFormatter(AppSettings()),
  );

  int occurrences(List<int> bytes, String token) =>
      pdfTextTokens(bytes).where((t) => t == token).length;

  group('Team section dive master', () {
    test('omits stale legacy dive master text once a team is linked', () async {
      final text = pdfVisibleText(
        await render(teamDive(buddies: [alice], diveMaster: 'Hendricks')),
      );

      expect(text, contains('Alice'));
      expect(
        text,
        isNot(contains('Hendricks')),
        reason: 'the junction is authoritative once it holds anyone',
      );
      expect(text, isNot(contains('Dive Master')));
    });

    test(
      'lists a linked dive master once when the legacy text names them too',
      () async {
        final bytes = await render(
          teamDive(buddies: [alice, guido], diveMaster: 'Guido'),
        );

        expect(pdfVisibleText(bytes), contains('Dive Master'));
        expect(
          occurrences(bytes, 'Guido'),
          1,
          reason: 'the legacy scalar duplicated the linked Dive Master row',
        );
      },
    );

    test('prints the legacy dive master when no team is linked', () async {
      final text = pdfVisibleText(
        await render(teamDive(diveMaster: 'Hendricks')),
      );

      expect(text, contains('Dive Master'));
      expect(
        text,
        contains('Hendricks'),
        reason: 'a dive logged before the junction existed keeps its text',
      );
    });
  });
}
