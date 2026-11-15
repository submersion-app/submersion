import 'dart:async';

import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';

import 'fake_site_catalogue.dart';

/// A [CatalogueGapService] that touches no database: it answers with what
/// a test sets and records what it is asked, for tests of the screens and
/// providers above the service.
class FakeCatalogueGapService extends CatalogueGapService {
  FakeCatalogueGapService()
    : super(
        siteRepository: SiteRepository(),
        catalogue: FakeSiteCatalogue(),
        classification: SiteClassificationRepository(),
        fills: SiteCatalogueFillRepository(),
      );

  /// What [findPairs] answers.
  List<CataloguePair> pairs = const [];

  /// The diver of every [findPairs] call, and the check each was handed to
  /// learn that a newer search has replaced it.
  final asked = <String?>[];
  final cancelChecks = <bool Function()>[];

  /// The requests of every [apply] call, in order.
  final applied = <List<CatalogueApplyRequest>>[];

  /// What [apply] answers.
  CatalogueApplyResult result = const CatalogueApplyResult(
    linked: 1,
    filled: 1,
  );

  /// When set, an [apply] waits for it before it answers.
  Completer<void>? gate;

  /// When set, [apply] throws it.
  Object? failure;

  /// The sites answered "Not the same site" and "No thanks".
  final notSame = <String>[];
  final declined = <String>[];

  @override
  Future<List<CataloguePair>> findPairs({
    required String? diverId,
    bool Function()? isCancelled,
  }) async {
    asked.add(diverId);
    if (isCancelled != null) cancelChecks.add(isCancelled);
    return pairs;
  }

  @override
  Future<CatalogueApplyResult> apply(
    List<CatalogueApplyRequest> requests, {
    required String? diverId,
  }) async {
    applied.add(requests);
    await gate?.future;
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<void> answerNotSame(
    CataloguePair pair, {
    required String? diverId,
  }) async => notSame.add(pair.site.id);

  @override
  Future<void> declineAll(
    CataloguePair pair, {
    required String? diverId,
  }) async => declined.add(pair.site.id);
}
