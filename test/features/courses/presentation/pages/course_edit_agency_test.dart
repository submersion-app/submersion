import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1715: the course editor must offer the same agencies as the
/// certification editor, so an agency added for certifications (FFESSM in
/// #1607) is never missing when logging the course that led to it.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<CertificationAgency>> agencyOptions(
    WidgetTester tester,
    Widget page,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<CertificationAgency>>(
      find.byType(DropdownButton<CertificationAgency>).first,
    );
    return [for (final item in dropdown.items!) item.value!];
  }

  testWidgets('course editor offers every agency, including FFESSM', (
    tester,
  ) async {
    final options = await agencyOptions(
      tester,
      const CourseEditPage(embedded: true),
    );

    expect(options, contains(CertificationAgency.ffessm));
    expect(options, CertificationAgency.values);
  });

  testWidgets('course and certification editors offer the same agencies', (
    tester,
  ) async {
    final courseOptions = await agencyOptions(
      tester,
      const CourseEditPage(embedded: true),
    );
    final certificationOptions = await agencyOptions(
      tester,
      const CertificationEditPage(embedded: true),
    );

    expect(courseOptions, certificationOptions);
  });
}
