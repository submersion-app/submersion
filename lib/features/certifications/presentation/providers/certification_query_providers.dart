import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The certification list's query (#2365); null lists every certification.
final certificationQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The certification list narrowed to the query's ids; the grouped list,
/// compact pane and table all read this.
final filteredCertificationsProvider =
    Provider<AsyncValue<List<Certification>>>(
      (ref) => narrowByQuery(
        ref,
        ref.watch(certificationListNotifierProvider),
        certificationQueryEntity,
        ref.watch(certificationQueryProvider),
        (c) => c.id,
      ),
    );
