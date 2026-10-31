import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('every kind has a heading and an icon of its own', () {
    final labels = {
      for (final kind in GlobalSearchKind.values)
        globalSearchKindLabel(l10n, kind),
    };
    final icons = {
      for (final kind in GlobalSearchKind.values) globalSearchKindIcon(kind),
    };
    expect(labels, hasLength(GlobalSearchKind.values.length));
    expect(icons, hasLength(GlobalSearchKind.values.length));
  });
}
