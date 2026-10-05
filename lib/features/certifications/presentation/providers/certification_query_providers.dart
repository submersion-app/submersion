import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The certification list's query (#2365); null lists every certification.
final certificationQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The home chip's "needs attention" scope (issue #2267). Real filter state
/// with a visible, clearable indicator, so a short list is never a mystery.
final certificationAttentionFilterProvider = StateProvider<bool>(
  (ref) => false,
);

/// The certification list narrowed to the query's ids and, while the scope
/// is on, to the certifications needing attention; the grouped list,
/// compact pane and table all read this.
final filteredCertificationsProvider =
    Provider<AsyncValue<List<Certification>>>((ref) {
      final byQuery = narrowByQuery(
        ref,
        ref.watch(certificationListNotifierProvider),
        certificationQueryEntity,
        ref.watch(certificationQueryProvider),
        (c) => c.id,
      );
      if (!ref.watch(certificationAttentionFilterProvider)) return byQuery;
      // Until currency resolves the scope is unknown, not empty: reading
      // it as empty would flash "No certifications need attention".
      final attention = ref.watch(currencyAttentionProvider).value;
      if (attention == null) return const AsyncLoading();
      final ids = attention.certificationIds;
      return byQuery.whenData(
        (certs) => [
          for (final c in certs)
            if (ids.contains(c.id)) c,
        ],
      );
    });
