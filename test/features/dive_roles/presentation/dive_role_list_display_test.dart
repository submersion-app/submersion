import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_list_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026);
  final byId = {
    DiveRole.diveGuideId: DiveRole(
      id: DiveRole.diveGuideId,
      name: 'diveGuide',
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    'c1': DiveRole(
      id: 'c1',
      name: 'Photographer',
      createdAt: now,
      updatedAt: now,
    ),
  };

  test('joins localized names in the order given, keeping unknown ids', () {
    final roles = rolesForIds([DiveRole.diveGuideId, 'c1', 'mystery'], byId);
    expect(
      roles.joinedLocalizedNames(l10n),
      'Dive Guide, Photographer, mystery',
    );
  });

  test('an empty list joins to an empty string', () {
    expect(const <DiveRole>[].joinedLocalizedNames(l10n), '');
  });
}
