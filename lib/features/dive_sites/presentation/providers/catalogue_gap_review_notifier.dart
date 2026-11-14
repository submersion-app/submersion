import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// What the review list shows: the pairs, which rows are ticked, and the
/// fields chosen for a row in its comparison.
class CatalogueGapReviewState {
  const CatalogueGapReviewState({
    this.pairs = const [],
    this.ticked = const {},
    this.fieldChoices = const {},
    this.isApplying = false,
  });

  final List<CataloguePair> pairs;

  /// The site ids of the ticked rows.
  final Set<String> ticked;

  /// By site id, the fields the diver kept ticked in the comparison. A row
  /// with no entry applies every field it offers.
  final Map<String, Set<CatalogueGapField>> fieldChoices;
  final bool isApplying;

  int get tickedCount => ticked.length;

  /// The fields applying [pair] would fill.
  Set<CatalogueGapField> fieldsFor(CataloguePair pair) =>
      fieldChoices[pair.site.id]?.intersection(pair.fields) ?? pair.fields;

  CatalogueGapReviewState copyWith({
    List<CataloguePair>? pairs,
    Set<String>? ticked,
    Map<String, Set<CatalogueGapField>>? fieldChoices,
    bool? isApplying,
  }) => CatalogueGapReviewState(
    pairs: pairs ?? this.pairs,
    ticked: ticked ?? this.ticked,
    fieldChoices: fieldChoices ?? this.fieldChoices,
    isApplying: isApplying ?? this.isApplying,
  );
}

/// Holds the review list's ticks while the pairs underneath it are found
/// again after each change.
///
/// A pair is ticked when it first appears if the app is sure of it. After
/// that the tick is the diver's: finding the pairs again never re-ticks a
/// row they un-ticked, and drops what belonged to pairs that have gone.
class CatalogueGapReviewNotifier
    extends StateNotifier<CatalogueGapReviewState> {
  CatalogueGapReviewNotifier(this._ref)
    : super(const CatalogueGapReviewState()) {
    _ref.listen<AsyncValue<List<CataloguePair>>>(
      catalogueGapPairsProvider,
      (_, next) => _take(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  static final _log = LoggerService.forClass(CatalogueGapReviewNotifier);

  /// The pairs already seeded, as site id and record id: a pair seen
  /// before keeps whatever tick the diver left it with.
  final Set<String> _seeded = {};

  static String _seedKey(CataloguePair pair) =>
      '${pair.site.id}|${pair.record.id}';

  void _take(AsyncValue<List<CataloguePair>> next) {
    // While the pairs are being found again the rows stay as they are.
    final pairs = next.value;
    if (pairs == null || !mounted) return;
    final present = {for (final pair in pairs) pair.site.id};
    final ticked = state.ticked.intersection(present);
    for (final pair in pairs) {
      if (_seeded.add(_seedKey(pair)) && pair.preTicked) {
        ticked.add(pair.site.id);
      }
    }
    _seeded.retainAll({for (final pair in pairs) _seedKey(pair)});
    state = state.copyWith(
      pairs: pairs,
      ticked: ticked,
      fieldChoices: {
        for (final entry in state.fieldChoices.entries)
          if (present.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  void toggle(String siteId) {
    final ticked = {...state.ticked};
    if (!ticked.remove(siteId)) ticked.add(siteId);
    state = state.copyWith(ticked: ticked);
  }

  /// Keeps the fields the diver chose for a row in its comparison. The
  /// row's tick then applies exactly these.
  void setFields(String siteId, Set<CatalogueGapField> fields) {
    state = state.copyWith(
      fieldChoices: {...state.fieldChoices, siteId: fields},
    );
  }

  /// Applies every ticked row. Null when there is nothing to do: nothing
  /// is ticked, or an apply is already running.
  Future<CatalogueApplyResult?> applyTicked() => _apply([
    for (final pair in state.pairs)
      if (state.ticked.contains(pair.site.id))
        CatalogueApplyRequest(pair, state.fieldsFor(pair)),
  ]);

  /// Applies one pair now, with [fields].
  Future<CatalogueApplyResult?> applyOne(
    CataloguePair pair,
    Set<CatalogueGapField> fields,
  ) => _apply([CatalogueApplyRequest(pair, fields)]);

  Future<CatalogueApplyResult?> _apply(
    List<CatalogueApplyRequest> requests,
  ) async {
    if (state.isApplying || requests.isEmpty) return null;
    state = state.copyWith(isApplying: true);
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
      final result = await _ref
          .read(catalogueGapServiceProvider)
          .apply(requests, diverId: diverId);
      _afterWrite();
      return result;
    } catch (error, stackTrace) {
      _log.error(
        'Could not apply catalogue pairs',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isApplying: false);
    }
  }

  /// Remembers that [pair]'s record is a different place.
  Future<void> notSame(CataloguePair pair) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    await _ref
        .read(catalogueGapServiceProvider)
        .answerNotSame(pair, diverId: diverId);
    _afterWrite();
  }

  /// Turns down everything [pair] offers.
  Future<void> noThanks(CataloguePair pair) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    await _ref
        .read(catalogueGapServiceProvider)
        .declineAll(pair, diverId: diverId);
    _afterWrite();
  }

  /// The pairs are found again by their own change ticks; the site list
  /// some screens hold in memory is told here.
  void _afterWrite() {
    _ref.invalidate(catalogueGapPairsProvider);
    _ref.invalidate(siteListNotifierProvider);
  }
}

final catalogueGapReviewProvider =
    StateNotifierProvider.autoDispose<
      CatalogueGapReviewNotifier,
      CatalogueGapReviewState
    >((ref) => CatalogueGapReviewNotifier(ref));
