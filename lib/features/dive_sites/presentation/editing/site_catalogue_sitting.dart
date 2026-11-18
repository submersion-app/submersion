import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_sea_name.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

const _log = LoggerService('SiteCatalogueSitting');

/// The held change of the catalogue offer's Review, on the header block
/// (issue #4527, phase 2).
const String siteCatalogueKey = 'site.catalogue';

const String _reviewedKey = 'site.catalogue.reviewed';

/// Whether the sitting holds a Review: the offer line is not shown again
/// for the rest of the sitting.
bool siteCatalogueReviewed(EditSession<DiveSite> session) =>
    !session.isDisposed && session.recall<bool>(_reviewedKey) == true;

/// Holds what the diver chose in the comparison for [pair].
///
/// Apply: each chosen field is set on its card, from the record as the
/// fill repository writes it, where the sitting has it empty (a value the
/// diver typed since is never overwritten); a position moves the site, and
/// [fetchElevation] then fills an empty altitude as the fill's own
/// follow-up does; site types join [siteTypesList]. Then the link and the
/// answers (the offered fields not chosen, declined) are held, written
/// before the site's row through [SiteCatalogueFillRepository.applyFill]
/// with no fields: it works the offer out from the row as stored, and only
/// links and records the answers. Not the same, No thanks: only the
/// answers are held.
///
/// A link or answer the repository refuses at Save (the record claimed by
/// another site, the site linked elsewhere since) fails the whole Save.
///
/// Returns whether it was held: not once the sitting has ended, or while
/// it is frozen for a Save under way, which would not write it.
bool holdCatalogueReview(
  EditSession<DiveSite> session,
  CataloguePair pair,
  CatalogueComparisonResult result, {
  required List<SiteTypeEntity> allTypes,
  required String? actingDiverId,
  String? bodyOfWater,
  Future<double?> Function(GeoPoint point)? fetchElevation,
  SiteCatalogueFillRepository? repository,
}) {
  if (session.isDisposed || session.isFrozen) return false;
  final fills = repository ?? SiteCatalogueFillRepository();
  final record = pair.record;
  final siteId = session.stored.id;
  switch (result) {
    case ComparisonKept():
      return true;
    case ComparisonApply(:final fields):
      // Site types need the sitting's list to join: before it is read they
      // are neither filled nor turned down, so the record offers them again.
      final unfillable = {
        if (siteTypesList.current(session) == null) CatalogueGapField.siteTypes,
      };
      final chosen = fields.intersection(pair.fields).difference(unfillable);
      _fill(
        session,
        pair,
        chosen,
        allTypes: allTypes,
        bodyOfWater: bodyOfWater,
        fetchElevation: fetchElevation,
      );
      _hold(session, () async {
        final write = await fills.applyFill(
          siteId: siteId,
          record: record,
          fields: const {},
          declined: pair.fields.difference(chosen).difference(unfillable),
          actingDiverId: actingDiverId,
          stampLibrary: false,
        );
        if (write.outcome != CatalogueFillOutcome.applied) {
          throw RecordSittingRefusal(
            (l10n) => l10n.diveSites_edit_catalogueRefused,
          );
        }
      });
    case ComparisonNotSame():
      _hold(
        session,
        () => _answer(
          fills,
          siteId,
          (answers) => answers.withNotSame(record.id),
          actingDiverId: actingDiverId,
        ),
      );
    case ComparisonNoThanks():
      _hold(
        session,
        () => _answer(
          fills,
          siteId,
          (answers) => answers.withDeclined(record.id, [
            for (final field in pair.fields) field.name,
          ]),
          actingDiverId: actingDiverId,
        ),
      );
  }
  return true;
}

/// [holdCatalogueReview] from the site page, reading what it needs from
/// [container]: the record's sea named in the diver's language (as the
/// fill names it), the site types, the acting diver, and the elevation of
/// a position the Review gives; the types list is read first when site
/// types are chosen. Returns false, holding nothing, when a read fails.
///
/// The Review is a change of the sitting at once, held as an answer that
/// writes nothing until the reads answer: a Save asked for meanwhile sees
/// the change, waits for the reads (the sitting tracks them), and writes
/// the Review. One whose reads fail is taken back.
Future<bool> holdCatalogueReviewFrom(
  ProviderContainer container,
  EditSession<DiveSite> session,
  CataloguePair pair,
  CatalogueComparisonResult result,
) {
  if (session.isDisposed || session.isFrozen) return Future.value(false);
  _hold(session, () async {});
  final work = _holdCatalogueReviewFrom(container, session, pair, result).then((
    held,
  ) {
    if (!held && !session.isDisposed && !session.isFrozen) {
      session
        ..remember(_reviewedKey, null)
        ..releaseWrite(siteCatalogueKey);
    }
    return held;
  });
  session.track(work);
  return work;
}

