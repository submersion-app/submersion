import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every built-in slug has a translated name', () {
    for (final t in kBuiltInSiteTypes) {
      expect(builtInSiteTypeName(l10n, t.id), t.name, reason: t.id);
    }
    expect(builtInSiteTypeName(l10n, 'mine'), isNull);
  });

  test('a custom type shows its own name, even with a built-in slug', () {
    final now = DateTime(2026);
    final custom = SiteTypeEntity(
      id: 'wreck',
      name: 'My wreck',
      createdAt: now,
      updatedAt: now,
    );
    expect(custom.localizedName(l10n), 'My wreck');
    expect(custom.copyWith(isBuiltIn: true).localizedName(l10n), 'Wreck');
  });
}
