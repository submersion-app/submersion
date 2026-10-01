import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Lowers the site filter sheet to the query tree (#2365). The ONLY
/// evaluator of a SiteFilterState: a field added to it and not named here
/// fails `site_filter_query_census_test`.
extension SiteFilterQuery on SiteFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) =>
        ConditionNode(FieldPath([key]), op, v);
    ListValue refs(Set<String> ids) =>
        ListValue([for (final id in ids.toList()..sort()) RefValue(id, id)]);

    // Exact matches on the dropdown's values; an empty string narrows
    // nothing, as it never did.
    if (country != null && country!.isNotEmpty) {
      parts.add(c('country', QueryOp.eq, StringValue(country!.trim())));
    }
    if (region != null && region!.isNotEmpty) {
      parts.add(c('region', QueryOp.eq, StringValue(region!.trim())));
    }
    if (difficulty != null) {
      parts.add(c('difficulty', QueryOp.eq, EnumValue(difficulty!.name)));
    }
    if (minDepth != null) {
      parts.add(c('maxDepth', QueryOp.gte, NumberValue(minDepth!, null)));
    }
    if (maxDepth != null) {
      parts.add(c('maxDepth', QueryOp.lte, NumberValue(maxDepth!, null)));
    }
    if (minRating != null) {
      parts.add(c('rating', QueryOp.gte, NumberValue(minRating!, null)));
    }
    if (hasCoordinates != null) {
      parts.add(
        c(
          'coordinates',
          hasCoordinates! ? QueryOp.isSet : QueryOp.isEmpty,
          null,
        ),
      );
    }
    if (hasDives != null) {
      // The list's dive count: dives neither planned nor excluded from
      // stats (DiveStatsScope), from every diver.
      final counted = ScopedNode(
        FieldPath(['dives']),
        AndNode([
          c('planned', QueryOp.eq, const BoolValue(false)),
          c('excludedFromStats', QueryOp.eq, const BoolValue(false)),
        ]),
      );
      parts.add(hasDives! ? counted : NotNode(counted));
    }
    if (siteTypeIds.isNotEmpty) {
      parts.add(c('types', QueryOp.inList, refs(siteTypeIds)));
    }
    if (tagIds.isNotEmpty) parts.add(c('tags', QueryOp.inList, refs(tagIds)));
    if (query != null) parts.add(query!);
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

/// The one compile call every site path shares. [diverId] reads a shared
/// site's dives as that diver's alone.
CompiledQuery compileSiteFilter(
  SiteFilterState filter, {
  String rootAlias = 'r0',
  String? diverId,
}) => compileQuery(
  filter.toQuery(),
  siteQueryEntity,
  appQueryRegistry,
  rootAlias: rootAlias,
  diverId: diverId,
);
