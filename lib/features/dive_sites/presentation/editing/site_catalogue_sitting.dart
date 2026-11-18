import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

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
void holdCatalogueReview(
  EditSession<DiveSite> session,
  CataloguePair pair,
  CatalogueComparisonResult result, {
  required List<SiteTypeEntity> allTypes,
  required String? actingDiverId,
  String? bodyOfWater,
  Future<double?> Function(GeoPoint point)? fetchElevation,
  SiteCatalogueFillRepository? repository,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final fills = repository ?? SiteCatalogueFillRepository();
  final record = pair.record;
  final siteId = session.stored.id;
  switch (result) {
    case ComparisonKept():
      return;
    case ComparisonApply(:final fields):
      final chosen = fields.intersection(pair.fields);
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
          declined: pair.fields.difference(chosen),
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
        () => fills.updateAnswers(
          siteId,
          (answers) => answers.withNotSame(record.id),
          actingDiverId: actingDiverId,
        ),
      );
    case ComparisonNoThanks():
      _hold(
        session,
        () => fills.updateAnswers(
          siteId,
          (answers) => answers.withDeclined(record.id, [
            for (final field in pair.fields) field.name,
          ]),
          actingDiverId: actingDiverId,
        ),
      );
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
