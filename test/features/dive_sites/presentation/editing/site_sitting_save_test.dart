import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_save.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// A save the service refuses because this profile may no longer edit the
/// site.
class _Refusing extends SiteEditSaveService {
  _Refusing() : super(SiteRepository());

  @override
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
  }) async => throw const SiteEditRefused('s1');
}

/// The site page says why a Save was refused (issue #4527, phase 2).
void main() {
  test('a Save refused for a lost right says so', () async {
    final session = EditSession<DiveSite>(
      const DiveSite(id: 's1', name: 'Blue Hole'),
    );
    addTearDown(session.dispose);

    final error = await saveSiteSitting(
      session,
      _Refusing(),
    ).then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<RecordSittingRefusal>());
    final l10n = AppLocalizationsEn();
    expect(
      (error! as RecordSittingRefusal).message(l10n),
      l10n.diveSites_edit_saveRefused,
    );
  });
}
