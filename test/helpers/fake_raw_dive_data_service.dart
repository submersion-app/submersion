import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';

/// Records each discard instead of touching a database.
class FakeRawDiveDataService implements RawDiveDataService {
  final calls = <String?>[];
  int cleared = 3;
  Object? failure;

  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<RawDiveDataUsage> getUsage() async => (sourceCount: 0, storedBytes: 0);

  @override
  Future<int> discard({String? computerId}) async {
    calls.add(computerId);
    if (failure != null) throw failure!;
    return cleared;
  }
}