Future<bool> _holdCatalogueReviewFrom(
  ProviderContainer container,
  EditSession<DiveSite> session,
  CataloguePair pair,
  CatalogueComparisonResult result,
) async {
  try {
    final service = container.read(catalogueGapServiceProvider);
    final fields = result is ComparisonApply
        ? result.fields
        : const <CatalogueGapField>{};
    final bodyOfWater = fields.contains(CatalogueGapField.bodyOfWater)
        ? await catalogueSeaInDiversLanguage(
            pair.record,
            loadSeas: service.loadSeas,
            placeNameLanguage: service.placeNameLanguage,
          )
        : null;
    if (fields.contains(CatalogueGapField.siteTypes)) {
      await siteTypesList.load(session);
    }
    final allTypes = await container.read(siteTypesProvider.future);
    final diverId = await container.read(
      validatedCurrentDiverIdProvider.future,
    );
    return holdCatalogueReview(
      session,
      pair,
      result,
      allTypes: allTypes,
      actingDiverId: diverId,
      bodyOfWater: bodyOfWater,
      fetchElevation: (point) => fetchSiteElevation(container, point),
    );
  } catch (error, stackTrace) {
    _log.error(
      'Could not hold the catalogue Review of site ${session.stored.id}',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

/// Writes an answer at Save; one the repository refuses (this profile may
/// no longer edit the site) fails the whole Save, as a refused link does.
Future<void> _answer(
  SiteCatalogueFillRepository fills,
  String siteId,
  SiteCatalogueAnswers Function(SiteCatalogueAnswers current) change, {
  required String? actingDiverId,
}) async {
  final written = await fills.updateAnswers(
    siteId,
    change,
    actingDiverId: actingDiverId,
  );
  if (!written) {
    throw RecordSittingRefusal((l10n) => l10n.diveSites_edit_catalogueRefused);
  }
}

void _hold(EditSession<DiveSite> session, Future<void> Function() write) {
  session
    ..remember(_reviewedKey, true)
    // Before the row: the offer is worked out from the site as stored.
    ..holdChange(
      siteCatalogueKey,
      cardId: siteHeaderCardId,
      write: write,
      beforeRecord: true,
    );
}

void _fill(
  EditSession<DiveSite> session,
  CataloguePair pair,
  Set<CatalogueGapField> chosen, {
  required List<SiteTypeEntity> allTypes,
  String? bodyOfWater,
  Future<double?> Function(GeoPoint point)? fetchElevation,
}) {
  final record = pair.record;
  bool blank(String? value) => value == null || value.trim().isEmpty;
  void text(EditField<DiveSite, String?> field, String? value) {
    if (blank(session.valueOf(field)) && !blank(value)) {
      session.set(field, value!.trim());
    }
  }

  for (final field in chosen) {
    switch (field) {
      case CatalogueGapField.position:
        final point = record.location;
        if (point == null || session.valueOf(siteLocationField) != null) break;
        moveSiteTo(session, point);
        if (fetchElevation != null &&
            session.valueOf(siteAltitudeField) == null) {
          scheduleAltitudeAfterMove(session, fetchElevation);
        }
      case CatalogueGapField.depth:
        if (session.valueOf(siteMinDepthField) == null &&
            session.valueOf(siteMaxDepthField) == null) {
          session
            ..set(siteMinDepthField, record.minDepth)
            ..set(siteMaxDepthField, record.maxDepth);
        }
      case CatalogueGapField.country:
        if (blank(session.valueOf(siteCountryField)) &&
            !blank(record.country)) {
          session
            ..set(siteCountryField, record.country!.trim())
            // A country always arrives with its code.
            ..set(
              siteCountryCodeField,
              record.countryCode ?? countryCodeFor(record.country),
            );
        }
      case CatalogueGapField.region:
        text(siteRegionField, record.region);
      case CatalogueGapField.city:
        text(siteCityField, record.locality);
      case CatalogueGapField.island:
        text(siteIslandField, record.island);
      case CatalogueGapField.bodyOfWater:
        text(siteBodyOfWaterField, bodyOfWater ?? record.bodyOfWater);
      case CatalogueGapField.waterType:
        if (session.valueOf(siteWaterTypeField) == null) {
          session.set(siteWaterTypeField, record.waterType);
        }
      case CatalogueGapField.entry:
        if (session.valueOf(siteEntryMethodsField).isEmpty) {
          session.set(siteEntryMethodsField, record.entryMethods);
        }
      case CatalogueGapField.difficulty:
        if (session.valueOf(siteDifficultyField) == null) {
          session.set(siteDifficultyField, record.difficulty);
        }
      case CatalogueGapField.hazards:
        text(siteHazardsField, record.hazards);
      case CatalogueGapField.description:
        if (blank(session.valueOf(siteDescriptionField)) &&
            !blank(record.description)) {
          session.set(siteDescriptionField, record.description!.trim());
        }
      case CatalogueGapField.siteTypes:
        final current = siteTypesList.current(session);
        if (current == null || current.isNotEmpty) break;
        final byId = {for (final t in allTypes) t.id: t};
        siteTypesList.set(session, [
          for (final id in record.typeIds) ?byId[id],
        ]);
    }
  }
}
