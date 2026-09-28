import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// The one id-set runner the site, equipment and trip lists share (#2365).
final queryIdSetRunnerProvider = Provider<QueryIdSetRunner>(
  (ref) => QueryIdSetRunner(DatabaseService.instance.database),
);
