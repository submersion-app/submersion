import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// What the review list shows: the pairs, which rows are ticked, and the
/// fields un-ticked for a row in its comparison.
class CatalogueGapReviewState {
  const CatalogueGapReviewState({
    this.pairs = const [],
    this.ticked = const {},
    this.untickedFields = const {},
    this.isWriting = false,
  });

  final List<CataloguePair> pairs;

  /// The site ids of the ticked rows.
  final Set<String> ticked;

  /// By site id, the fields the diver un-ticked in the comparison. A row
  /// applies every field it offers but these.
  ///
  /// Kept as what was turned away, not what was chosen: a field the record
  /// gains after the diver looked is then offered like any other, and is
  /// never turned down without having been shown.
  final Map<String, Set<CatalogueGapField>> untickedFields;

  /// A write is under way and the pairs have not been found again since:
  /// an apply, or an answer. The list still shows rows the write has dealt
  /// with, so nothing more is sent until it has caught up.
  final bool isWriting;

  int get tickedCount => ticked.length;

  /// The fields applying [pair] would fill.
  Set<CatalogueGapField> fieldsFor(CataloguePair pair) =>
      pair.fields.difference(untickedFields[pair.site.id] ?? const {});

  CatalogueGapReviewState copyWith({
    List<CataloguePair>? pairs,
    Set<String>? ticked,
    Map<String, Set<CatalogueGapField>>? untickedFields,
    bool? isWriting,
  }) => CatalogueGapReviewState(
    pairs: pairs ?? this.pairs,
    ticked: ticked ?? this.ticked,
    untickedFields: untickedFields ?? this.untickedFields,
    isWriting: isWriting ?? this.isWriting,
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
  CatalogueGapReviewNotifier(Ref ref)
    : _container = ref.container,
      super(const CatalogueGapReviewState()) {
    ref.listen<AsyncValue<List<CataloguePair>>>(
      catalogueGapPairsProvider,
      (_, next) => _take(next),
      fireImmediately: true,
    );
  }

  /// Every read goes through the container, not the provider's own Ref.
  /// The diver may leave the page while a write is under way: the Ref is
  /// then no use, and the write and what follows it must still finish.
  final ProviderContainer _container;
  static final _log = LoggerService.forClass(CatalogueGapReviewNotifier);

  /// The pairs already seeded, as site id and record id: a pair seen
  /// before keeps whatever tick the diver left it with.
  Set<String> _seeded = const {};

  /// The record each listed site was last paired with. A tick and the
  /// fields un-ticked are a decision about that record: when a site turns
  /// up paired with another one, both are dropped and the pair is seeded
  /// afresh.
  Map<String, String> _recordBySite = const {};

  static String _seedKey(CataloguePair pair) =>
      '${pair.site.id}|${pair.record.id}';

  void _take(AsyncValue<List<CataloguePair>> next) {
    // While the pairs are being found again the rows stay as they are.
    final pairs = next.value;
    if (pairs == null || !mounted) return;
    final recordBySite = {
      for (final pair in pairs) pair.site.id: pair.record.id,
    };
    // Sites still listed against the record the diver last saw them with.
    final present = {
      for (final entry in recordBySite.entries)
        if ((_recordBySite[entry.key] ?? entry.value) == entry.value) entry.key,
    };
    final seededBefore = _seeded;
    _recordBySite = recordBySite;
    _seeded = {for (final pair in pairs) _seedKey(pair)};
    state = state.copyWith(
      pairs: pairs,
      ticked: {
        ...state.ticked.intersection(present),
        for (final pair in pairs)
          if (pair.preTicked && !seededBefore.contains(_seedKey(pair)))
            pair.site.id,
      },
      untickedFields: {
        for (final entry in state.untickedFields.entries)
          if (present.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  void toggle(String siteId) {
    final ticked = {...state.ticked};
    if (!ticked.remove(siteId)) ticked.add(siteId);
    state = state.copyWith(ticked: ticked);
  }

  /// Keeps what the diver chose for [pair] in its comparison: [fields] are
  /// the ones left ticked. The row's tick then applies those, and any the
  /// record comes to offer later.
  void setFields(CataloguePair pair, Set<CatalogueGapField> fields) {
    state = state.copyWith(
      untickedFields: {
        ...state.untickedFields,
        pair.site.id: pair.fields.difference(fields),
      },
    );
  }

  /// Applies every ticked row. Null when there is nothing to do: nothing
  /// is ticked, or a write is already running.
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

  Future<CatalogueApplyResult?> _apply(List<CatalogueApplyRequest> requests) =>
      requests.isEmpty
      ? Future.value()
      : _write((service, diverId) => service.apply(requests, diverId: diverId));

  /// Remembers that [pair]'s record is a different place.
  Future<void> notSame(CataloguePair pair) => _write(
    (service, diverId) => service.answerNotSame(pair, diverId: diverId),
  );

  /// Turns down everything [pair] offers.
  Future<void> noThanks(CataloguePair pair) =>
      _write((service, diverId) => service.declineAll(pair, diverId: diverId));

  /// Runs one write and has the pairs found again before the list takes
  /// another. Null, with nothing written, when a write is already running.
  Future<T?> _write<T>(
    Future<T> Function(CatalogueGapService service, String? diverId) write,
  ) async {
    if (state.isWriting) return null;
    state = state.copyWith(isWriting: true);
    try {
      final diverId = await _container.read(
        validatedCurrentDiverIdProvider.future,
      );
      final result = await write(
        _container.read(catalogueGapServiceProvider),
        diverId,
      );
      await _afterWrite();
      return result;
    } catch (error, stackTrace) {
      _log.error(
        'Could not write to a site from the catalogue review',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isWriting: false);
    }
  }

  /// Has the pairs found again and, while the list is still on screen,
  /// waits for them: until then it shows rows the write has dealt with,
  /// and they must not be sent a second time.
  Future<void> _afterWrite() async {
    catalogueGapWritten(_container);
    if (!mounted) return;
    try {
      await _container.read(catalogueGapPairsProvider.future);
    } catch (error, stackTrace) {
      // The write itself went through. The list keeps the rows it had.
      _log.warning(
        'Could not find the catalogue pairs again after a write',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final catalogueGapReviewProvider =
    StateNotifierProvider.autoDispose<
      CatalogueGapReviewNotifier,
      CatalogueGapReviewState
    >((ref) => CatalogueGapReviewNotifier(ref));
