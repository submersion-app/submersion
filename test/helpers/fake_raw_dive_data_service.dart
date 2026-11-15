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
  Future<RawDiveDataUsage> getUsage({String? computerId}) async =>
      (diveCount: 0, storedBytes: 0);

  List<ComputerRawDiveDataUsage> byComputer = const [];

  @override
  Future<List<ComputerRawDiveDataUsage>> getUsageByComputer() async =>
      byComputer;

  @override
  Future<int> discard({String? computerId}) async {
    calls.add(computerId);
    if (failure != null) throw failure!;
    return cleared;
  }
}
